package app.drivetalk.drivetalk

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.util.concurrent.Executors

/**
 * "Who's free now" on the home screen (D-133): up to 3 friends who are free
 * (or in a call), from the app when it refreshes, from a push, and every 30
 * minutes. Tap a friend: the app opens and asks them; tap elsewhere: the
 * app opens. Only names, a mode and minutes left — never a number.
 */
object FreeWidget {
    private val io = Executors.newSingleThreadExecutor()
    private val ROWS = listOf(
        Triple(R.id.friend_row1, R.id.friend_initial1, R.id.friend_name1) to R.id.friend_status1,
        Triple(R.id.friend_row2, R.id.friend_initial2, R.id.friend_name2) to R.id.friend_status2,
        Triple(R.id.friend_row3, R.id.friend_initial3, R.id.friend_name3) to R.id.friend_status3,
    )

    fun installed(context: Context): Boolean =
        AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, FreeFriendsWidget::class.java))
            .isNotEmpty()

    /** The list from the app (same JSON as the server's). */
    fun setFromApp(context: Context, json: String) {
        DrivingStore(context).widgetFriends = json
        updateAll(context)
    }

    /** Ask the server (background thread), then redraw. */
    fun refresh(context: Context, done: (() -> Unit)? = null) {
        val app = context.applicationContext
        if (!installed(app)) {
            done?.invoke()
            return
        }
        io.execute {
            try {
                val store = DrivingStore(app)
                DrivingApi(store).freeFriends()?.let { store.widgetFriends = it }
                updateAll(app)
            } finally {
                done?.invoke()
            }
        }
    }

    fun updateAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, FreeFriendsWidget::class.java))
        if (ids.isEmpty()) return
        val v = views(context)
        for (id in ids) mgr.updateAppWidget(id, v)
    }

    private fun flags(): Int {
        var f = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) f = f or PendingIntent.FLAG_IMMUTABLE
        return f
    }

    private fun views(context: Context): RemoteViews {
        val store = DrivingStore(context)
        val v = RemoteViews(context.packageName, R.layout.widget_friends)
        v.setTextViewText(R.id.friends_title, store.text("widgetTitle", "Free now"))
        val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        v.setOnClickPendingIntent(R.id.friends_root, PendingIntent.getActivity(context, 600, open, flags()))
        val list = try {
            JSONArray(store.widgetFriends)
        } catch (e: Exception) {
            JSONArray()
        }
        val now = System.currentTimeMillis()
        var shown = 0
        for (i in 0 until list.length()) {
            if (shown == ROWS.size) break
            val f = list.optJSONObject(i) ?: continue
            val until = parseTime(f.optString("until"))
            if (until in 1..now) continue // its time is over
            val id = f.optString("id")
            val name = store.nameFor(id, f.optString("name"))
            val busy = f.optBoolean("busy")
            val (ids, statusId) = ROWS[shown]
            val (rowId, initialId, nameId) = ids
            v.setViewVisibility(rowId, View.VISIBLE)
            v.setTextViewText(initialId, name.trim().take(1))
            v.setInt(
                initialId,
                "setBackgroundResource",
                if (busy) R.drawable.widget_avatar_busy else R.drawable.widget_avatar,
            )
            v.setTextViewText(nameId, name)
            val minutes = if (until > 0) ((until - now) / 60_000L).toInt() + 1 else 0
            val status = if (busy) {
                store.text("widgetBusy", "In a call")
            } else {
                val mode = store.text("widgetMode_${f.optString("mode")}", "")
                val left = store.text("widgetLeft", "{m} min").replace("{m}", "$minutes")
                if (mode.isEmpty()) left else "$mode · $left"
            }
            v.setTextViewText(statusId, status)
            // Tap a free friend: the app asks them (only one shown here).
            if (!busy) {
                val ask = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(MainActivity.EXTRA_WIDGET_ASK, id)
                }
                v.setOnClickPendingIntent(rowId, PendingIntent.getActivity(context, 610 + shown, ask, flags()))
            }
            shown++
        }
        for (i in shown until ROWS.size) v.setViewVisibility(ROWS[i].first.first, View.GONE)
        v.setTextViewText(R.id.friends_empty, if (shown == 0) store.text("widgetEmpty", "Nobody is free right now") else "")
        v.setViewVisibility(R.id.friends_empty, if (shown == 0) View.VISIBLE else View.GONE)
        return v
    }

    /** "2026-10-20T18:00:00+00:00" → ms (0 when unknown). */
    private fun parseTime(s: String): Long = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            java.time.OffsetDateTime.parse(s).toInstant().toEpochMilli()
        } else {
            0L
        }
    } catch (e: Exception) {
        0L
    }

    /** Is [id] on the widget right now (a tap may ask only them)? */
    fun shows(context: Context, id: String): Boolean = try {
        val list = JSONArray(DrivingStore(context).widgetFriends)
        (0 until list.length()).any { list.optJSONObject(it)?.optString("id") == id }
    } catch (e: Exception) {
        false
    }
}

class FreeFriendsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        FreeWidget.updateAll(context)
        val pending = goAsync()
        FreeWidget.refresh(context) { pending.finish() }
    }
}
