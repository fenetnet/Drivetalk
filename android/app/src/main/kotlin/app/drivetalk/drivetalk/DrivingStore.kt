package app.drivetalk.drivetalk

import android.content.Context
import android.content.SharedPreferences

/**
 * Settings for automatic driving availability, kept in the app's private
 * storage on this phone. The device token can only start/stop driving
 * availability, list open offers (names) and say "not now" for its owner.
 */
class DrivingStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("drivetalk_driving", Context.MODE_PRIVATE)

    var enabled: Boolean
        get() = prefs.getBoolean("enabled", false)
        set(v) = prefs.edit().putBoolean("enabled", v).apply()

    var inVehicle: Boolean
        get() = prefs.getBoolean("inVehicle", false)
        set(v) = prefs.edit().putBoolean("inVehicle", v).apply()

    val url: String get() = prefs.getString("url", "") ?: ""
    val key: String get() = prefs.getString("key", "") ?: ""
    val token: String get() = prefs.getString("token", "") ?: ""
    val minutes: Int get() = prefs.getInt("minutes", 120)

    /** Texts come from the app (Hebrew strings live in the app's ARB file). */
    fun text(name: String, fallback: String): String =
        prefs.getString("text_$name", null) ?: fallback

    fun save(url: String, key: String, token: String, minutes: Int, texts: Map<String, String>) {
        val e = prefs.edit()
            .putString("url", url.trimEnd('/'))
            .putString("key", key)
            .putString("token", token)
            .putInt("minutes", minutes)
            .putBoolean("enabled", true)
        for ((k, v) in texts) e.putString("text_$k", v)
        e.apply()
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}
