package app.drivetalk.drivetalk

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Runs only during a detected trip (with the feature turned on):
 * marks me available on the server, checks every 20 seconds whether a friend
 * is free too, and shows (and reads aloud) "X is free now. Talk?".
 * Stops when the trip ends, when "Stop" is tapped, or after 3 hours.
 */
class DrivingService : Service() {
    companion object {
        const val ACTION_START = "app.drivetalk.driving.START"
        const val ACTION_END = "app.drivetalk.driving.END"
        const val ACTION_MANUAL = "app.drivetalk.driving.MANUAL"
        const val ACTION_QUIET_END = "app.drivetalk.driving.QUIET_END"
        const val ACTION_STOP_ALL = "app.drivetalk.driving.STOP_ALL"
        private const val POLL_MS = 20_000L
        private const val MAX_MS = 3 * 60 * 60 * 1000L

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
        private fun send(context: Context, action: String) {
            val i = Intent(context, DrivingService::class.java).setAction(action)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (e: Exception) {
                // Not allowed right now: at least keep the server in sync
                // (no background alerts until the app is opened).
                val api = DrivingApi(DrivingStore(context))
                when (action) {
                    ACTION_END -> Thread { api.stop() }.start()
                    ACTION_START -> Thread { api.start() }.start()
                    ACTION_STOP_ALL -> Thread { api.stopAll() }.start()
                }
            }
        }
    }

    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val shown = mutableSetOf<String>()
    private var startedAt = 0L
    private var running = false
    private var manual = false
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        DrivingNotifications.ensureChannels(this)
        if (intent?.action == ACTION_MANUAL) manual = true
        if (intent?.action == ACTION_START) manual = false
        val notification = DrivingNotifications.status(this, manual)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                DrivingNotifications.ID_STATUS,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(DrivingNotifications.ID_STATUS, notification)
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
            io.execute {
                val offers = DrivingApi(DrivingStore(ctx)).offers() ?: emptyList()
                main.post {
                    for (o in offers) {
                        if (shown.add(o.id)) {
                            DrivingNotifications.showOffer(ctx, o)
                            val key = if (o.kind == "quick") "voiceQuick" else "voiceOffer"
                            speak(DrivingStore(ctx).text(key, "{name}").replace("{name}", o.name))
                        }
                    }
                }
            }
            main.postDelayed(this, POLL_MS)
        }
    }

    private fun speak(text: String) {
        if (ttsReady) tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "offer")
    }

    private fun finish(callServer: Boolean) {
        running = false
        main.removeCallbacks(poll)
        val store = DrivingStore(this)
        store.inVehicle = false
        if (callServer) {
            io.execute { DrivingApi(store).stop() }
        }
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
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        main.removeCallbacks(poll)
        tts?.shutdown()
        io.shutdown()
        super.onDestroy()
    }
}
