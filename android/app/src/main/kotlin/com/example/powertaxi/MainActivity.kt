package com.example.powertaxi

import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Timer
import kotlin.concurrent.timerTask
import com.android.howen.HowenManager
import android.os.Bundle

class MainActivity : FlutterActivity() {

    private val COMMAND_CHANNEL = "com.ezbus.taximeter/howen_commands"
    private val STREAM_CHANNEL  = "com.ezbus.taximeter/howen_stream"
    private val BUTTON_CHANNEL  = "com.ezbus.taximeter/howen_buttons"

    private var eventSink: EventChannel.EventSink? = null
    private var buttonEventSink: EventChannel.EventSink? = null
    
    private var howenManager: HowenManager? = null
    private var lastTotalPulse: Long = 0L
    private var startDistancePulse: Long = 0L
    private var isMeterRunning = false
    private var isFirstPulseOfRide = false // True until first pulse arrives after startMeter()
    private var pulsesPerKm = 500.0 // Default K-Factor

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── 1. Distance pulse stream ──────────────────────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d("HowenStream", "Flutter connected to hardware stream.")
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopHardwareMeter()
                }
            })

        // ── 2. Commands (start / stop meter, print) ───────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMMAND_CHANNEL)
            .setMethodCallHandler { call, result ->
                initHowenManager() // Ensure manager is ready
                when (call.method) {
                    "startMeter" -> {
                        // Capture starting pulse for relative distance
                        // In a real scenario, we might want to get the latest total pulse count first.
                        // But since it's a stream, we'll wait for the next callback.
                        startHardwareMeter()
                        result.success(true)
                    }
                    "stopMeter" -> {
                        stopHardwareMeter()
                        result.success(true)
                    }
                    "updateCalibration" -> {
                        val kFactor = call.argument<Double>("pulsesPerKm") ?: 500.0
                        pulsesPerKm = if (kFactor > 0.0) kFactor else 500.0
                        Log.d("HowenHardware", "Calibration updated: K=$pulsesPerKm")
                        result.success(true)
                    }
                    "printReceipt" -> {
                        val fare     = call.argument<Double>("fare")     ?: 0.0
                        val distance = call.argument<Double>("distance") ?: 0.0
                        Log.d("HowenPrint", "PRINT — fare=$$fare  dist=${distance}m")
                        result.success(true)
                    }
                    "getRawPulses" -> {
                        result.success(lastTotalPulse)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 3. Hardware button event stream ──────────────────────────────────
        // Sends button index to Flutter: 4 = F4, 5 = F5, 6 = F6
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BUTTON_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    buttonEventSink = events
                    Log.d("HowenButtons", "Flutter connected to button channel.")
                }
                override fun onCancel(arguments: Any?) {
                    buttonEventSink = null
                }
            })
    }

    // ── 4. Intercept Game Button key events BEFORE Android consumes them ──────
    // The Howen AT5 sends KEYCODE_BUTTON_C / _X / _Y for its F4/F5/F6 keys.
    // We catch them here and push the button index through the EventChannel.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            // Log EVERY key press for diagnostics
            Log.d("HowenButtons", "KEY_DOWN keyCode=${event.keyCode} source=${event.source} sink=${buttonEventSink != null}")

            val buttonIndex = when (event.keyCode) {
                // ── Confirmed Howen AT5 custom keycodes (from Logcat) ──────────
                290 -> 4   // F4 (0x122 = Game Button 3)
                291 -> 5   // F5 (0x123 = Game Button 4)
                292 -> 6   // F6 (0x124 = Game Button 5)
                // ── Standard Android fallbacks ─────────────────────────────────
                KeyEvent.KEYCODE_BUTTON_C  -> 4   // 98
                KeyEvent.KEYCODE_BUTTON_X  -> 5   // 99
                KeyEvent.KEYCODE_BUTTON_Y  -> 6   // 100
                KeyEvent.KEYCODE_F4        -> 4
                KeyEvent.KEYCODE_F5        -> 5
                KeyEvent.KEYCODE_F6        -> 6
                else -> -1
            }

            if (buttonIndex != -1) {
                Log.d("HowenButtons", "🎮 MATCHED button $buttonIndex (keyCode=${event.keyCode}) sink=${buttonEventSink != null}")
                runOnUiThread { buttonEventSink?.success(buttonIndex) }
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    // ── 4. Howen SDK Lifecycle ──────────────────────────────────────────────
    
    private val oimlCallback = object : HowenManager.OimlCallback {
        override fun onOimlPluseChanged(distancePulse: Int, totalDistancePulse: Long, pulseWidth: Long) {
            lastTotalPulse = totalDistancePulse

            if (isMeterRunning) {
                // On the very first pulse after the meter starts, capture a true baseline.
                // This prevents a jump caused by startDistancePulse being 0 while
                // totalDistancePulse is the absolute odometer value (e.g. 20,000,000).
                if (isFirstPulseOfRide) {
                    startDistancePulse = totalDistancePulse
                    isFirstPulseOfRide = false
                    Log.d("HowenHardware", "BASELINE SET: startPulse=$startDistancePulse")
                    return // Distance is 0.0m on the very first tick — skip emit
                }

                // Howen OIML pulses are doubled (2 hardware signals per physical pulse).
                // Reference: OimlActivity.java → long Pulse = (total_pulse >> 1);
                val relativePulses = (totalDistancePulse - startDistancePulse) / 2.0
                val safePulsesPerKm = if (pulsesPerKm > 0.0) pulsesPerKm else 500.0
                val distanceMeters = (relativePulses / safePulsesPerKm) * 1000.0

                Log.d("HowenHardware", "PULSE: total=$totalDistancePulse rel=$relativePulses dist=${distanceMeters}m")

                activity.runOnUiThread {
                    val data = mapOf(
                        "distance" to distanceMeters,
                        "totalPulse" to totalDistancePulse
                    )
                    eventSink?.success(data)
                }
            }
        }

        override fun onOimlPowerAdcChanged(mainPower: Int, boxPower: Int) {
            Log.d("HowenHardware", "POWER: main=$mainPower box=$boxPower")
        }
    }

    private fun startHardwareMeter() {
        // Do NOT use lastTotalPulse as baseline here — it may be 0 if no callback
        // has fired yet. Instead, mark that the next callback should set the baseline.
        startDistancePulse = 0L
        isFirstPulseOfRide = true
        isMeterRunning = true
        Log.d("HowenHardware", "Meter STARTED — awaiting first pulse for baseline")
    }

    private fun stopHardwareMeter() {
        isMeterRunning = false
        Log.d("HowenHardware", "Meter STOPPED")
    }

    override fun onDestroy() {
        howenManager?.release()
        super.onDestroy()
    }

    private fun initHowenManager() {
        if (howenManager == null) {
            howenManager = HowenManager.create(this)
            howenManager?.setOimlCallback(oimlCallback)
            Log.d("HowenHardware", "HowenManager INITIALIZED")
        }
    }
}