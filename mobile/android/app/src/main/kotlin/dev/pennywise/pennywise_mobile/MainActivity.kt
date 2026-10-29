package dev.pennywise.pennywise_mobile

import android.os.Bundle
import android.Manifest
import android.content.pm.PackageManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val smsWorker = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.pennywise/bank_sms").setMethodCallHandler { call, result ->
            if (call.method == "requestPermission") {
                if (checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (permissionResult != null) {
                    result.error("permission_busy", "An SMS permission request is already open.", null)
                } else {
                    permissionResult = result
                    requestPermissions(arrayOf(Manifest.permission.RECEIVE_SMS), smsPermissionRequest)
                }
                return@setMethodCallHandler
            }
            smsWorker.execute {
                try {
                    val store = BankSmsStore(applicationContext)
                    val response: Any? = when (call.method) {
                        "status" -> store.status() + mapOf("supported" to true, "permissionGranted" to (checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED))
                        "configure" -> {
                            store.configure(call.argument<Boolean>("enabled") ?: false, call.argument<List<String>>("senders") ?: emptyList())
                            null
                        }
                        "pending" -> store.pending()
                        "acknowledge" -> { store.acknowledge((call.argument<List<String>>("ids") ?: emptyList()).toSet()); null }
                        "clear" -> { store.clear(); null }
                        else -> { runOnUiThread { result.notImplemented() }; return@execute }
                    }
                    runOnUiThread { result.success(response) }
                } catch (_: Exception) {
                    runOnUiThread { result.error("sms_storage_error", "SMS settings or encrypted queue could not be accessed. Existing queued messages were preserved.", null) }
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == smsPermissionRequest) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }

    override fun onDestroy() {
        permissionResult?.error("permission_cancelled", "SMS permission request was interrupted. Please try again.", null)
        permissionResult = null
        smsWorker.shutdown()
        super.onDestroy()
    }

    companion object { private const val smsPermissionRequest = 43102 }
}
