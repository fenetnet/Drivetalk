package app.drivetalk.drivetalk

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val callPermissionRequest = 4711
    private var pendingNumber: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Regular phone call through the phone's own dialer.
        // With the CALL_PHONE permission: one tap (ACTION_CALL).
        // Without it: the dialer opens with the number filled in (ACTION_DIAL).
        // Returns "calling", "dialer" or "failed".
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.drivetalk/phone")
            .setMethodCallHandler { call, result ->
                if (call.method != "call") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val number = call.argument<String>("number")
                if (number.isNullOrBlank()) {
                    result.success("failed")
                    return@setMethodCallHandler
                }
                if (hasCallPermission()) {
                    result.success(place(number, direct = true))
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    pendingNumber = number
                    pendingResult = result
                    requestPermissions(arrayOf(Manifest.permission.CALL_PHONE), callPermissionRequest)
                } else {
                    result.success(place(number, direct = false))
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != callPermissionRequest) return
        val number = pendingNumber
        val result = pendingResult
        pendingNumber = null
        pendingResult = null
        if (number == null || result == null) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(place(number, direct = granted))
    }

    private fun hasCallPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED

    private fun place(number: String, direct: Boolean): String = try {
        val action = if (direct) Intent.ACTION_CALL else Intent.ACTION_DIAL
        startActivity(Intent(action, Uri.parse("tel:$number")))
        if (direct) "calling" else "dialer"
    } catch (e: Exception) {
        "failed"
    }
}
