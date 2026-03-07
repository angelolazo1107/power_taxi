package com.example.powertaxi

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Timer
import kotlin.concurrent.timerTask

class MainActivity: FlutterActivity() {
    private val COMMAND_CHANNEL = "com.ezbus.taximeter/howen_commands"
    private val STREAM_CHANNEL = "com.ezbus.taximeter/howen_stream"

    // Variables to hold our fake hardware state
    private var eventSink: EventChannel.EventSink? = null
    private var pulseTimer: Timer? = null
    private var simulatedDistance = 0.0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // =========================================================
        // 1. SETUP THE STREAM (Listening for pulses)
        // =========================================================
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    // Save the "sink" so we can push data into it later
                    eventSink = events 
                    println("📱 Native: Flutter connected to the hardware stream.")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopSimulatedHardware()
                    println("📱 Native: Flutter disconnected.")
                }
            })

        // =========================================================
        // 2. SETUP THE COMMANDS (Start, Stop, Print)
        // =========================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMMAND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMeter" -> {
                        println("⚙️ Native: FAKE HOWEN METER STARTED")
                        simulatedDistance = 0.0 // Reset distance for new ride
                        startSimulatedHardware()
                        result.success(true)
                    }
                    "stopMeter" -> {
                        println("⚙️ Native: FAKE HOWEN METER STOPPED")
                        stopSimulatedHardware()
                        result.success(true)
                    }
                    "printReceipt" -> {
                        val fare = call.argument<Double>("fare") ?: 0.0
                        val distance = call.argument<Double>("distance") ?: 0.0
                        
                        // Simulate the physical printer in the debug console
                        println("=====================================")
                        println("🖨️ NATIVE PRINTER SIMULATION")
                        println("TOTAL FARE: Php $fare")
                        println("DISTANCE: $distance m")
                        println("=====================================")
                        
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    // --- FAKE HARDWARE LOGIC ---

    private fun startSimulatedHardware() {
        pulseTimer?.cancel()
        pulseTimer = Timer()
        
        // This timer acts like the car driving down the road
        pulseTimer?.scheduleAtFixedRate(timerTask {
            
            // Simulate driving 15 meters every second (approx 54 km/h)
            simulatedDistance += 15.0 
            
            // Push the new distance back up to Flutter on the main UI thread
            activity.runOnUiThread {
                eventSink?.success(simulatedDistance)
            }
            
        }, 1000, 1000) // Start after 1 second, repeat every 1 second
    }

    private fun stopSimulatedHardware() {
        pulseTimer?.cancel()
        pulseTimer = null
    }
}