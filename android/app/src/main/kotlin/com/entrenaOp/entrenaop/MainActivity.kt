package com.entrenaOp.entrenaop

import android.Manifest
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val workoutVibration by lazy { WorkoutVibration(this) }
    private var vibrationChannel: MethodChannel? = null
    private var notificationPermissionResult: MethodChannel.Result? = null
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
                        "needsPermission" -> result.success(
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                                !workoutVibration.notificationsEnabled() &&
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                                    PackageManager.PERMISSION_GRANTED,
                        )
                        "requestPermission" -> requestVibrationPermission(result)
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
                            // Samsung cancela estos avisos antes de registrarlos si
                            // la app tiene las notificaciones bloqueadas.
                            if (!workoutVibration.notificationsEnabled()) {
                                result.error("notifications_disabled", "Notificaciones desactivadas", null)
                                return@setMethodCallHandler
                            }
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

    private fun requestVibrationPermission(result: MethodChannel.Result) {
        if (!isForeground || isFinishing) {
            result.success(false)
            return
        }
        if (workoutVibration.notificationsEnabled()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            // Un bloqueo desde ajustes no se resuelve con otro diálogo.
            result.success(false)
            return
        }
        if (notificationPermissionResult != null) {
            result.error("permission_request_pending", "Petición de permiso en curso", null)
            return
        }
        notificationPermissionResult = result
        try {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
        } catch (error: Exception) {
            notificationPermissionResult = null
            throw error
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            val result = notificationPermissionResult
            notificationPermissionResult = null
            result?.success(workoutVibration.notificationsEnabled())
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
        notificationPermissionResult?.error("permission_request_cancelled", "Prueba interrumpida", null)
        notificationPermissionResult = null
        vibrationChannel?.setMethodCallHandler(null)
        vibrationChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST = 7314
    }
}
