package com.entrenaOp.entrenaop

import android.content.pm.ApplicationInfo
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val workoutVibration by lazy { WorkoutVibration(this) }
    private var vibrationChannel: MethodChannel? = null
    private var isForeground = false
    private val isDebug by lazy {
        (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vibrationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "es.entrenaop/workout_vibration",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "diagnostics" -> {
                            if (isDebug) {
                                result.success(
                                    workoutVibration.diagnostics() + ("visible" to isForeground),
                                )
                            } else {
                                result.notImplemented()
                            }
                        }
                        "signal" -> {
                            val cue = call.arguments as? String
                            val sent = isForeground && workoutVibration.signal(cue)
                            if (isDebug) {
                                Log.d("EntrenaOPVibration", "aviso=$cue visible=$isForeground enviada=$sent")
                            }
                            result.success(sent)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    if (isDebug) {
                        Log.e("EntrenaOPVibration", "fallo en ${call.method}", error)
                    }
                    result.error("vibration_failed", error.message, null)
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        isForeground = true
    }

    override fun onStop() {
        isForeground = false
        workoutVibration.cancel()
        super.onStop()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        vibrationChannel?.setMethodCallHandler(null)
        vibrationChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
