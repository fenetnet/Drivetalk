package app.drivetalk.drivetalk

import android.content.Context
import android.provider.ContactsContract

/**
 * Phone numbers from the phone's contacts (numbers only — no names, no
 * other details). The app hashes them before anything leaves the phone.
 */
object ContactsReader {
    fun phoneNumbers(context: Context): List<String> {
        val out = LinkedHashSet<String>()
        try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                null,
                null,
                null,
            )?.use { c ->
                val i = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (c.moveToNext() && out.size < 5000) {
                    if (i >= 0) c.getString(i)?.let { out.add(it) }
                }
            }
        } catch (e: Exception) {
            // No permission or no contacts provider.
        }
        return out.toList()
    }
}
