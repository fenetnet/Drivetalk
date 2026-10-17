package app.drivetalk.drivetalk

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.DetectedActivity
import io.flutter.plugin.common.EventChannel

/** Android's official in-vehicle detection (Activity Recognition Transition API). */
object DrivingDetection {
    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    private fun pendingIntent(context: Context): PendingIntent {
        val i = Intent(context, DrivingReceiver::class.java)
            .setAction(DrivingReceiver.ACTION_TRANSITION)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        // The system adds the detection result to this intent → must be mutable.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
        return PendingIntent.getBroadcast(context, 42, i, flags)
    }

    @SuppressLint("MissingPermission")
    fun register(context: Context, done: ((Boolean) -> Unit)? = null) {
        if (!hasPermission(context)) {
            done?.invoke(false)
            return
        }
        fun t(type: Int, transition: Int) = ActivityTransition.Builder()
            .setActivityType(type)
            .setActivityTransition(transition)
            .build()
        val transitions = listOf(
            t(DetectedActivity.IN_VEHICLE, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
            t(DetectedActivity.IN_VEHICLE, ActivityTransition.ACTIVITY_TRANSITION_EXIT),
            // Android's "left the vehicle" can be late; starting to walk
            // (or run / cycle) is a faster, reliable sign the trip is over.
            t(DetectedActivity.WALKING, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
            t(DetectedActivity.RUNNING, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
            t(DetectedActivity.ON_BICYCLE, ActivityTransition.ACTIVITY_TRANSITION_ENTER),
        )
        try {
            ActivityRecognition.getClient(context)
                .requestActivityTransitionUpdates(ActivityTransitionRequest(transitions), pendingIntent(context))
                .addOnSuccessListener { done?.invoke(true) }
                .addOnFailureListener { done?.invoke(false) }
        } catch (e: Exception) {
            done?.invoke(false)
        }
    }

    @SuppressLint("MissingPermission")
    fun unregister(context: Context) {
        try {
            if (hasPermission(context)) {
                ActivityRecognition.getClient(context)
                    .removeActivityTransitionUpdates(pendingIntent(context))
            }
        } catch (e: Exception) {
            // Nothing registered.
        }
    }
}

/** Live events to the app while it is open ("enter" / "exit" / "action"). */
object DrivingEvents : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun send(event: String) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            try {
                sink?.success(event)
            } catch (e: Exception) {
                // App not listening.
            }
        }
    }
}
