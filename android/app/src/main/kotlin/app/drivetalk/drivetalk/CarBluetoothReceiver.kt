package app.drivetalk.drivetalk

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * The car's Bluetooth connected / disconnected → trip started / ended (only
 * the cars the user picked, and only with automatic availability turned on).
 */
class CarBluetoothReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val store = DrivingStore(context)
        val cars = store.carAddresses
        if (!store.enabled || cars.isEmpty()) return
        @Suppress("DEPRECATION")
        val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        val address = try { device?.address } catch (e: SecurityException) { null }
        if (address == null || cars.none { it.equals(address, ignoreCase = true) }) return
        when (intent.action) {
            BluetoothDevice.ACTION_ACL_CONNECTED -> DrivingReceiver.onVehicle(context, true, "car bluetooth")
            BluetoothDevice.ACTION_ACL_DISCONNECTED -> DrivingReceiver.onVehicle(context, false, "car bluetooth off")
        }
    }
}
