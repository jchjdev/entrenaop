package com.entrenaOp.entrenaop

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.media.AudioAttributes
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

internal class PhoneRunLocationChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private val methods = MethodChannel(messenger, "es.entrenaop/phone_run")
    private val events = EventChannel(messenger, "es.entrenaop/phone_run/locations")
    private var pendingPermission: Pair<String, MethodChannel.Result>? = null
    private var permissionDialogOpen = false
    private var token: String? = null
    private var sink: EventChannel.EventSink? = null
    private var speech: TextToSpeech? = null
    private var speechReady = false
    private var pendingSpeech: Pair<String, Long>? = null

    init {
        events.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
            when (call.method) {
                "publishProgress" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val current = token
                    if (current != null && arguments != null && arguments["token"] == current) {
                        PhoneRunLocationService.progress(current, arguments)
                        offerNotificationPermission()
                    }
                    result.success(null)
                    return@setMethodCallHandler
                }
                "endProgress" -> {
                    // La notificación se retira cuando se detiene el servicio.
                    result.success(null)
                    return@setMethodCallHandler
                }
                "speak" -> {
                    (call.arguments as? String)?.let(::speak)
                    result.success(null)
                    return@setMethodCallHandler
                }
                "silence" -> {
                    pendingSpeech = null
                    speech?.stop()
                    result.success(null)
                    return@setMethodCallHandler
                }
            }
            val requested = call.arguments as? String
            if (requested == null) {
                result.error("invalid_session", null, null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "start" -> requestStart(requested, result)
                "stop" -> {
                    if (token == requested) stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun speak(text: String) {
        if (speechReady) {
            speech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "phone-run")
            return
        }
        pendingSpeech = text to SystemClock.elapsedRealtime()
        if (speech != null) return
        speech = TextToSpeech(activity.applicationContext) { status ->
            Handler(Looper.getMainLooper()).post {
                val engine = speech ?: return@post
                if (status != TextToSpeech.SUCCESS || engine.setLanguage(Locale.forLanguageTag("es-ES")) < 0) {
                    pendingSpeech = null
                    engine.shutdown()
                    speech = null
                    return@post
                }
                engine.setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                speechReady = true
                val latest = pendingSpeech
                pendingSpeech = null
                if (latest != null && SystemClock.elapsedRealtime() - latest.second < 2000) {
                    speak(latest.first)
                }
            }
        }
    }

    private fun offerNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || !activity.hasWindowFocus() ||
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        val preferences = activity.getPreferences(Context.MODE_PRIVATE)
        if (preferences.getBoolean("phone_run_notifications_offered", false)) return
        preferences.edit().putBoolean("phone_run_notifications_offered", true).apply()
        try {
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7317)
        } catch (_: RuntimeException) {
            // El ritmo sigue disponible dentro de la aplicación.
        }
    }

    private fun requestStart(requested: String, result: MethodChannel.Result) {
        if (token != null || permissionDialogOpen) {
            result.error("busy", null, null)
            return
        }
        token = requested
        if (hasPreciseLocation()) {
            start(requested, result)
            return
        }
        pendingPermission = requested to result
        permissionDialogOpen = true
        try {
            activity.requestPermissions(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                LOCATION_PERMISSION_REQUEST,
            )
        } catch (error: RuntimeException) {
            permissionDialogOpen = false
            pendingPermission = null
            token = null
            result.error("permission", null, null)
        }
    }

    fun onPermissionResult(requestCode: Int) {
        if (requestCode != LOCATION_PERMISSION_REQUEST) return
        permissionDialogOpen = false
        val (requested, result) = pendingPermission ?: return
        pendingPermission = null
        if (hasPreciseLocation()) {
            start(requested, result)
        } else {
            token = null
            result.error("permission", null, null)
        }
    }

    private fun hasPreciseLocation() =
        activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun start(requested: String, result: MethodChannel.Result) {
        val context = activity.applicationContext
        val intent = Intent(context, PhoneRunLocationService::class.java)
            .putExtra(PhoneRunLocationService.TOKEN, requested)
        PhoneRunLocationService.prepare(
            requested,
            started = { error ->
                if (error == null) {
                    result.success(null)
                } else {
                    if (token == requested) token = null
                    result.error(error, null, null)
                }
            },
            event = { event -> sink?.success(event + ("token" to requested)) },
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (error: RuntimeException) {
            PhoneRunLocationService.cancel(requested, "unavailable")
        }
    }

    private fun stop() {
        val current = token ?: return
        token = null
        pendingPermission?.second?.error("cancelled", null, null)
        pendingPermission = null
        PhoneRunLocationService.cancel(current, "cancelled")
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        stop()
    }

    fun close() {
        stop()
        pendingSpeech = null
        speech?.shutdown()
        speech = null
        speechReady = false
        sink = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    companion object {
        private const val LOCATION_PERMISSION_REQUEST = 7315
    }
}
