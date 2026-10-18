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
            // "X is on the way" — a quick-connect friend started a trip.
            "trip" -> {
                val from = data["from"] ?: return
                DrivingNotifications.showTrip(this, from, data["name"].orEmpty())
            }
        }
    }
}
