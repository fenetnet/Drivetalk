package app.drivetalk.drivetalk

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.app.PendingIntent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.RemoteViews
import java.util.concurrent.Executors

/**
 * One tap "I'm free" (30 minutes) / "stop", from the home-screen widget or
 * the quick-settings tile, without opening the app.
 */
object QuickFree {
    private val io = Executors.newSingleThreadExecutor()
    private const val MINUTES = 30

    fun toggle(context: Context, done: (() -> Unit)? = null) {
        val app = context.applicationContext
        val store = DrivingStore(app)
        if (!store.configured) {
            // Not signed in on this phone yet: open the app.
            app.startActivity(
                Intent(app, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            return
        }
        val wasFree = store.freeNow
        // Show the new state right away; the server call follows.
        store.availableUntil = if (wasFree) 0L else System.currentTimeMillis() + MINUTES * 60_000L
        refreshAll(app)
        // Refused by Android: "free" was undone (and explained) already.
        val started = if (wasFree) {
            DrivingService.stopAll(app)
            true
        } else {
            DrivingService.startManual(app)
        }
        io.execute {
            if (!wasFree && started) {
                val ok = DrivingApi(store).startManual(MINUTES)
                if (!ok) {
                    store.availableUntil = 0L
                    DrivingService.quietEnd(app)
                }
            }
            DrivingEvents.send("quick")
            Handler(Looper.getMainLooper()).post {
                refreshAll(app)
                done?.invoke()
            }
        }
    }

    fun refreshAll(context: Context) {
        QuickWidget.updateAll(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                TileService.requestListeningState(
                    context,
                    ComponentName(context, QuickTileService::class.java),
                )
            } catch (e: Exception) {
                // Tile not added.
            }
        }
    }

    fun label(context: Context): String {
        val store = DrivingStore(context)
        return if (store.freeNow) {
            store.text("quickOn", "Free · tap to stop")
        } else {
            store.text("quickOff", "I'm free now")
        }
    }
}

/** Home-screen widget: one big button. */
class QuickWidget : AppWidgetProvider() {
    companion object {
        const val ACTION_TOGGLE = "app.drivetalk.quick.TOGGLE"

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, QuickWidget::class.java))
            if (ids.isEmpty()) return
            for (id in ids) mgr.updateAppWidget(id, views(context))
        }

        private fun views(context: Context): RemoteViews {
            val free = DrivingStore(context).freeNow
            val v = RemoteViews(context.packageName, R.layout.widget_free)
            v.setTextViewText(R.id.widget_text, QuickFree.label(context))
            v.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (free) R.drawable.widget_bg_on else R.drawable.widget_bg_off,
            )
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flags = flags or PendingIntent.FLAG_IMMUTABLE
            val i = Intent(context, QuickWidget::class.java).setAction(ACTION_TOGGLE)
            v.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getBroadcast(context, 77, i, flags))
            return v
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) mgr.updateAppWidget(id, views(context))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE) {
            val pending = goAsync()
            QuickFree.toggle(context) { pending.finish() }
        }
    }
}

/** Quick-settings tile (pull down the notification shade). */
class QuickTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        val store = DrivingStore(this)
        tile.state = if (store.freeNow) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = store.text("tileLabel", "DriveBond")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = QuickFree.label(this)
        }
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_drivetalk)
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        QuickFree.toggle(this) { onStartListening() }
    }
}
