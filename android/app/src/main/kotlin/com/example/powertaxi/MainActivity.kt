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
                        pulsesPerKm = kFactor
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
                // Howen OIML pulse is usually doubled (2 pulses per signal event)
                // OimlActivity.java does: long Pulse = (total_pulse >> 1);
                val relativePulses = (totalDistancePulse - startDistancePulse) / 2.0
                val distanceMeters = (relativePulses / pulsesPerKm) * 1000.0
                
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
        startDistancePulse = lastTotalPulse
        isMeterRunning = true
        Log.d("HowenHardware", "Meter STARTED at pulse: $startDistancePulse")
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