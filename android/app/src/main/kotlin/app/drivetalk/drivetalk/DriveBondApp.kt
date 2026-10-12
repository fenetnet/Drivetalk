package app.drivetalk.drivetalk

import android.content.Context
import android.app.Application
import org.json.JSONArray
import org.json.JSONObject

/**
 * A crash in the Android part (e.g. the driving service): keep a short
 * technical note for the app to send the owner on its next start
 * (no personal data). The phone then handles the crash as usual.
 */
class DriveBondApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                remember(this, error)
            } catch (_: Throwable) {
                // Never fail while noting a crash.
            }
            previous?.uncaughtException(thread, error)
        }
    }

    companion object {
        // The same place the app's settings live (shared_preferences).
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY = "flutter.real.crashes.v1"

        fun remember(context: Context, error: Throwable) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val queue = try {
                JSONArray(prefs.getString(KEY, "[]"))
            } catch (_: Exception) {
                JSONArray()
            }
            val stack = android.util.Log.getStackTraceString(error)
            queue.put(
                JSONObject()
                    .put("kind", "android")
                    .put("message", "$error".take(500))
                    .put("stack", stack.take(4000)),
            )
            val keep = JSONArray()
            for (i in maxOf(0, queue.length() - 5) until queue.length()) keep.put(queue.get(i))
            // commit(): the process is about to end.
            prefs.edit().putString(KEY, keep.toString()).commit()
        }
    }
}
