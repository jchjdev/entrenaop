package com.entrenaOp.entrenaop

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

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

    init {
        events.setStreamHandler(this)
        methods.setMethodCallHandler { call, result ->
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
        sink = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    companion object {
        private const val LOCATION_PERMISSION_REQUEST = 7315
    }
}
