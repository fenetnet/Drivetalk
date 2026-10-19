package app.drivetalk.drivetalk

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * The car's Bluetooth connected / disconnected → trip started / ended (only
 * the car the user picked, and only with automatic availability turned on).
 */
class CarBluetoothReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val store = DrivingStore(context)
        if (!store.enabled || store.carAddress.isEmpty()) return
        @Suppress("DEPRECATION")
        val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        val address = try { device?.address } catch (e: SecurityException) { null }
        if (address == null || !address.equals(store.carAddress, ignoreCase = true)) return
        when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> {
                // Back within the short stop: the same trip goes on.
                if (store.tripEndsAt > 0L && store.inVehicle) {
                    store.tripEndsAt = 0L
                    store.log("car bluetooth back — same trip")
                } else {
                    DrivingReceiver.onVehicle(context, true, "car bluetooth")
                }
            }
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                if (store.shortStops && store.inVehicle) {
                    // A short stop (dropping someone off): the trip ends
                    // only if the car isn't back soon (DrivingService).
                    store.tripEndsAt = System.currentTimeMillis()
                    store.log("car bluetooth off — waiting 5 min")
                } else {
                    DrivingReceiver.onVehicle(context, false, "car bluetooth off")
                }
            }
        }
    }
}
