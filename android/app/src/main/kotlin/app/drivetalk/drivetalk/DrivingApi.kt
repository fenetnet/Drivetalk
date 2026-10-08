package app.drivetalk.drivetalk

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** The background calls (device token only). Never on the main thread. */
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

    /**
     * Trip availability is a short lease (15 minutes) that the running
     * service renews: if the phone kills the service, it ends by itself soon.
     */
    fun start(): String? = rpc("auto_start", JSONObject().put("p_minutes", LEASE_MINUTES))?.trim('"')

    companion object {
        const val LEASE_MINUTES = 15
    }

    fun stop(): String? = rpc("auto_stop", JSONObject())?.trim('"')

    /** One tap (widget / tile): free for [minutes]. False if not allowed. */
    fun startManual(minutes: Int, mode: String = "free", circle: String = ""): Boolean {
        val body = JSONObject().put("p_minutes", minutes).put("p_mode", mode)
        if (circle.isNotEmpty()) {
            val r = rpc("device_start", JSONObject(body.toString()).put("p_circle", circle))
            if (r != null) return r.trim() != "null"
            // Older server without circles here: for everyone instead.
        }
        return rpc("device_start", body)?.let { it.trim() != "null" } ?: false
    }

    /** "Stop" on the notification: end any availability (manual too). */
    fun stopAll(): String? = rpc("device_stop", JSONObject())?.trim('"')

    /** Quick connect: cancel during the 5 seconds (reaches the other side). */
    fun cancelCall(offerId: String): Boolean =
        rpc("device_cancel_call", JSONObject().put("p_offer", offerId))?.trim() == "true"

    /** "In a call" (true) / "call ended" (false): friends see "in a call". */
    fun phoneCall(on: Boolean): String? =
        rpc("device_phone_call", JSONObject().put("p_on", on))?.trim('"')

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
                    // The name saved in my contacts, if I have one.
                    store.nameFor(o.optString("other_id", ""), o.optString("other_name", "")),
                    o.optString("kind", "ask"),
                )
            }
        } catch (e: Exception) {
            null
        }
    }
}
