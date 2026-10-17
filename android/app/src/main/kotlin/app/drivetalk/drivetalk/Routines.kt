package app.drivetalk.drivetalk

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import org.json.JSONArray
import java.util.Calendar
import java.util.concurrent.Executors

/**
 * "Every weekday at 8:00 I'm driving to work": at the routine's time the
 * phone marks me available by itself (app closed too) and tells me so in a
 * notification. Times are approximate (Android may shift them a few minutes
 * to save battery).
 */
object Routines {
    data class Routine(
        val id: String,
        val days: Set<Int>, // 1 = Monday … 7 = Sunday
        val hour: Int,
        val minute: Int,
        val mode: String,
        val minutes: Int,
        val enabled: Boolean,
        val circle: String = "",
    )

    fun parse(json: String): List<Routine> = try {
        val a = JSONArray(json)
        (0 until a.length()).map {
            val o = a.getJSONObject(it)
            val d = o.getJSONArray("days")
            Routine(
                id = o.getString("id"),
                days = (0 until d.length()).map { i -> d.getInt(i) }.toSet(),
                hour = o.getInt("hour"),
                minute = o.getInt("minute"),
                mode = o.optString("mode", "free"),
                minutes = o.optInt("minutes", 30),
                enabled = o.optBoolean("enabled", true),
                circle = o.optString("circle", ""),
            )
        }
    } catch (e: Exception) {
        emptyList()
    }

    /** Calendar weekday → 1 = Monday … 7 = Sunday (like the app). */
    private fun isoDay(c: Calendar): Int = ((c.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1

    /** Next occurrence (ms) of [r] strictly after [from]. */
    fun next(r: Routine, from: Long): Long? {
        if (!r.enabled || r.days.isEmpty()) return null
        val c = Calendar.getInstance().apply { timeInMillis = from }
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        for (i in 0..7) {
            val d = (c.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, i)
                set(Calendar.HOUR_OF_DAY, r.hour)
                set(Calendar.MINUTE, r.minute)
            }
            if (d.timeInMillis > from && isoDay(d) in r.days) return d.timeInMillis
        }
        return null
    }

    private fun pendingIntent(context: Context): PendingIntent {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(
            context,
            91,
            Intent(context, RoutineReceiver::class.java),
            flags,
        )
    }

    /** (Re)arm one alarm for the earliest upcoming routine. */
    fun schedule(context: Context) {
        val store = DrivingStore(context)
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val pi = pendingIntent(context)
        am.cancel(pi)
        if (!store.configured) return
        val now = System.currentTimeMillis()
        val at = parse(store.routines).mapNotNull { next(it, now) }.minOrNull() ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } else {
            am.set(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    /** The routine whose time is now (within 20 minutes), if any. */
    fun due(context: Context, now: Long): Routine? {
        val c = Calendar.getInstance().apply { timeInMillis = now }
        return parse(DrivingStore(context).routines).firstOrNull { r ->
            if (!r.enabled) return@firstOrNull false
            val start = (c.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, r.hour)
                set(Calendar.MINUTE, r.minute)
                set(Calendar.SECOND, 0)
            }
            isoDay(c) in r.days && now >= start.timeInMillis &&
                now - start.timeInMillis < 20 * 60_000L
        }
    }
}

class RoutineReceiver : BroadcastReceiver() {
    companion object {
        private val io = Executors.newSingleThreadExecutor()
        /** "Yes, I have time" on the routine's question (see [ask]). */
        const val ACTION_GO = "app.drivetalk.routine.GO"
        private const val EXTRA_MINUTES = "minutes"
        private const val EXTRA_MODE = "mode"
        private const val EXTRA_CIRCLE = "circle"
        private const val ID_NOTE = 7050
        private const val ID_ASK = 7051

        /**
         * Android 12+ lets an alarm start the background watcher only when
         * battery optimization is off for the app ("background work" in
         * the permissions). Otherwise the routine asks with one tap instead
         * — a tap may start it.
         */
        fun canStartWatcher(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
            val pm = context.getSystemService(PowerManager::class.java) ?: return false
            return pm.isIgnoringBatteryOptimizations(context.packageName)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        val store = DrivingStore(app)
        val now = System.currentTimeMillis()
        val go = intent.action == ACTION_GO
        val r = if (go) null else Routines.due(app, now)
        val pending = goAsync()
        io.execute {
            try {
                if (go) {
                    app.getSystemService(NotificationManager::class.java).cancel(ID_ASK)
                    if (store.configured && !store.freeNow) {
                        start(
                            app,
                            store,
                            intent.getIntExtra(EXTRA_MINUTES, 30),
                            intent.getStringExtra(EXTRA_MODE) ?: "free",
                            intent.getStringExtra(EXTRA_CIRCLE) ?: "",
                        )
                    }
                } else if (r != null && store.configured && !store.freeNow) {
                    if (canStartWatcher(app)) {
                        start(app, store, r.minutes, r.mode, r.circle)
                    } else {
                        // Never "free" on the server without alerts here:
                        // ask first, one tap turns it on.
                        ask(app, store, r)
                    }
                }
            } finally {
                Routines.schedule(app)
                QuickFree.refreshAll(app)
                pending.finish()
            }
        }
    }

    private fun start(app: Context, store: DrivingStore, minutes: Int, mode: String, circle: String) {
        val now = System.currentTimeMillis()
        val ok = DrivingApi(store).startManual(minutes, mode, circle)
        if (ok) {
            store.availableUntil = now + minutes * 60_000L
            store.endWithTrip = false
            // Refused by Android: it already undid "free" and
            // said so — no "you're free now" notice then.
            if (DrivingService.startManual(app)) {
                notify(app, store)
            }
            DrivingEvents.send("quick")
        }
    }

    private fun flags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) f = f or PendingIntent.FLAG_IMMUTABLE
        return f
    }

    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        92,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        flags(),
    )

    private fun builder(context: Context): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, DrivingNotifications.CHANNEL_OFFERS)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

    private fun notify(context: Context, store: DrivingStore) {
        DrivingNotifications.ensureChannels(context)
        val n = builder(context).setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text("routineTitle", "DriveBond"))
            .setContentText(store.text("routineBody", ""))
            .setAutoCancel(true)
            .setContentIntent(openApp(context))
            .build()
        context.getSystemService(NotificationManager::class.java).notify(ID_NOTE, n)
    }

    /** "Your usual time — do you have time now?" with "Yes" (one tap). */
    private fun ask(context: Context, store: DrivingStore, r: Routines.Routine) {
        DrivingNotifications.ensureChannels(context)
        val i = Intent(context, RoutineReceiver::class.java)
            .setAction(ACTION_GO)
            .putExtra(EXTRA_MINUTES, r.minutes)
            .putExtra(EXTRA_MODE, r.mode)
            .putExtra(EXTRA_CIRCLE, r.circle)
        val yes = PendingIntent.getBroadcast(context, 93, i, flags())
        val label = store.text("routineAskYes", "Yes")
        val action = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(context, R.drawable.ic_stat_drivetalk),
                label,
                yes,
            ).build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Action.Builder(R.drawable.ic_stat_drivetalk, label, yes).build()
        }
        val b = builder(context).setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text("routineAskTitle", "DriveBond"))
            .setContentText(
                store.text("routineAskBody", "{minutes}").replace("{minutes}", r.minutes.toString()),
            )
            .setAutoCancel(true)
            .setContentIntent(openApp(context))
            .addAction(action)
        // Gone by itself once the routine's moment has passed.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) b.setTimeoutAfter(20 * 60_000L)
        context.getSystemService(NotificationManager::class.java).notify(ID_ASK, b.build())
    }
}
