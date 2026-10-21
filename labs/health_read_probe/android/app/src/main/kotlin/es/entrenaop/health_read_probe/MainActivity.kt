package es.entrenaop.health_read_probe

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.health.connect.client.PermissionController

class MainActivity : FlutterFragmentActivity() {
    private var reader: RunningHealthReader? = null
    private var pendingConsent: MethodChannel.Result? = null
    private val permissionLauncher = registerForActivityResult(
        PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        pendingConsent?.success(if (RunningHealthReader.permission in granted) "granted" else "denied")
        pendingConsent = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        reader = RunningHealthReader(this) { result ->
            if (pendingConsent != null) {
                result.error("readFailed", null, null)
            } else {
                pendingConsent = result
                permissionLauncher.launch(setOf(RunningHealthReader.permission))
            }
        }.also { it.attach(flutterEngine.dartExecutor.binaryMessenger) }
    }

    override fun onDestroy() {
        reader?.close()
        reader = null
        pendingConsent = null
        super.onDestroy()
    }
}
