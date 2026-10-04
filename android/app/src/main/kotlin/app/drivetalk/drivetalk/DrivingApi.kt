package app.drivetalk.drivetalk

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** The four background calls (device token only). Never on the main thread. */
class DrivingApi(private val store: DrivingStore) {

    /** kind: "ask" (talk?) or "quick" (quick connect, already agreed). */
    data class Offer(val id: String, val name: String, val kind: String = "ask")

    private fun rpc(fn: String, body: JSONObject): String? {
        if (store.url.isEmpty() || store.key.isEmpty() || store.token.isEmpty()) return null
        return try {
            val c = URL("${store.url}/rest/v1/rpc/$fn").openConnection() as HttpURLConnection
            c.requestMethod = "POST"
            c.connectTimeout = 10_000
            c.readTimeout = 10_000
            c.doOutput = true
            c.setRequestProperty("apikey", store.key)
            c.setRequestProperty("Content-Type", "application/json")
            c.outputStream.use { it.write(body.put("p_token", store.token).toString().toByteArray()) }
            val ok = c.responseCode in 200..299
            val text = (if (ok) c.inputStream else c.errorStream)?.bufferedReader()?.use { it.readText() }
            c.disconnect()
            if (ok) text else null
        } catch (e: Exception) {
            null
        }
    }

    fun start(): String? = rpc("auto_start", JSONObject().put("p_minutes", store.minutes))?.trim('"')

    fun stop(): String? = rpc("auto_stop", JSONObject())?.trim('"')

    /** One tap (widget / tile): free for [minutes]. False if not allowed. */
    fun startManual(minutes: Int): Boolean =
        rpc("device_start", JSONObject().put("p_minutes", minutes))
            ?.let { it.trim() != "null" } ?: false

    /** "Stop" on the notification: end any availability (manual too). */
    fun stopAll(): String? = rpc("device_stop", JSONObject())?.trim('"')

    fun decline(offerId: String): String? =
        rpc("auto_decline", JSONObject().put("p_offer", offerId))?.trim('"')

    fun offers(): List<Offer>? {
        val text = rpc("auto_offers", JSONObject()) ?: return null
        return try {
            val arr = JSONArray(text)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                Offer(
                    o.getString("offer_id"),
                    o.optString("other_name", ""),
                    o.optString("kind", "ask"),
                )
            }
        } catch (e: Exception) {
            null
        }
    }
}
