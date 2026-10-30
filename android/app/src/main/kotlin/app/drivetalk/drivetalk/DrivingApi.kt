package app.drivetalk.drivetalk

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** The background calls (device token only). Never on the main thread. */
class DrivingApi(private val store: DrivingStore) {


    /**
     * kind: "ask" (talk?), "direct" (a friend tapped me: "X wants to talk
     * with you") or "quick" (quick connect, already agreed).
     */
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

    /** Asks the push server function [body] (D-119/D-120). Quietly does nothing on failure. */
    private fun callPush(body: JSONObject) {
        if (store.url.isEmpty() || store.key.isEmpty()) return
        try {
            val c = URL("${store.url}/functions/v1/$PUSH_FUNCTION").openConnection() as HttpURLConnection
            c.requestMethod = "POST"
            c.connectTimeout = 10_000
            c.readTimeout = 20_000
            c.doOutput = true
            c.setRequestProperty("apikey", store.key)
            c.setRequestProperty("Content-Type", "application/json")
            c.outputStream.use { it.write(body.toString().toByteArray()) }
            c.responseCode
            c.disconnect()
        } catch (e: Exception) {
            // Not set up yet, or no network: the phones still poll.
        }
    }

    /**
     * "I'm on the way": the push function tells my quick-connect friends
     * (D-119; the server decides who, at most once a day each).
     */
    fun notifyTrip() {
        if (store.token.isEmpty()) return
        callPush(JSONObject().put("kind", "trip").put("device_token", store.token))
    }

    /** After my action: whatever the server queued for others goes out now (D-120). */
    fun kick() = callPush(JSONObject().put("kind", "flush"))

    /**
     * Trip availability is a short lease (15 minutes) that the running
     * service renews: if the phone kills the service, it ends by itself soon.
     */
    fun start(): String? =
        rpc("auto_start", JSONObject().put("p_minutes", LEASE_MINUTES))?.trim('"')?.also { kick() }

    companion object {
        /** The push server function as deployed in Supabase (D-119). */
        const val PUSH_FUNCTION = "smooth-responder"

        const val LEASE_MINUTES = 15
    }

    fun stop(): String? = rpc("auto_stop", JSONObject())?.trim('"')

    /** One tap (widget / tile): free for [minutes]. False if not allowed. */
    fun startManual(minutes: Int, mode: String = "free", circle: String = ""): Boolean {
        val body = JSONObject().put("p_minutes", minutes).put("p_mode", mode)
        if (circle.isNotEmpty()) {
            val r = rpc("device_start", JSONObject(body.toString()).put("p_circle", circle))
            if (r != null) return (r.trim() != "null").also { if (it) kick() }
            // Older server without circles here: for everyone instead.
        }
        return (rpc("device_start", body)?.let { it.trim() != "null" } ?: false).also { if (it) kick() }
    }

    /** "Stop" on the notification: end any availability (manual too). */
    fun stopAll(): String? = rpc("device_stop", JSONObject())?.trim('"')

    /** Quick connect: cancel during the 5 seconds (reaches the other side). */
    fun cancelCall(offerId: String): Boolean =
        rpc("device_cancel_call", JSONObject().put("p_offer", offerId))?.trim() == "true"

    /** "In a call" (true) / "call ended" (false): friends see "in a call". */
    fun phoneCall(on: Boolean): String? =
        // A call closes my open questions: the one who said yes is told (D-121).
        rpc("device_phone_call", JSONObject().put("p_on", on))?.trim('"')?.also { if (on) kick() }

    /** Free friends for the home-screen widget (JSON, D-133); null = no answer. */
    fun freeFriends(): String? = rpc("device_free_friends", JSONObject())?.takeIf { it.trim().startsWith("[") }

    /** "It reached my phone" — the one who asked sees it (D-129). */
    fun shown(offerId: String): String? =
        rpc("device_offer_shown", JSONObject().put("p_offer", offerId))?.trim('"')

    fun decline(offerId: String): String? =
        rpc("auto_decline", JSONObject().put("p_offer", offerId))?.trim('"')

    /** "Talk" from the notification: status ("accepted", "pending", …) and who dials. */
    data class Answer(val status: String, val iCall: Boolean)

    fun answer(offerId: String): Answer? {
        val text = rpc("device_answer", JSONObject().put("p_offer", offerId)) ?: return null
        kick()
        return try {
            val o = JSONObject(text)
            Answer(o.optString("status", ""), o.optBoolean("i_call", false))
        } catch (e: Exception) {
            null
        }
    }

    /** A call agreed in the last 2 minutes: do I dial (iCall), or do they? */
    data class Call(val id: String, val name: String, val iCall: Boolean)

    fun calls(): List<Call>? {
        val text = rpc("device_calls", JSONObject()) ?: return null
        return try {
            val arr = JSONArray(text)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                Call(
                    o.getString("offer_id"),
                    store.nameFor(o.optString("other_id", ""), o.optString("other_name", "")),
                    o.optBoolean("i_call", false),
                )
            }
        } catch (e: Exception) {
            null
        }
    }

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
