package app.drivetalk.drivetalk

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
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
    }

    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        val store = DrivingStore(app)
        val now = System.currentTimeMillis()
        val r = Routines.due(app, now)
        val pending = goAsync()
        io.execute {
            try {
                if (r != null && store.configured && !store.freeNow) {
                    val ok = DrivingApi(store).startManual(r.minutes, r.mode)
                    if (ok) {
                        store.availableUntil = now + r.minutes * 60_000L
                        DrivingService.startManual(app)
                        notify(app, store)
                        DrivingEvents.send("quick")
                    }
                }
            } finally {
                Routines.schedule(app)
                QuickFree.refreshAll(app)
                pending.finish()
            }
        }
    }

    private fun notify(context: Context, store: DrivingStore) {
        DrivingNotifications.ensureChannels(context)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags = flags or PendingIntent.FLAG_IMMUTABLE
        val open = PendingIntent.getActivity(
            context,
            92,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            flags,
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, DrivingNotifications.CHANNEL_OFFERS)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val n = b.setSmallIcon(R.drawable.ic_stat_drivetalk)
            .setContentTitle(store.text("routineTitle", "DriveTalk"))
            .setContentText(store.text("routineBody", ""))
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        context.getSystemService(NotificationManager::class.java).notify(7050, n)
    }
}
