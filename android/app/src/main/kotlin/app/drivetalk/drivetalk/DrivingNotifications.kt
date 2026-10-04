package app.drivetalk.drivetalk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/** Notifications while driving: "you're available" and "X is free — talk?". */
object DrivingNotifications {
    const val CHANNEL_STATUS = "driving_status"
    const val CHANNEL_OFFERS = "driving_offers"
    const val ID_STATUS = 7001
    private const val ID_OFFER_BASE = 7100

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        val store = DrivingStore(context)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_STATUS,
                store.text("channelStatus", "Driving availability"),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_OFFERS,
                store.text("channelOffers", "Someone is free to talk"),
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    private fun builder(context: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

    private fun flags(mutable: Boolean = false): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            f = f or if (mutable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_IMMUTABLE
            }
        }
        return f
    }

    private fun openApp(context: Context, request: Int, offerId: String? = null, accept: Boolean = false): PendingIntent {
        val i = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (offerId != null) {
                putExtra(MainActivity.EXTRA_OFFER, offerId)
                putExtra(MainActivity.EXTRA_ACCEPT, accept)
            }
        }
        return PendingIntent.getActivity(context, request, i, flags())
    }

    private fun broadcast(context: Context, action: String, request: Int, offerId: String? = null): PendingIntent {
        val i = Intent(context, DrivingReceiver::class.java).setAction(action)
        if (offerId != null) i.putExtra(MainActivity.EXTRA_OFFER, offerId)
        return PendingIntent.getBroadcast(context, request, i, flags())
    }

    fun status(context: Context): Notification {
        val store = DrivingStore(context)
        return builder(context, CHANNEL_STATUS)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(store.text("statusTitle", "DriveTalk"))
            .setContentText(store.text("statusBody", "Available to talk while driving"))
            .setOngoing(true)
            .setContentIntent(openApp(context, 1))
            .addAction(
                Notification.Action.Builder(
                    null,
                    store.text("stop", "Stop"),
                    broadcast(context, DrivingReceiver.ACTION_STOP, 2),
                ).build(),
            )
            .build()
    }

    fun showOffer(context: Context, offer: DrivingApi.Offer) {
        val store = DrivingStore(context)
        val req = 100 + (offer.id.hashCode() and 0xffff)
        val quick = offer.kind == "quick"
        val b = builder(context, CHANNEL_OFFERS)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(
                store.text(if (quick) "quickTitle" else "offerTitle", "{name}")
                    .replace("{name}", offer.name),
            )
            .setContentText(store.text(if (quick) "quickBody" else "offerBody", ""))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_CALL)
            .setContentIntent(openApp(context, req, offer.id, accept = false))
            .addAction(
                Notification.Action.Builder(
                    null,
                    store.text("talk", "Talk now"),
                    // Quick connect is already agreed: opening the app connects.
                    openApp(context, req + 1, offer.id, accept = !quick),
                ).build(),
            )
        if (!quick) {
            b.addAction(
                Notification.Action.Builder(
                    null,
                    store.text("notNow", "Not now"),
                    broadcast(context, DrivingReceiver.ACTION_DECLINE, req + 2, offer.id),
                ).build(),
            )
        }
        val n = b
            .apply {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    @Suppress("DEPRECATION")
                    setPriority(Notification.PRIORITY_HIGH)
                }
            }
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(ID_OFFER_BASE + (offer.id.hashCode() and 0xff), n)
    }

    fun cancelOffer(context: Context, offerId: String) {
        context.getSystemService(NotificationManager::class.java)
            .cancel(ID_OFFER_BASE + (offerId.hashCode() and 0xff))
    }
}
