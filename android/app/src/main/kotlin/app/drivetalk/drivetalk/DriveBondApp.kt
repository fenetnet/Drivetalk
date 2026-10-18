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
        try {
            noteHangs(this)
        } catch (_: Throwable) {
            // Never fail at start because of a note.
        }
    }

    companion object {
        // The same place the app's settings live (shared_preferences).
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY = "flutter.real.crashes.v1"
        private const val EXIT_KEY = "driveBondLastExit"

        /**
         * The app froze ("not responding") or crashed below Kotlin since the
         * last start: Android remembers it (11+); noted like a crash, so the
         * owner hears about it too (D-120). Only the kind and Android's short
         * description — no personal data.
         */
        private fun noteHangs(context: Context) {
            if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.R) return
            val am = context.getSystemService(android.app.ActivityManager::class.java) ?: return
            val own = context.getSharedPreferences("drivebond_exits", Context.MODE_PRIVATE)
            val last = own.getLong(EXIT_KEY, 0L)
            var newest = last
            for (e in am.getHistoricalProcessExitReasons(context.packageName, 0, 5)) {
                if (e.timestamp <= last) continue
                newest = maxOf(newest, e.timestamp)
                val kind = when (e.reason) {
                    android.app.ApplicationExitInfo.REASON_ANR -> "android_hang"
                    android.app.ApplicationExitInfo.REASON_CRASH_NATIVE -> "android_native"
                    else -> continue
                }
                // The first start ever only sets the mark (no old news).
                if (last == 0L) continue
                note(context, kind, (e.description ?: kind).take(500), "")
            }
            if (newest != last) own.edit().putLong(EXIT_KEY, newest).apply()
        }

        private fun note(context: Context, kind: String, message: String, stack: String) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val queue = try {
                JSONArray(prefs.getString(KEY, "[]"))
            } catch (_: Exception) {
                JSONArray()
            }
            queue.put(JSONObject().put("kind", kind).put("message", message).put("stack", stack))
            val keep = JSONArray()
            for (i in maxOf(0, queue.length() - 5) until queue.length()) keep.put(queue.get(i))
            prefs.edit().putString(KEY, keep.toString()).commit()
        }

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
