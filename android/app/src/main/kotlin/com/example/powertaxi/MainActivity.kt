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
                        val fare        = call.argument<Double>("fare")        ?: 0.0
                        val distance    = call.argument<Double>("distance")    ?: 0.0
                        val receiptText = call.argument<String>("receiptText") ?: ""
                        Log.d("HowenPrint", "PRINT — fare=$$fare dist=${distance}m receiptLen=${receiptText.length}")
                        if (receiptText.isNotEmpty()) {
                            printToHowenSerial(receiptText)
                        }
                        result.success(true)
                    }
                    "getRawPulses" -> {
                        result.success(lastTotalPulse)
                    }
                    "getDeviceSerial" -> {
                        val serial = getHowenDeviceSerial()
                        Log.d("HowenSerial", "Detected device serial: $serial")
                        result.success(serial)
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
                // ── Shift Management (Volume) ──────────────────────────
                KeyEvent.KEYCODE_VOLUME_UP   -> 1   // F1 (Start Shift / End Shift)
                KeyEvent.KEYCODE_VOLUME_DOWN -> 2   // F2 (Break)
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

    private fun getHowenDeviceSerial(): String {
        // 1. Try Reflection on HowenManager
        howenManager?.let { manager ->
            try {
                val methods = manager.javaClass.declaredMethods
                for (method in methods) {
                    val name = method.name.lowercase()
                    if ((name.contains("sn") || name.contains("serial") || name.contains("deviceid") || name.contains("uuid"))
                        && method.parameterTypes.isEmpty()
                        && method.returnType == String::class.java
                    ) {
                        method.isAccessible = true
                        val res = method.invoke(manager) as? String
                        if (!res.isNullOrBlank() && !res.equals("unknown", ignoreCase = true)) {
                            Log.d("HowenSerial", "Found serial via HowenManager.${method.name}: $res")
                            return res.trim().uppercase()
                        }
                    }
                }
            } catch (e: Throwable) {
                Log.w("HowenSerial", "HowenManager reflection error: ${e.message}")
            }
        }

        // 2. Try android.os.SystemProperties (sys.sn is default Howen device SN property)
        val systemPropertyKeys = arrayOf(
            "sys.sn",
            "persist.sys.sn",
            "ro.serialno",
            "gsm.sn",
            "ro.sys.sn",
            "ro.howen.sn",
            "persist.radio.sn",
            "ro.hw.sn",
            "ro.hardware.sn",
            "ro.boot.serialno"
        )
        for (key in systemPropertyKeys) {
            val value = getSystemProperty(key)
            if (value.isNotBlank() && !value.equals("unknown", ignoreCase = true) && !value.equals("unknown-device", ignoreCase = true)) {
                Log.d("HowenSerial", "Found serial via SystemProperties[$key]: $value")
                return value.trim().uppercase()
            }
        }

        // 3. Try shell getprop execution for Howen props
        for (key in arrayOf("sys.sn", "persist.sys.sn", "ro.serialno", "gsm.sn")) {
            val value = readShellProp(key)
            if (value.isNotBlank() && !value.equals("unknown", ignoreCase = true)) {
                Log.d("HowenSerial", "Found serial via getprop $key: $value")
                return value.trim().uppercase()
            }
        }

        // 4. Try Build.getSerial()
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                @Suppress("MissingPermission")
                val serial = android.os.Build.getSerial()
                if (!serial.isNullOrBlank() && !serial.equals("unknown", ignoreCase = true)) {
                    Log.d("HowenSerial", "Found serial via Build.getSerial(): $serial")
                    return serial.trim().uppercase()
                }
            }
        } catch (e: Throwable) {
            Log.w("HowenSerial", "Build.getSerial() failed: ${e.message}")
        }

        // 5. Try Build.SERIAL
        @Suppress("DEPRECATION")
        val legacySerial = android.os.Build.SERIAL
        if (!legacySerial.isNullOrBlank() && !legacySerial.equals("unknown", ignoreCase = true)) {
            Log.d("HowenSerial", "Found serial via Build.SERIAL: $legacySerial")
            return legacySerial.trim().uppercase()
        }

        // 6. Try TelephonyManager (deviceId / getImei)
        try {
            val telephonyManager = getSystemService(android.content.Context.TELEPHONY_SERVICE) as? android.telephony.TelephonyManager
            telephonyManager?.let { tm ->
                @Suppress("DEPRECATION", "MissingPermission")
                val deviceId = tm.deviceId
                if (!deviceId.isNullOrBlank() && !deviceId.equals("unknown", ignoreCase = true)) {
                    Log.d("HowenSerial", "Found serial via TelephonyManager.deviceId: $deviceId")
                    return deviceId.trim().uppercase()
                }
            }
        } catch (e: Throwable) {
            Log.w("HowenSerial", "TelephonyManager error: ${e.message}")
        }

        // 7. Fallback to Settings.Secure.ANDROID_ID
        try {
            val androidId = android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ANDROID_ID)
            if (!androidId.isNullOrBlank() && !androidId.equals("unknown", ignoreCase = true)) {
                Log.d("HowenSerial", "Found serial via ANDROID_ID: $androidId")
                return androidId.trim().uppercase()
            }
        } catch (e: Throwable) {
            Log.w("HowenSerial", "ANDROID_ID error: ${e.message}")
        }

        return ""
    }

    private fun getSystemProperty(key: String, defaultValue: String = ""): String {
        return try {
            val systemPropertiesClass = Class.forName("android.os.SystemProperties")
            val getMethod = systemPropertiesClass.getMethod("get", String::class.java, String::class.java)
            (getMethod.invoke(null, key, defaultValue) as? String) ?: defaultValue
        } catch (e: Throwable) {
            defaultValue
        }
    }

    private fun readShellProp(propName: String): String {
        return try {
            val process = Runtime.getRuntime().exec("getprop $propName")
            val reader = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
            val output = reader.readLine()?.trim() ?: ""
            process.destroy()
            output
        } catch (e: Throwable) {
            ""
        }
    }

    private fun printToHowenSerial(receiptText: String) {
        val ports = arrayOf(
            "/dev/ttyS0", "/dev/ttyS1", "/dev/ttyS2", "/dev/ttyS3", 
            "/dev/ttyS4", "/dev/ttyS5", "/dev/ttyUSB0", "/dev/ttyUSB4", "/dev/ttyUSB5"
        )
        val bauds = intArrayOf(9600, 115200, 19200, 38400)

        // ESC @ (0x1B, 0x40) init + text bytes + 3 line feeds + GS V 1 cut (0x1D, 0x56, 0x01)
        val escInit = byteArrayOf(0x1B.toByte(), 0x40.toByte())
        val escCut  = byteArrayOf(0x0A.toByte(), 0x0A.toByte(), 0x0A.toByte(), 0x1D.toByte(), 0x56.toByte(), 0x01.toByte())
        
        val textBytes = receiptText.toByteArray(Charsets.UTF_8)
        val fullData = escInit + textBytes + escCut

        Thread {
            for (port in ports) {
                // Ensure Android app process has permission to open serial node
                try {
                    Runtime.getRuntime().exec("chmod 666 $port").waitFor()
                } catch (_: Throwable) {}

                for (baud in bauds) {
                    try {
                        val fd = com.howen.howennative.serialService.serialOpen(port)
                        if (fd >= 0) {
                            com.howen.howennative.serialService.serialPortSetting(fd, baud, 8, 0, 1)
                            Thread.sleep(50)
                            val written = com.howen.howennative.serialService.serialWrite(fd, fullData, fullData.size)
                            Log.d("HowenPrint", "SUCCESS: Sent $written/${fullData.size} bytes to $port @ $baud baud (fd=$fd)")
                            Thread.sleep(150)
                            com.howen.howennative.serialService.serialClose(fd)
                        } else {
                            Log.w("HowenPrint", "Could not open port $port (fd=$fd)")
                        }
                    } catch (e: Throwable) {
                        Log.e("HowenPrint", "Error sending to $port @ $baud baud: ${e.message}")
                    }
                }
            }
        }.start()
    }
}