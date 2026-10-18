package app.drivetalk.drivetalk

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Push notifications through Firebase (D-119). Data messages only: the
 * notification itself (texts, "Talk") is built here, like the others.
 */
class PushService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        // Nothing to do here: the app saves the new address the next time it
        // opens (it asks Firebase for the current one).
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        when (data["type"]) {
            // The test button on the app's test screen.
            "test" -> DrivingNotifications.showTest(this)
            // A question or an agreed call for me (D-120).
            "sync" -> PushSync.run(this)
            // For the app's owners: feedback, a crash, a new user.
            "owner" -> DrivingNotifications.showOwner(this, data["what"].orEmpty(), data["name"].orEmpty())
            // A new version on Google Play.
            "version" -> DrivingNotifications.showVersion(this)
            // "X tried to reach you" — they said yes, I didn't answer (D-121).
            "missed" -> {
                val from = data["from"] ?: return
                DrivingNotifications.showMissed(this, from, data["name"].orEmpty(), data["gender"].orEmpty())
            }
            // "X is on the way" — a quick-connect friend started a trip.
            "trip" -> {
                val from = data["from"] ?: return
                DrivingNotifications.showTrip(this, from, data["name"].orEmpty())
            }
        }
    }
}
