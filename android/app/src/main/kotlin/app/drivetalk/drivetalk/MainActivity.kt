package app.drivetalk.drivetalk

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Regular phone call through the phone's own dialer.
        // direct=true  → ACTION_CALL (needs the CALL_PHONE permission, asked in Dart)
        // direct=false → ACTION_DIAL (dialer opens with the number; user taps call)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.drivetalk/phone")
            .setMethodCallHandler { call, result ->
                if (call.method != "call") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val number = call.argument<String>("number")
                val direct = call.argument<Boolean>("direct") ?: false
                if (number.isNullOrBlank()) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    val action = if (direct) Intent.ACTION_CALL else Intent.ACTION_DIAL
                    startActivity(Intent(action, Uri.parse("tel:$number")))
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
