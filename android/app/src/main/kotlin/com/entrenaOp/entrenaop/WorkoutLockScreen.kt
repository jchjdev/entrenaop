package com.entrenaOp.entrenaop

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build

internal class WorkoutLockScreen(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)
    private var activeExecution: String? = null

    init {
        // Una ejecución descartada por el sistema no deja una tarjeta huérfana.
        manager.cancel(NOTIFICATION_ID)
    }

    @SuppressLint("MissingPermission")
    fun show(data: Map<*, *>): Boolean {
        val execution = data["executionId"] as? String ?: return true
        val exercise = data["exercise"] as? String ?: return true
        val prescription = data["prescription"] as? String ?: return true
        val url = data["openUrl"] as? String ?: return true
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Entrenamiento en curso", NotificationManager.IMPORTANCE_LOW)
                    .apply { setShowBadge(false) },
            )
            if (manager.getNotificationChannel(CHANNEL_ID).importance == NotificationManager.IMPORTANCE_NONE) {
                return false
            }
        }

        val now = System.currentTimeMillis()
        val deadline = (data["restEndsAt"] as? Number)?.toLong()?.takeIf { it > now }
        val open = PendingIntent.getActivity(
            context, NOTIFICATION_ID,
            Intent(Intent.ACTION_VIEW, Uri.parse(url), context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        fun builder(): Notification.Builder {
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            builder.setSmallIcon(android.R.drawable.ic_menu_recent_history)
                .setContentIntent(open)
                .setColor(Color.rgb(255, 90, 31))
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setShowWhen(deadline != null)
            if (deadline != null) {
                builder.setWhen(deadline).setUsesChronometer(true).setChronometerCountDown(true)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // El sistema retira la cuenta atrás al vencer aunque Flutter esté suspendido.
                builder.setTimeoutAfter(deadline?.minus(now) ?: TWO_HOURS_MS)
            }
            return builder
        }

        val publicNotification = builder()
            .setContentTitle(if (deadline != null) "Descanso" else "Entrenamiento en curso")
            .build()
        val notification = builder()
            .setContentTitle(if (deadline != null) "Descanso · $exercise" else exercise)
            .setContentText(prescription)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(publicNotification)
            .build()
        return try {
            manager.notify(NOTIFICATION_ID, notification)
            activeExecution = execution
            true
        } catch (_: SecurityException) {
            false
        }
    }

    fun clear(execution: String) {
        if (activeExecution == execution) close()
    }

    fun close() {
        activeExecution = null
        manager.cancel(NOTIFICATION_ID)
    }

    private companion object {
        const val CHANNEL_ID = "workout_lock_screen"
        const val NOTIFICATION_ID = 7320
        const val TWO_HOURS_MS = 7_200_000L
    }
}
