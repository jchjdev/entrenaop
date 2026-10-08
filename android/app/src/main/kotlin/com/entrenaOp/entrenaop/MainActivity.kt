package com.entrenaOp.entrenaop

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val workoutVibration by lazy { WorkoutVibration(this) }
    private var vibrationChannel: MethodChannel? = null
    private var isForeground = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vibrationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "es.entrenaop/workout_vibration",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "signal") {
                    result.notImplemented()
                } else {
                    try {
                        result.success(
                            isForeground && workoutVibration.signal(call.arguments as? String),
                        )
                    } catch (error: Exception) {
                        result.error("vibration_failed", error.message, null)
                    }
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
