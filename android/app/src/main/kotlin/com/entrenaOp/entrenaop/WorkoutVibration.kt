package com.entrenaOp.entrenaop

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings

class WorkoutVibration(private val context: Context) {
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    fun notificationsEnabled(): Boolean =
        context.getSystemService(NotificationManager::class.java)?.areNotificationsEnabled() == true

    fun diagnostics(): Map<String, Any?> = mapOf(
        "sdk" to Build.VERSION.SDK_INT,
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "hasVibrator" to (vibrator?.hasVibrator() == true),
        "hasAmplitudeControl" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.hasAmplitudeControl()
        } else null,
        "permissionGranted" to (
            context.checkSelfPermission(Manifest.permission.VIBRATE) == PackageManager.PERMISSION_GRANTED
        ),
        "notificationsEnabled" to notificationsEnabled(),
        "ringerMode" to context.getSystemService(AudioManager::class.java)?.ringerMode,
        "interruptionFilter" to context.getSystemService(NotificationManager::class.java)
            ?.currentInterruptionFilter,
        // -1 indica que no hay valor explícito; no significa intensidad cero.
        "notificationIntensity" to runCatching {
            Settings.System.getInt(context.contentResolver, "notification_vibration_intensity", -1)
        }.getOrNull(),
    )

    @Suppress("DEPRECATION")
    fun signal(cue: String?): Boolean {
        val pattern = when (cue) {
            "preparationTick", "workEndingTick" -> longArrayOf(0, 60)
            "halfway", "tenSecondsRemaining" -> longArrayOf(0, 120)
            "workStarted" -> longArrayOf(0, 200)
            "workFinished", "restFinished" -> longArrayOf(0, 160, 100, 160)
            else -> throw IllegalArgumentException("Aviso de vibración desconocido: $cue")
        }
        val motor = vibrator ?: return false
        if (!motor.hasVibrator()) return false

        // Avisos temporales, sujetos a los ajustes de notificación y No molestar.
        // No son alarmas ni respuesta de teclado; no se fuerza la intensidad.
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createWaveform(pattern, -1)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                motor.vibrate(
                    effect,
                    VibrationAttributes.Builder()
                        .setUsage(VibrationAttributes.USAGE_NOTIFICATION)
                        .build(),
                )
            } else {
                motor.vibrate(effect, audioAttributes)
            }
        } else {
            motor.vibrate(pattern, -1, audioAttributes)
        }
        // Android confirma la solicitud, no que el usuario la haya percibido.
        return true
    }

    fun cancel() {
        vibrator?.cancel()
    }
}
