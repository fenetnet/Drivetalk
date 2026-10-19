package app.drivetalk.drivetalk

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity

/**
 * The double check (D-127). Android's "in a vehicle" can be wrong (a brisk
 * walk, a bouncing bag), and its "trip over" can be late or never come. So
 * around a trip the phone also asks Android "what am I doing now?" about
 * once a minute — the same permission, no GPS, only while a trip may be on:
 * - "in a vehicle" from Android starts a trip only once a check agrees
 *   (walking instead → it wasn't a trip; nothing after 4 minutes → no trip);
 * - during the trip, walking twice in a row, or standing still for 10
 *   minutes, ends it.
 * The car's Bluetooth needs no check: it starts and ends a trip at once.
 */
object TripCheck {
    const val ACTION_SAMPLE = "app.drivetalk.driving.SAMPLE"
    private const val INTERVAL_MS = 60_000L
    private const val CONFIRM_WITHIN_MS = 4 * 60_000L
    private const val PARKED_MS = 10 * 60_000L
    private const val SURE = 70

    private fun pendingIntent(context: Context): PendingIntent {
        val i = Intent(context, DrivingReceiver::class.java).setAction(ACTION_SAMPLE)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        // The system adds the result to this intent → must be mutable.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(context, 43, i, flags)
    }

    @SuppressLint("MissingPermission")
    private fun startSampling(context: Context) {
        if (!DrivingDetection.hasPermission(context)) return
        try {
            ActivityRecognition.getClient(context)
                .requestActivityUpdates(INTERVAL_MS, pendingIntent(context))
        } catch (e: Exception) {
            // No checks: Android's own events still start and end trips.
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopSampling(context: Context) {
        try {
            if (DrivingDetection.hasPermission(context)) {
                ActivityRecognition.getClient(context)
                    .removeActivityUpdates(pendingIntent(context))
            }
        } catch (e: Exception) {
            // Nothing to stop.
        }
    }

    /** Android said "in a vehicle": check before it counts. */
    fun maybeTrip(context: Context) {
        val store = DrivingStore(context)
        if (!store.enabled || store.inVehicle) return
        if (store.pendingTripAt == 0L) store.log("in a vehicle? (android) — checking")
        store.pendingTripAt = System.currentTimeMillis()
        store.walkSamples = 0
        startSampling(context)
    }

    /** Android said "walking" before the check agreed: it wasn't a trip. */
    fun notATrip(context: Context, why: String) {
        val store = DrivingStore(context)
        if (store.pendingTripAt == 0L) return
        store.pendingTripAt = 0L
        store.log("not a trip ($why)")
        if (!store.inVehicle) stopSampling(context)
    }

    /** A trip started (confirmed, or by the car's Bluetooth). */
    fun tripStarted(context: Context, byBluetooth: Boolean) {
        val store = DrivingStore(context)
        store.pendingTripAt = 0L
        store.walkSamples = 0
        store.stillSince = 0L
        store.tripByBluetooth = byBluetooth
        // The car's Bluetooth ends the trip by itself: no checks needed.
        if (byBluetooth) stopSampling(context) else startSampling(context)
    }

    /** The trip is over (or detection turned off): no more checks. */
    fun stop(context: Context) {
        val store = DrivingStore(context)
        store.pendingTripAt = 0L
        store.walkSamples = 0
        store.stillSince = 0L
        stopSampling(context)
    }

    /** One answer to "what am I doing now?". */
    fun onSample(context: Context, intent: Intent) {
        if (!ActivityRecognitionResult.hasResult(intent)) return
        val r = ActivityRecognitionResult.extractResult(intent) ?: return
        val store = DrivingStore(context)
        if (!store.enabled) return stop(context)
        val now = System.currentTimeMillis()
        val vehicle = r.getActivityConfidence(DetectedActivity.IN_VEHICLE)
        val onFoot = maxOf(
            r.getActivityConfidence(DetectedActivity.ON_FOOT),
            r.getActivityConfidence(DetectedActivity.WALKING),
            r.getActivityConfidence(DetectedActivity.RUNNING),
        )
        val still = r.getActivityConfidence(DetectedActivity.STILL)

        if (store.pendingTripAt > 0L && !store.inVehicle) {
            when {
                vehicle >= SURE -> {
                    store.pendingTripAt = 0L
                    DrivingReceiver.onVehicle(context, true, "android, checked")
                }
                onFoot >= SURE -> notATrip(context, "walking")
                now - store.pendingTripAt > CONFIRM_WITHIN_MS -> notATrip(context, "no vehicle in 4 min")
            }
            return
        }
        if (!store.inVehicle) return stop(context)
        if (store.tripByBluetooth) return
        when {
            vehicle >= SURE -> {
                store.walkSamples = 0
                store.stillSince = 0L
            }
            onFoot >= SURE -> {
                store.stillSince = 0L
                store.walkSamples = store.walkSamples + 1
                if (store.walkSamples >= 2) DrivingReceiver.onVehicle(context, false, "walking, checked")
            }
            still >= SURE -> {
                store.walkSamples = 0
                if (store.stillSince == 0L) store.stillSince = now
                if (now - store.stillSince >= PARKED_MS) {
                    DrivingReceiver.onVehicle(context, false, "still 10 min")
                }
            }
        }
    }
}
