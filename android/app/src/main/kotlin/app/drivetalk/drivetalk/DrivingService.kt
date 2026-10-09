package app.drivetalk.drivetalk

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
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
        /** Renew the trip lease well before it runs out. */
        private const val RENEW_MS = 4 * 60 * 1000L
        private const val MAX_MS = 3 * 60 * 60 * 1000L
        /** "In a call" lasts 3 minutes on the server: renew every 2. */
        private const val PHONE_RENEW_MS = 2 * 60 * 1000L

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
        if (intent?.action == ACTION_MANUAL) manual = true
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
            ACTION_END -> if (manual && running) Unit else finish(callServer = true)
            ACTION_QUIET_END -> finish(callServer = false)
            ACTION_STOP_ALL -> {
                val store = DrivingStore(this)
                io.execute { DrivingApi(store).stopAll() }
                finish(callServer = false)
            }
            ACTION_MANUAL -> begin(callStart = false)
            else -> begin(callStart = true)
        }
        return START_NOT_STICKY
    }

    private fun begin(callStart: Boolean) {
        if (running) {
            // Already watching (e.g. manual → a trip started): just update.
            if (callStart) io.execute { DrivingApi(DrivingStore(this)).start() }
            return
        }
        running = true
        startedAt = System.currentTimeMillis()
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.forLanguageTag("he-IL")
                tts?.setSpeechRate(1.15f)
                ttsReady = true
            }
        }
        val store = DrivingStore(this)
        renewedAt = System.currentTimeMillis()
        if (callStart) {
            io.execute {
                val r = DrivingApi(store).start()
                if (r == "bad_token") main.post { finish(callServer = false) }
            }
        }
        main.postDelayed(poll, 3_000)
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
            if (!polling) {
                polling = true
                io.execute { pollOffers(ctx) }
            }
            main.postDelayed(this, POLL_MS)
        }
    }

    private fun pollOffers(ctx: Context) {
        // null = no answer (network): keep what is shown, try again later.
        val offers = DrivingApi(DrivingStore(ctx)).offers()
        main.post {
            polling = false
            if (offers == null || !running) return@post
            val store = DrivingStore(ctx)
            for (o in offers) {
                // Remembered on the phone: not repeated after a restart.
                if (store.markShown(o.id)) {
                    DrivingNotifications.showOffer(ctx, o)
                    val key = if (o.kind == "quick") "voiceQuick" else "voiceOffer"
                    speak(store.text(key, "{name}").replace("{name}", o.name))
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
        val audio = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return
        val busy = audio.mode == AudioManager.MODE_IN_CALL ||
            audio.mode == AudioManager.MODE_IN_COMMUNICATION
        if (busy == phoneBusy && !(busy && now - phoneSentAt > PHONE_RENEW_MS)) return
        // Remembered only once the server has it (else: again in 10 s).
        phoneSentAt = now
        val store = DrivingStore(this)
        io.execute {
            val ok = DrivingApi(store).phoneCall(busy) != null
            main.post {
                if (ok) phoneBusy = busy else phoneSentAt = 0L
            }
        }
    }

    private fun speak(text: String) {
        // On screen, the app asks by voice itself — never twice.
        if (MainActivity.onScreen) return
        if (ttsReady) tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "offer")
    }

    private fun finish(callServer: Boolean) {
        running = false
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
        tts?.shutdown()
        tts = null
        if (manual) store.availableUntil = 0L
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
        main.removeCallbacks(poll)
        tts?.shutdown()
        io.shutdown()
        super.onDestroy()
    }
}
