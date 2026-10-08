package com.entrenaOp.entrenaop

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class WorkoutVibration(context: Context) {
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

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
