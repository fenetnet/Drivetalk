package app.drivetalk.drivetalk

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener

/**
 * What Google Play passed through the install (1.3.0): a friend's invite
 * link to the store carries "invite=<code>", so after installing the app
 * connects to them by itself. Only the text Google Play gives back; nothing
 * is sent anywhere from here.
 */
object InstallReferrer {
    fun read(context: Context, done: (String?) -> Unit) {
        val client = try {
            InstallReferrerClient.newBuilder(context.applicationContext).build()
        } catch (e: Exception) {
            done(null)
            return
        }
        var answered = false
        fun answer(value: String?) {
            if (answered) return
            answered = true
            done(value)
            try { client.endConnection() } catch (_: Exception) {}
        }
        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(code: Int) {
                    if (code == InstallReferrerClient.InstallReferrerResponse.OK) {
                        val value = try {
                            client.installReferrer.installReferrer
                        } catch (e: Exception) {
                            null
                        }
                        answer(value)
                    } else {
                        answer(null)
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    answer(null)
                }
            })
        } catch (e: Exception) {
            answer(null)
        }
    }
}
