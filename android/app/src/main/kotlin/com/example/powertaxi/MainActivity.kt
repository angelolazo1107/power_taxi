package com.example.powertaxi

import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Timer
import kotlin.concurrent.timerTask

class MainActivity : FlutterActivity() {

    private val COMMAND_CHANNEL = "com.ezbus.taximeter/howen_commands"
    private val STREAM_CHANNEL  = "com.ezbus.taximeter/howen_stream"
    private val BUTTON_CHANNEL  = "com.ezbus.taximeter/howen_buttons"

    private var eventSink: EventChannel.EventSink? = null
    private var buttonEventSink: EventChannel.EventSink? = null
    private var pulseTimer: Timer? = null
    private var simulatedDistance = 0.0

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
                    stopSimulatedHardware()
                }
            })

        // ── 2. Commands (start / stop meter, print) ───────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMMAND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMeter" -> {
                        simulatedDistance = 0.0
                        startSimulatedHardware()
                        result.success(true)
                    }
                    "stopMeter" -> {
                        stopSimulatedHardware()
                        result.success(true)
                    }
                    "printReceipt" -> {
                        val fare     = call.argument<Double>("fare")     ?: 0.0
                        val distance = call.argument<Double>("distance") ?: 0.0
                        Log.d("HowenPrint", "PRINT — fare=$$fare  dist=${distance}m")
                        result.success(true)
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

    // ── Simulated hardware (distance pulses for testing) ─────────────────────
    private fun startSimulatedHardware() {
        pulseTimer?.cancel()
        pulseTimer = Timer()
        pulseTimer?.scheduleAtFixedRate(timerTask {
            simulatedDistance += 15.0
            activity.runOnUiThread { eventSink?.success(simulatedDistance) }
        }, 1000, 1000)
    }

    private fun stopSimulatedHardware() {
        pulseTimer?.cancel()
        pulseTimer = null
    }
}