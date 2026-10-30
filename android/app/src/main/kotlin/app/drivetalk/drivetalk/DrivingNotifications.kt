package app.drivetalk.drivetalk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

/** Notifications while driving: "you're available" and "X is free — talk?". */
object DrivingNotifications {
    const val CHANNEL_STATUS = "driving_status"
    const val CHANNEL_OFFERS = "driving_offers"

    /** "X is free — talk?": its own soft chime and vibration (D-106). */
    const val CHANNEL_TALK = "talk_offers"
    private val VIBRATION = longArrayOf(0, 120, 90, 120, 90, 380)
    const val ID_STATUS = 7001
    private const val ID_PROBLEM = 7002
    private const val ID_OFFER_BASE = 7100

    /** After "Talk": "X is calling you" / "tap to call X" (its own id). */
    private const val ID_CALL_BASE = 7400

    /** "X is on the way" from a friend (D-119, D-161). */
    const val CHANNEL_TRIP = "friend_trips"
    // Each kind its own 256-wide range (they used to overlap: a new trip
    // notice could replace a call or "tried to reach you").
    private const val ID_TRIP_BASE = 8000

    /** News for me: a new version, owner notes (D-120). */
    const val CHANNEL_NEWS = "app_news"
    private const val ID_OWNER = 8400
    private const val ID_VERSION = 8500

    /** "X tried to reach you" (D-121), one per friend. */
    private const val ID_MISSED_BASE = 8600

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
        val talk = NotificationChannel(
            CHANNEL_TALK,
            store.text("channelTalk", "Talk now?"),
            NotificationManager.IMPORTANCE_HIGH,
        )
        talk.setSound(
            Uri.parse("android.resource://${context.packageName}/${R.raw.offer_chime}"),
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_REQUEST)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        talk.enableVibration(true)
        talk.vibrationPattern = VIBRATION
        nm.createNotificationChannel(talk)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_NEWS,
                store.text("channelNews", "DriveBond news"),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_TRIP,
                store.text("channelTrip", "Friends on the way"),
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

    private fun wakeApp(context: Context, request: Int, offer: DrivingApi.Offer): PendingIntent {
        val i = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_OFFER, offer.id)
            putExtra(MainActivity.EXTRA_ACCEPT, false)
            putExtra(MainActivity.EXTRA_WAKE, true)
            // So the app asks aloud at once, before it has loaded anything.
            putExtra(MainActivity.EXTRA_NAME, offer.name)
            putExtra(MainActivity.EXTRA_KIND, offer.kind)
        }
        return PendingIntent.getActivity(context, request, i, flags())
    }

    private fun broadcast(
        context: Context,
        action: String,
        request: Int,
        offerId: String? = null,
        name: String? = null,
    ): PendingIntent {
        val i = Intent(context, DrivingReceiver::class.java).setAction(action)
        if (offerId != null) i.putExtra(MainActivity.EXTRA_OFFER, offerId)
        if (name != null) i.putExtra(DrivingReceiver.EXTRA_NAME, name)
        return PendingIntent.getBroadcast(context, request, i, flags())
    }

    fun status(context: Context, manual: Boolean = false): Notification {
        val store = DrivingStore(context)
        return builder(context, CHANNEL_STATUS)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text(if (manual) "manualTitle" else "statusTitle", "DriveBond"))
            .setContentText(store.text(if (manual) "manualBody" else "statusBody", ""))
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

    /**
     * Will this question open the app on the screen (like an incoming call)?
     * Only while driving, with the screen off or locked and "full screen"
     * allowed; with the screen in use Android shows the usual pop-up.
     */
    private fun opensApp(context: Context): Boolean {
        if (!DrivingStore(context).drivingNow || MainActivity.onScreen) return false
        if (Build.VERSION.SDK_INT >= 34 &&
            !context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
        ) {
            return false
        }
        val power = context.getSystemService(android.os.PowerManager::class.java)
        val lock = context.getSystemService(android.app.KeyguardManager::class.java)
        return power?.isInteractive == false || lock?.isKeyguardLocked == true
    }

    /** Shows the question; true when it opens the app (which then asks aloud). */
    fun showOffer(context: Context, offer: DrivingApi.Offer): Boolean {
        val opens = opensApp(context)
        val store = DrivingStore(context)
        store.log("question shown (${offer.kind})")
        // The one who asked sees it reached me (D-129); never on this thread.
        Thread { DrivingApi(store).shown(offer.id) }.start()
        val req = 100 + (offer.id.hashCode() and 0xffff)
        val quick = offer.kind == "quick"
        ensureChannels(context)
        val b = builder(context, CHANNEL_TALK)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(
                store.text(
                    when {
                        quick -> "quickTitle"
                        offer.kind == "direct" -> "directTitle"
                        else -> "offerTitle"
                    },
                    "{name}",
                )
                    .replace("{name}", offer.name),
            )
            .setContentText(store.text(if (quick) "quickBody" else "offerBody", ""))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_CALL)
            .setContentIntent(openApp(context, req, offer.id, accept = false))
            .apply {
                // A question is open for 30 seconds: never left behind (D-139).
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) setTimeoutAfter(40_000L)
            }
            .apply {
                // Driving and the app isn't on screen: open it, like an
                // incoming call (over the lock screen), so "yes" can be said
                // aloud. With the screen in use (e.g. navigation) Android
                // shows the usual pop-up instead (D-130).
                if (store.drivingNow && !MainActivity.onScreen) {
                    setFullScreenIntent(wakeApp(context, req + 5, offer), true)
                }
            }
        if (quick) {
            // Agreed in advance: 5 seconds to cancel (server-side), then
            // opening the app starts the call.
            b.addAction(
                Notification.Action.Builder(
                    null,
                    store.text("cancel", "Cancel"),
                    broadcast(context, DrivingReceiver.ACTION_CANCEL_CALL, req + 3, offer.id),
                ).build(),
            )
            b.addAction(
                Notification.Action.Builder(
                    null,
                    store.text("talk", "Talk now"),
                    openApp(context, req + 1, offer.id, accept = false),
                ).build(),
            )
        }
        // "Talk" answers right here (no need to open the app); also on the
        // locked screen, where the name stays hidden (D-111).
        val talk = Notification.Action.Builder(
            null,
            store.text("talk", "Talk now"),
            broadcast(context, DrivingReceiver.ACTION_ACCEPT, req + 1, offer.id, offer.name),
        ).build()
        val notNow = Notification.Action.Builder(
            null,
            store.text("notNow", "Not now"),
            broadcast(context, DrivingReceiver.ACTION_DECLINE, req + 2, offer.id),
        ).build()
        if (!quick) {
            b.addAction(talk)
            b.addAction(notNow)
        }
        val public = builder(context, CHANNEL_TALK)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(
                store.text(if (quick) "publicOffer" else "publicOfferTalk", store.text("publicOffer", "DriveBond")),
            )
            .apply {
                if (!quick) {
                    addAction(talk)
                    addAction(notNow)
                }
            }
            .build()
        b.setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(public)
        val n = b
            .apply {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    @Suppress("DEPRECATION")
                    setPriority(Notification.PRIORITY_HIGH)
                    @Suppress("DEPRECATION")
                    setSound(Uri.parse("android.resource://${context.packageName}/${R.raw.offer_chime}"))
                    @Suppress("DEPRECATION")
                    setVibrate(VIBRATION)
                }
            }
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(ID_OFFER_BASE + (offer.id.hashCode() and 0xff), n)
        return opens
    }

    /** "Couldn't turn on availability in the background — open DriveBond." */
    fun showProblem(context: Context) {
        ensureChannels(context)
        val store = DrivingStore(context)
        // The alerts channel: this one must be seen (the status one is quiet).
        val n = builder(context, CHANNEL_OFFERS)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text("bgFailedTitle", "DriveBond"))
            .setContentText(store.text("bgFailedBody", ""))
            .setAutoCancel(true)
            .setContentIntent(openApp(context, 3))
            .build()
        context.getSystemService(NotificationManager::class.java).notify(ID_PROBLEM, n)
    }

    /**
     * After "Talk" from the notification: what happens now.
     * accepted + they call → "the call from X is on its way";
     * accepted + I call → "tap to call X"; pending → "waiting for X";
     * anything else → "didn't work out this time".
     */
    fun showAnswered(context: Context, offerId: String, name: String, status: String?, iCall: Boolean) {
        // Already agreed before this tap (e.g. in the app): nothing new to say.
        if (status == "handled") return
        val key = when {
            status == "accepted" && !iCall -> "answeredTheyCall"
            status == "accepted" -> "answeredYouCall"
            status == "pending" -> "answeredWaiting"
            // No answer (network, or an older server): answer in the app.
            status == null || status == "" || status == "bad_token" -> "answeredRetry"
            else -> "answeredMissed"
        }
        showCallNote(
            context,
            offerId,
            name,
            key,
            ring = status == "accepted" && iCall,
            accept = key == "answeredRetry",
        )
    }

    /** From the background check: a call I should dial, or one coming to me. */
    fun showCall(context: Context, offerId: String, name: String, iCall: Boolean) {
        DrivingStore(context).log("call shown (${if (iCall) "I call" else "they call"})")
        showCallNote(context, offerId, name, if (iCall) "answeredYouCall" else "answeredTheyCall", ring = iCall)
    }

    private fun showCallNote(
        context: Context,
        offerId: String,
        name: String,
        key: String,
        ring: Boolean,
        accept: Boolean = false,
    ) {
        ensureChannels(context)
        val store = DrivingStore(context)
        val req = 300 + (offerId.hashCode() and 0xffff)
        val b = builder(context, if (ring) CHANNEL_TALK else CHANNEL_OFFERS)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text(key, "{name}").replace("{name}", name))
            .setAutoCancel(true)
            .setContentIntent(openApp(context, req, offerId, accept = accept))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) b.setTimeoutAfter(3 * 60_000L)
        val public = builder(context, CHANNEL_OFFERS)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text("publicOffer", "DriveBond"))
            .build()
        b.setVisibility(Notification.VISIBILITY_PRIVATE).setPublicVersion(public)
        context.getSystemService(NotificationManager::class.java)
            .notify(ID_CALL_BASE + (offerId.hashCode() and 0xff), b.build())
    }

    /**
     * "Dani is on the way — there's time to talk" (D-119). "Talk" opens the
     * app, which asks Dani (my tap is my yes); the friend decides as usual.
     */
    fun showTrip(context: Context, friendId: String, name: String) {
        val store = DrivingStore(context)
        // Only a notification this phone really showed may ask (another
        // app could send the same "open" request).
        store.markShown("trip:$friendId")
        ensureChannels(context)
        val req = 300 + (friendId.hashCode() and 0xffff)
        val talkIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.EXTRA_ASK, friendId)
        }
        val talk = PendingIntent.getActivity(context, req, talkIntent, flags())
        val title = store.text("tripTitle", "{name}").replace("{name}", name)
        val b = builder(context, CHANNEL_TRIP)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(title)
            .setContentText(store.text("tripBody", ""))
            .setAutoCancel(true)
            .setContentIntent(openApp(context, req + 1))
            .addAction(
                Notification.Action.Builder(null, store.text("tripTalk", "Talk"), talk).build(),
            )
            .apply {
                // Gone by itself when the moment has passed (30 minutes).
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) setTimeoutAfter(30 * 60_000L)
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    @Suppress("DEPRECATION")
                    setPriority(Notification.PRIORITY_HIGH)
                }
            }
        context.getSystemService(NotificationManager::class.java)
            .notify(ID_TRIP_BASE + (friendId.hashCode() and 0xff), b.build())
    }

    /** The test screen's "send me a test notification" (D-119). */
    fun showTest(context: Context) {
        val store = DrivingStore(context)
        ensureChannels(context)
        val b = builder(context, CHANNEL_TRIP)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text("pushTestTitle", "DriveBond ✓"))
            .setAutoCancel(true)
            .setContentIntent(openApp(context, 299))
        context.getSystemService(NotificationManager::class.java).notify(ID_TRIP_BASE + 999, b.build())
    }

    /** For the app's owners: new feedback / a crash (D-120). */
    fun showOwner(context: Context, what: String, name: String) {
        // Not for every new user (owner, D-162): only people from my
        // contacts, and those come as the "joined" card in the app.
        if (what != "feedback" && what != "crash") return
        val store = DrivingStore(context)
        ensureChannels(context)
        val title = if (what == "feedback") {
            store.text("ownerFeedback", "New feedback")
        } else {
            store.text("ownerCrash", "A crash")
        }
        val b = builder(context, CHANNEL_NEWS)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(title)
            .setAutoCancel(true)
            .setContentIntent(openApp(context, 298))
        context.getSystemService(NotificationManager::class.java)
            .notify(ID_OWNER + (what.hashCode() and 0x3f), b.build())
    }

    /** "A new version of DriveBond" — opens Google Play (D-120). */
    fun showVersion(context: Context) {
        val store = DrivingStore(context)
        ensureChannels(context)
        val play = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("https://play.google.com/store/apps/details?id=${context.packageName}"),
        ).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
        val b = builder(context, CHANNEL_NEWS)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text("versionTitle", "A new version of DriveBond"))
            .setContentText(store.text("versionBody", ""))
            .setAutoCancel(true)
            .setContentIntent(PendingIntent.getActivity(context, 297, play, flags()))
        context.getSystemService(NotificationManager::class.java).notify(ID_VERSION, b.build())
    }

    /**
     * "X tried to reach you": they said yes, the question closed before I
     * answered (D-121). Only a note; tapping opens the app.
     */
    fun showMissed(context: Context, friendId: String, name: String, gender: String) {
        val store = DrivingStore(context)
        ensureChannels(context)
        val shown = store.nameFor(friendId, name)
        val key = when (gender) {
            "female" -> "missedTitleF"
            "male" -> "missedTitleM"
            else -> "missedTitleO"
        }
        val b = builder(context, CHANNEL_NEWS)
            .setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text(key, "{name}").replace("{name}", shown))
            .setContentText(store.text("missedBody", ""))
            .setAutoCancel(true)
            .setContentIntent(openApp(context, 296))
        context.getSystemService(NotificationManager::class.java)
            .notify(ID_MISSED_BASE + (friendId.hashCode() and 0xff), b.build())
    }

    fun cancelTrip(context: Context, friendId: String) {
        context.getSystemService(NotificationManager::class.java)
            .cancel(ID_TRIP_BASE + (friendId.hashCode() and 0xff))
    }

    fun cancelOffer(context: Context, offerId: String) {
        context.getSystemService(NotificationManager::class.java)
            .cancel(ID_OFFER_BASE + (offerId.hashCode() and 0xff))
    }
}
