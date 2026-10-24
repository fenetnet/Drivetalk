package app.drivetalk.drivetalk

import android.content.Context
import android.media.AudioManager
import android.media.MediaRecorder
import android.os.Build

/**
 * Is the phone really in a call? Only yes/no, from the sound system: no
 * permission, no number, no call log.
 *
 * A regular call: the "in call" sound mode. An internet call (WhatsApp and
 * the like) uses the "communication" mode — but so do other things (a voice
 * assistant, the car's hands-free, an app that left the mode on), so it
 * counts only while some app is really recording for a call.
 */
object PhoneState {
    fun inCall(context: Context): Boolean {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
        return when (audio.mode) {
            AudioManager.MODE_IN_CALL -> true
            AudioManager.MODE_IN_COMMUNICATION -> voiceCallRecording(audio)
            else -> false
        }
    }

    private fun voiceCallRecording(audio: AudioManager): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        return try {
            audio.activeRecordingConfigurations.any {
                it.clientAudioSource == MediaRecorder.AudioSource.VOICE_COMMUNICATION
            }
        } catch (e: Exception) {
            true
        }
    }
}
