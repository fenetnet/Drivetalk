package app.drivetalk.drivetalk

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Runs only during a detected trip (with the feature turned on):
 * marks me available on the server, checks every 10 seconds whether a friend
 * is free too, and shows (and reads aloud) "X is free now. Talk?".
 * Stops when the trip ends, when "Stop" is tapped, or after 3 hours.
 * Trip availability is a 15-minute lease renewed every 4 minutes.
 */
class DrivingService : Service() {
    companion object {
        const val ACTION_START = "app.drivetalk.driving.START"
        const val ACTION_END = "app.drivetalk.driving.END"
        const val ACTION_MANUAL = "app.drivetalk.driving.MANUAL"
        const val ACTION_QUIET_END = "app.drivetalk.driving.QUIET_END"
        const val ACTION_STOP_ALL = "app.drivetalk.driving.STOP_ALL"
        private const val POLL_MS = 10_000L
        private const val FAST_POLL_MS = 3_000L
        private const val FAST_MS = 2 * 60_000L

        /** The server's quiet first minutes of a trip (5) and a little. */
        private const val TRIP_TELL_MS = 5 * 60_000L + 30_000L
        /** Renew the trip lease well before it runs out. */
        private const val RENEW_MS = 4 * 60 * 1000L
        private const val MAX_MS = 3 * 60 * 60 * 1000L
        /** "In a call" lasts 3 minutes on the server: renew every 2. */
        private const val PHONE_RENEW_MS = 2 * 60 * 1000L

        /** Spoken like directions: other sound is lowered, not stopped. */
        private val VOICE_ATTRS: AudioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        /** The service is running in this process (the app re-arms it if not). */
        @Volatile var watching = false
            private set

        @Volatile private var instance: DrivingService? = null

        /**
         * A push said "something for you" (D-120): look now. False when the
         * service isn't running (then the push itself shows it).
         */
        fun pollNow(): Boolean = instance?.pollSoon() ?: false

        fun start(context: Context) = send(context, ACTION_START)

        fun end(context: Context) = send(context, ACTION_END)

        /** I marked myself free in the app: watch for friends until [until]. */
        fun startManual(context: Context) = send(context, ACTION_MANUAL)

        /** The app already cleared availability: just stop watching. */
        fun quietEnd(context: Context) = send(context, ACTION_QUIET_END)

        /** "Stop" on the notification: clear availability on the server. */
        fun stopAll(context: Context) = send(context, ACTION_STOP_ALL)

        // Allowed from the background: activity-recognition events and
        // notification actions are exempt from Android's start limits.
        // False when Android refused (the caller then must not claim "free").
        private fun send(context: Context, action: String): Boolean {
            val i = Intent(context, DrivingService::class.java).setAction(action)
            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
                true
            } catch (e: Exception) {
                undo(context, action)
                false
            }
        }

        // Android didn't let the service run (battery saver, the daily
        // limit on Android 15…). Never leave "free" on the server without
        // alerts on this phone: undo it and say so.
        private fun undo(context: Context, action: String?) {
            val api = DrivingApi(DrivingStore(context))
            when (action) {
                ACTION_END -> Thread { api.stop() }.start()
                ACTION_STOP_ALL -> Thread { api.stopAll() }.start()
                ACTION_QUIET_END -> Unit
                ACTION_MANUAL -> {
                    Thread { api.stopAll() }.start()
                    DrivingStore(context).availableUntil = 0L
                    QuickFree.refreshAll(context)
                    DrivingNotifications.showProblem(context)
                }
                else -> {
                    Thread { api.stop() }.start()
                    DrivingNotifications.showProblem(context)
                }
            }
        }
    }

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    /** Offers on screen now (to remove them once gone: cancelled, answered, timed out). */
    private val quickShown = mutableSetOf<String>()
    private var startedAt = 0L
    private var renewedAt = 0L
    private var running = false

    /** When the detected trip started (0 = none) and whether friends heard. */
    private var tripAt = 0L
    private var tripTold = false
    private var manual = false
    /** Last "in a call" sent to the server, and when (renewed every 2 minutes). */
    private var phoneBusy = false
    private var phoneSentAt = 0L
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    /** The latest start request (so finishing never stops a newer one). */
    private var lastStartId = 0
    /** One offers request at a time (a slow network must not pile them up). */
    private var polling = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        DrivingNotifications.ensureChannels(this)
        val store = DrivingStore(this)
        // The trip ended, but I'm still free (from the app, the widget or a
        // routine): keep watching until that time, as a manual window.
        // "For the whole trip" ends here instead.
        val keepFree = intent?.action == ACTION_END && running &&
            store.freeNow && !store.endWithTrip
        if (intent?.action == ACTION_MANUAL || keepFree) manual = true
        if (intent?.action == ACTION_START) manual = false
        lastStartId = startId
        val notification = DrivingNotifications.status(this, manual)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    DrivingNotifications.ID_STATUS,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(DrivingNotifications.ID_STATUS, notification)
            }
        } catch (e: Exception) {
            // Refused (e.g. Android 15's daily limit): undo, don't crash.
            if (!running) {
                undo(this, intent?.action)
                stopSelf(startId)
            }
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_END -> when {
                store.freeNow && store.endWithTrip -> {
                    // "For the whole trip": the trip is over, so is my free time.
                    io.execute {
                        DrivingApi(store).stopAll()
                        DrivingEvents.send("quick")
                    }
                    store.availableUntil = 0L
                    finish(callServer = false)
                }
                // The trip ended but my own free time goes on.
                manual && running -> {
                    tripAt = 0L
                    tripTold = false
                }
                else -> finish(callServer = true)
            }
            ACTION_QUIET_END -> finish(callServer = false)
            ACTION_STOP_ALL -> {
                io.execute { DrivingApi(store).stopAll() }
                finish(callServer = false)
            }
            ACTION_MANUAL -> begin(callStart = false)
            else -> begin(callStart = true)
        }
        return START_NOT_STICKY
    }

    private fun begin(callStart: Boolean) {
        if (callStart && tripAt == 0L) tripAt = System.currentTimeMillis()
        if (running) {
            // Already watching (e.g. manual → a trip started): just update.
            if (callStart) io.execute { DrivingApi(DrivingStore(this)).start() }
            return
        }
        running = true
        watching = true
        instance = this
        startedAt = System.currentTimeMillis()
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.forLanguageTag("he-IL")
                tts?.setSpeechRate(1.15f)
                // Like a navigation app: music / Waze get quieter meanwhile.
                tts?.setAudioAttributes(VOICE_ATTRS)
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    override fun onDone(utteranceId: String?) = releaseFocus()
                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) = releaseFocus()
                })
                ttsReady = true
            }
        }
        val store = DrivingStore(this)
        renewedAt = System.currentTimeMillis()
        if (callStart) {
            io.execute {
                val r = DrivingApi(store).start()
                // Quiet hours: the server didn't mark me free, so don't
                // claim "available while driving" for the whole trip.
                if (r == "bad_token" || r == "quiet_hours") {
                    main.post { finish(callServer = false) }
                }
            }
        }
        main.postDelayed(poll, 3_000)
    }

    /** Ticks of [poll]; with push working, offers are fetched every 3rd. */
    private var ticks = 0

    private fun pollSoon(): Boolean {
        if (!running) return false
        main.post {
            callsUntil = System.currentTimeMillis() + 3 * 60_000L
            fastUntil = System.currentTimeMillis() + FAST_MS
            if (running && !polling) {
                polling = true
                io.execute { pollOffers(this) }
            }
        }
        return true
    }

    private val poll: Runnable = object : Runnable {
        override fun run() {
            if (!running) return
            val now = System.currentTimeMillis()
            if (now - startedAt > MAX_MS ||
                (manual && now > DrivingStore(this@DrivingService).availableUntil)
            ) {
                finish(callServer = !manual)
                return
            }
            val ctx = this@DrivingService
            if (!manual && now - renewedAt > RENEW_MS) {
                renewedAt = now
                io.execute { DrivingApi(DrivingStore(ctx)).start() }
            }
            checkPhoneCall(now)
            // After the trip's quiet first minutes: my quick-connect friends
            // hear I'm on the way (once per trip, D-119).
            if (!manual && tripAt > 0L && !tripTold && now - tripAt > TRIP_TELL_MS) {
                tripTold = true
                io.execute { DrivingApi(DrivingStore(ctx)).notifyTrip() }
            }
            // With push working, the server wakes this service when there is
            // something (D-120): looking every 30 seconds is a safety net.
            ticks++
            // Around a question: every 3 seconds, so "agreed" or "cancelled"
            // shows at once (D-129).
            val fast = now < fastUntil
            val due = fast || !DrivingStore(ctx).pushReady || ticks % 3 == 0
            if (due && !polling) {
                polling = true
                io.execute { pollOffers(ctx) }
            }
            main.postDelayed(this, if (fast) FAST_POLL_MS else POLL_MS)
        }
    }

    /** Until when to also ask "is a call agreed?" (after a question was shown). */
    @Volatile private var callsUntil = 0L

    /** Until when to look every 3 seconds (2 minutes from a question). */
    @Volatile private var fastUntil = 0L

    private fun pollOffers(ctx: Context) {
        // null = no answer (network): keep what is shown, try again later.
        val api = DrivingApi(DrivingStore(ctx))
        val offers = api.offers()
        // Only right after a question: a call agreed with me (D-111).
        val calls = if (System.currentTimeMillis() < callsUntil) api.calls() else null
        main.post {
            polling = false
            if (offers == null || !running) return@post
            val store = DrivingStore(ctx)
            for (o in offers) {
                // Remembered on the phone: not repeated after a restart.
                if (store.markShown(o.id)) {
                    fastUntil = System.currentTimeMillis() + FAST_MS
                    DrivingNotifications.showOffer(ctx, o)
                    // In the background "yes" can't be heard: say how to answer.
                    val text = when (o.kind) {
                        "quick" -> store.text("voiceQuick", "{name}")
                        "direct" -> store.text("bgVoiceDirect", store.text("voiceDirect", "{name}"))
                        else -> store.text("bgVoiceOffer", store.text("voiceOffer", "{name}"))
                    }
                    // Said once: in the background "yes" can't be heard, so
                    // repeating it only nags (D-115); the notification stays.
                    speak(text.replace("{name}", o.name))
                }
            }
            if (offers.isNotEmpty()) callsUntil = System.currentTimeMillis() + 3 * 60_000L
            // On screen, the app shows the call itself.
            // In a call right now: the call is already happening.
            val inCall = PhoneState.inCall(ctx)
            for (c in if (MainActivity.onScreen) emptyList<DrivingApi.Call>() else calls ?: emptyList()) {
                if (inCall) {
                    // They're calling me — that's this call: nothing to add,
                    // not even after it ends. (A call I should make waits.)
                    if (!c.iCall) store.markShown("call:${c.id}")
                    continue
                }
                if (store.markShown("call:${c.id}")) {
                    DrivingNotifications.showCall(ctx, c.id, c.name, c.iCall)
                    if (c.iCall) speak(store.text("voiceYouCall", "{name}").replace("{name}", c.name))
                }
            }
            // An offer that's gone (cancelled / answered / timed out): remove it.
            val ids = offers.map { it.id }.toSet()
            for (id in quickShown - ids) DrivingNotifications.cancelOffer(ctx, id)
            quickShown.clear()
            quickShown.addAll(ids)
        }
    }

    /**
     * Is the phone in a call (regular, or e.g. WhatsApp)? Only yes/no, from
     * the sound system: no permission, no number, no call log. Friends then
     * see "in a call" and nobody is offered me until it ends.
     */
    private fun checkPhoneCall(now: Long) {
        val busy = PhoneState.inCall(this)
        if (busy == phoneBusy && !(busy && now - phoneSentAt > PHONE_RENEW_MS)) return
        if (busy && !phoneBusy) {
            // A call started: the open questions are closed (D-121) — stop
            // asking aloud and take their notifications away.
            tts?.stop()
            for (id in quickShown) DrivingNotifications.cancelOffer(this, id)
            quickShown.clear()
        }
        // Remembered only once the server has it (else: again in 10 s).
        phoneSentAt = now
        val store = DrivingStore(this)
        if (busy != phoneBusy) store.log(if (busy) "phone call: yes" else "phone call: ended")
        io.execute {
            val ok = DrivingApi(store).phoneCall(busy) != null
            main.post {
                if (ok) phoneBusy = busy else phoneSentAt = 0L
            }
        }
    }

    private fun speak(text: String, utteranceId: String = "offer") {
        // On screen, the app asks by voice itself — never twice.
        if (MainActivity.onScreen) return
        if (!ttsReady) return
        requestFocus()
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    private var focus: AudioFocusRequest? = null

    private fun requestFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val audio = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return
        val r = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(VOICE_ATTRS)
            .build()
        focus = r
        audio.requestAudioFocus(r)
    }

    private fun releaseFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val audio = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return
        focus?.let { audio.abandonAudioFocusRequest(it) }
        focus = null
    }

    private fun finish(callServer: Boolean) {
        running = false
        watching = false
        if (instance === this) instance = null
        tripAt = 0L
        tripTold = false
        main.removeCallbacks(poll)
        val store = DrivingStore(this)
        // "In a call" doesn't outlive the service.
        if (phoneBusy) io.execute { DrivingApi(store).phoneCall(false) }
        phoneBusy = false
        store.inVehicle = false
        if (callServer) {
            io.execute { DrivingApi(store).stop() }
        }
        for (id in quickShown) DrivingNotifications.cancelOffer(this, id)
        quickShown.clear()
        releaseFocus()
        tts?.shutdown()
        tts = null
        if (manual) store.availableUntil = 0L
        if (!store.freeNow) store.endWithTrip = false
        QuickFree.refreshAll(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf(lastStartId)
    }

    /**
     * Android 15+: a dataSync service gets a few hours a day. When time is
     * up, stop cleanly and tell the server (no "free" left behind).
     */
    override fun onTimeout(startId: Int, fgsType: Int) {
        if (manual) io.execute { DrivingApi(DrivingStore(this)).stopAll() }
        finish(callServer = !manual)
    }

    override fun onDestroy() {
        running = false
        watching = false
        if (instance === this) instance = null
        main.removeCallbacks(poll)
        tts?.shutdown()
        io.shutdown()
        super.onDestroy()
    }
}
