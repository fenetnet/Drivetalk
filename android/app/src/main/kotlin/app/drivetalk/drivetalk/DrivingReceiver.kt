package app.drivetalk.drivetalk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity
import java.util.concurrent.Executors

/**
 * - Trip started / ended (from Android's activity recognition: the phone's
 *   motion sensors, no GPS) → start / end [DrivingService].
 * - "Stop", "Talk" and "Not now" from the notifications ("Talk" answers
 *   right there — no need to open the app).
 */
class DrivingReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_TRANSITION = "app.drivetalk.driving.TRANSITION"
        const val ACTION_STOP = "app.drivetalk.driving.STOP"
        const val ACTION_DECLINE = "app.drivetalk.driving.DECLINE"
        const val ACTION_CANCEL_CALL = "app.drivetalk.driving.CANCEL_CALL"
        const val ACTION_ACCEPT = "app.drivetalk.driving.ACCEPT"
        const val EXTRA_NAME = "app.drivetalk.name"
        private val io = Executors.newSingleThreadExecutor()


        /** Shared by real detections and the developer "simulate" buttons. */
        fun onVehicle(context: Context, entered: Boolean, why: String = "test") {
            val store = DrivingStore(context)
            if (!store.enabled) return
            // A new trip always (re)starts the service, even if a previous
            // one was never closed; "trip over" only matters during a trip
            // (and isn't logged otherwise: every walk would push the useful
            // lines out of the short log).
            if (!entered && !store.inVehicle) return
            store.log((if (entered) "trip start" else "trip end") + " ($why)")
            store.inVehicle = entered
            if (entered) TripCheck.tripStarted(context, why.startsWith("car bluetooth")) else TripCheck.stop(context)
            DrivingEvents.send(if (entered) "enter" else "exit")
            if (entered) DrivingService.start(context) else DrivingService.end(context)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TRANSITION -> {
                if (!ActivityTransitionResult.hasResult(intent)) return
                val result = ActivityTransitionResult.extractResult(intent) ?: return
                // Use the latest event only (several can arrive together).
                val e = result.transitionEvents.maxByOrNull { it.elapsedRealTimeNanos } ?: return
                val entered = e.activityType == DetectedActivity.IN_VEHICLE &&
                    e.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER
                val why = when (e.activityType) {
                    DetectedActivity.IN_VEHICLE -> if (entered) "android: in vehicle" else "android: left vehicle"
                    DetectedActivity.WALKING -> "walking"
                    DetectedActivity.RUNNING -> "running"
                    DetectedActivity.ON_BICYCLE -> "bicycle"
                    else -> "other"
                }
                val store = DrivingStore(context)
                when {
                    // A trip from the car's Bluetooth starts and ends with it.
                    store.inVehicle && store.tripByBluetooth ->
                        store.log("$why — ignored, trip by car bluetooth")
                    // Android's "in a vehicle" counts once a check agrees (D-127).
                    entered && store.enabled && !store.inVehicle -> TripCheck.maybeTrip(context)
                    // Walking before the check agreed: it wasn't a trip.
                    !entered && !store.inVehicle && store.pendingTripAt > 0L -> TripCheck.notATrip(context, why)
                    else -> onVehicle(context, entered, why)
                }
            }
            TripCheck.ACTION_SAMPLE -> TripCheck.onSample(context, intent)
            ACTION_STOP -> {
                DrivingStore(context).inVehicle = false
                DrivingEvents.send("exit")
                DrivingService.stopAll(context)
            }
            ACTION_CANCEL_CALL -> {
                val offer = intent.getStringExtra(MainActivity.EXTRA_OFFER) ?: return
                DrivingNotifications.cancelOffer(context, offer)
                val pending = goAsync()
                val store = DrivingStore(context)
                io.execute {
                    try {
                        DrivingApi(store).cancelCall(offer)
                    } finally {
                        pending.finish()
                    }
                }
            }
            ACTION_ACCEPT -> {
                val offer = intent.getStringExtra(MainActivity.EXTRA_OFFER) ?: return
                val name = intent.getStringExtra(EXTRA_NAME) ?: ""
                DrivingNotifications.cancelOffer(context, offer)
                val pending = goAsync()
                val store = DrivingStore(context)
                io.execute {
                    try {
                        val r = DrivingApi(store).answer(offer)
                        // Agreed now: told once here (the service won't repeat
                        // "X is calling you"). Still waiting for the other
                        // side: the service tells when they say yes.
                        if (r?.status == "accepted") store.markShown("call:$offer")
                        DrivingNotifications.showAnswered(context, offer, name, r?.status, r?.iCall ?: false)
                    } finally {
                        pending.finish()
                    }
                }
            }
            ACTION_DECLINE -> {
                val offer = intent.getStringExtra(MainActivity.EXTRA_OFFER) ?: return
                DrivingNotifications.cancelOffer(context, offer)
                val pending = goAsync()
                val store = DrivingStore(context)
                io.execute {
                    try {
                        DrivingApi(store).decline(offer)
                    } finally {
                        pending.finish()
                    }
                }
            }
        }
    }
}

/** Re-arm detection after the phone restarts (registrations don't survive). */
class DrivingBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }
        val store = DrivingStore(context)
        store.inVehicle = false
        TripCheck.stop(context)
        if (store.enabled) DrivingDetection.register(context)
        Routines.schedule(context)
    }
}
