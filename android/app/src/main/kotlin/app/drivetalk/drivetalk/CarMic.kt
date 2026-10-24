package app.drivetalk.drivetalk

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager

/**
 * While the app listens for "yes" / "no" in the car: the car's microphone
 * (Bluetooth hands-free) hears better than the phone in a holder. Only
 * when such a device is connected, only while listening. Music may pause
 * for a second meanwhile.
 */
object CarMic {
    @Volatile private var on = false

    private fun audio(context: Context) =
        context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

    fun available(context: Context): Boolean = try {
        audio(context)?.getDevices(AudioManager.GET_DEVICES_INPUTS)
            ?.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO } == true
    } catch (e: Exception) {
        false
    }

    /** True when the car's microphone is (being) switched on. */
    @Suppress("DEPRECATION")
    fun set(context: Context, want: Boolean): Boolean {
        val audio = audio(context) ?: return false
        return try {
            if (want) {
                if (!available(context)) return false
                audio.startBluetoothSco()
                audio.isBluetoothScoOn = true
                on = true
                true
            } else {
                if (on) {
                    audio.isBluetoothScoOn = false
                    audio.stopBluetoothSco()
                    on = false
                }
                true
            }
        } catch (e: Exception) {
            on = false
            false
        }
    }
}
