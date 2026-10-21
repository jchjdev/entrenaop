package es.entrenaop.health_read_probe

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

internal class RunningHealthReader(
    private val activity: FlutterFragmentActivity,
    private val askConsent: (MethodChannel.Result) -> Unit,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "es.entrenaop.device_health/reader").also {
            it.setMethodCallHandler(::handle)
        }
    }

    private fun status(): String = when (HealthConnectClient.getSdkStatus(activity)) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "updateRequired"
        else -> "unavailable"
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "status") {
            result.success(status())
            return
        }
        if (status() != "available") {
            result.error("unavailable", null, null)
            return
        }
        when (call.method) {
            "requestReadAccess" -> askConsent(result)
            "readRuns" -> scope.launch {
                try {
                    result.success(readRuns(call))
                } catch (_: SecurityException) {
                    result.error("permissionRequired", null, null)
                } catch (_: CancellationException) {
                    result.error("readFailed", null, null)
                } catch (_: Exception) {
                    // Los errores nativos no exponen registros ni mensajes de salud.
                    result.error("readFailed", null, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun readRuns(call: MethodCall): Map<String, Any> {
        val startMicros = call.argument<Number>("startMicros")?.toLong()
            ?: throw IllegalArgumentException()
        val endMicros = call.argument<Number>("endMicros")?.toLong()
            ?: throw IllegalArgumentException()
        require(startMicros >= 0 && endMicros > startMicros)
        require(endMicros - startMicros <= 7L * 86400 * 1000000)
        val start = instant(startMicros)
        val end = instant(endMicros)
        val client = HealthConnectClient.getOrCreate(activity)
        if (permission !in client.permissionController.getGrantedPermissions()) throw SecurityException()
        val runs = mutableListOf<Map<String, Any>>()
        var token: String? = null
        var pages = 0
        var truncated = false
        do {
            if (!activity.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                throw SecurityException()
            }
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                    ascendingOrder = false,
                    pageSize = 100,
                    pageToken = token,
                )
            )
            for (record in response.records) {
                if (record.exerciseType != ExerciseSessionRecord.EXERCISE_TYPE_RUNNING &&
                    record.exerciseType != ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL) continue
                if (record.startTime.isBefore(start) || record.endTime.isAfter(end)) continue
                if (runs.size >= 200) {
                    truncated = true
                    break
                }
                val values = mutableMapOf<String, Any>(
                    "id" to record.metadata.id,
                    "kind" to "running",
                    "startMicros" to micros(record.startTime),
                    "endMicros" to micros(record.endTime),
                    "modifiedMicros" to micros(record.metadata.lastModifiedTime),
                    "writerApplication" to record.metadata.dataOrigin.packageName,
                )
                record.startZoneOffset?.let { values["startOffsetSeconds"] = it.totalSeconds }
                record.endZoneOffset?.let { values["endOffsetSeconds"] = it.totalSeconds }
                record.metadata.device?.manufacturer?.takeIf { it.isNotBlank() }?.let {
                    values["deviceBrand"] = it
                }
                // No agregamos DistanceRecord de otras fuentes ni deducimos pausas.
                runs.add(values)
            }
            token = response.pageToken
            pages++
        } while (!truncated && token != null && pages < 20)
        return mapOf("runs" to runs, "truncated" to (truncated || token != null))
    }

    fun close() {
        channel?.setMethodCallHandler(null)
        scope.cancel()
    }

    companion object {
        val permission = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        private fun instant(micros: Long): Instant = Instant.ofEpochSecond(micros / 1000000, (micros % 1000000) * 1000)
        private fun micros(instant: Instant): Long = instant.epochSecond * 1000000 + instant.nano / 1000
    }
}
