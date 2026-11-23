package com.entrenaOp.entrenaop

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.Looper

class PhoneRunLocationService : Service(), LocationListener {
    private val location by lazy { getSystemService(LocationManager::class.java) }
    private var request: Request? = null

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Carrera con el móvil", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    @SuppressLint("MissingPermission")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val token = intent?.getStringExtra(TOKEN)
        val next = waiting?.takeIf { it.token == token }
        if (next == null) {
            if (request == null) {
                // Android exige promover incluso un inicio cancelado antes de
                // entregar el Intent. En este caso jamás se solicita ubicación.
                try { promote() } catch (_: RuntimeException) {}
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf(startId)
            }
            return START_NOT_STICKY
        }
        waiting = null
        if (request != null) {
            next.started("busy")
            return START_NOT_STICKY
        }
        try {
            promote()
            if (!location.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                next.started("disabled")
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf(startId)
                return START_NOT_STICKY
            }
            location.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, this, Looper.getMainLooper())
            request = next
            running = this
            next.started(null)
        } catch (_: SecurityException) {
            next.started("permission")
            stopRecording()
        } catch (_: RuntimeException) {
            next.started("unavailable")
            stopRecording()
        }
        return START_NOT_STICKY
    }

    private fun notification(data: Map<*, *>? = null): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder.setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Grabando carrera")
            .setContentText("Toca para volver a EntrenaOP y pausar o terminar.")
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        if (data != null) {
            val phase = data["phase"] as? String ?: "Carrera"
            val pace = data["pace"] as? String ?: "— min/km"
            val distance = data["distance"] as? String ?: ""
            val progress = data["progress"] as? String ?: ""
            val elapsed = (data["seconds"] as? Number)?.toLong() ?: 0
            builder.setContentTitle("$phase · $pace")
                .setContentText(listOf(distance, progress).filter { it.isNotEmpty() }.joinToString(" · "))
                .setWhen(System.currentTimeMillis() - elapsed * 1000)
                .setUsesChronometer(elapsed > 0)
        }
        return builder.build()
    }

    private fun promote() {
        val notification = notification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @SuppressLint("MissingPermission")
    private fun updateProgress(data: Map<*, *>) {
        try {
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification(data))
        } catch (_: SecurityException) {
            // La captura puede continuar aunque no se concedan notificaciones.
        }
    }

    override fun onLocationChanged(point: Location) {
        request?.event?.invoke(mapOf(
            "lat" to point.latitude, "lon" to point.longitude,
            "accuracy" to if (point.hasAccuracy()) point.accuracy.toDouble() else -1.0,
            "time" to point.time,
        ))
    }

    override fun onProviderDisabled(provider: String) {
        request?.event?.invoke(mapOf("error" to "disabled"))
        stopRecording()
    }

    override fun onProviderEnabled(provider: String) = Unit

    @Deprecated("Antiguo callback de Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    private fun releaseLocation() {
        if (running === this) running = null
        request = null
        location.removeUpdates(this)
    }

    private fun stopRecording() {
        releaseLocation()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        request?.event?.invoke(mapOf("error" to "interrupted"))
        releaseLocation()
        super.onDestroy()
    }

    private class Request(
        val token: String,
        val started: (String?) -> Unit,
        val event: (Map<String, Any>) -> Unit,
    )

    companion object {
        const val TOKEN = "phone_run_token"
        private const val CHANNEL_ID = "phone_run_recording"
        private const val NOTIFICATION_ID = 7316
        private var waiting: Request? = null
        private var running: PhoneRunLocationService? = null

        // Canal y servicio comparten proceso y ejecutan estas llamadas en el hilo principal.
        internal fun prepare(token: String, started: (String?) -> Unit, event: (Map<String, Any>) -> Unit) {
            waiting = Request(token, started, event)
        }

        internal fun cancel(token: String, error: String) {
            waiting?.takeIf { it.token == token }?.let {
                waiting = null
                it.started(error)
            }
            running?.takeIf { it.request?.token == token }?.stopRecording()
        }

        internal fun progress(token: String, data: Map<*, *>) {
            running?.takeIf { it.request?.token == token }?.updateProgress(data)
        }
    }
}
