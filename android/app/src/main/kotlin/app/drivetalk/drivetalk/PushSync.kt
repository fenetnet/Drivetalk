package app.drivetalk.drivetalk

import android.content.Context
import android.media.AudioManager

/**
 * A push said "something for you" (a question, or an agreed call — D-120).
 * Shown now even when the app and its background service are closed: the
 * same notifications the service shows, each only once.
 */
object PushSync {
    fun run(context: Context) {
        // On screen, the app shows it itself.
        if (MainActivity.onScreen) return
        // The background service is running: it looks right away.
        if (DrivingService.pollNow()) return
        val store = DrivingStore(context)
        val api = DrivingApi(store)
        val offers = api.offers() ?: return
        for (o in offers) {
            if (store.markShown(o.id)) DrivingNotifications.showOffer(context, o)
        }
        val calls = api.calls() ?: return
        val mode = (context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager)?.mode
        val inCall = mode == AudioManager.MODE_IN_CALL || mode == AudioManager.MODE_IN_COMMUNICATION
        for (c in calls) {
            if (inCall) {
                // They're calling me — that's this call: nothing to add.
                if (!c.iCall) store.markShown("call:${c.id}")
                continue
            }
            if (store.markShown("call:${c.id}")) {
                DrivingNotifications.showCall(context, c.id, c.name, c.iCall)
            }
        }
    }
}
