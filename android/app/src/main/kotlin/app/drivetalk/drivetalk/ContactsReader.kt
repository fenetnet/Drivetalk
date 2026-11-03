package app.drivetalk.drivetalk

import android.content.Context
import android.provider.ContactsContract

/**
 * Phone numbers from the phone's contacts. The app hashes the numbers
 * before anything leaves the phone; names are used only on the phone (to
 * show friends by the name saved here) and are never sent.
 */
object ContactsReader {
    /**
     * Number + the name saved for it on this phone + whether it's a
     * favorite (starred) — for "maybe call…" suggestions, on the phone only.
     */
    fun contacts(context: Context): List<Map<String, String>> {
        val out = LinkedHashMap<String, String>()
        val starred = HashSet<String>()
        try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.STARRED,
                ),
                null,
                null,
                null,
            )?.use { c ->
                val n = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                val d = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val s = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.STARRED)
                while (c.moveToNext() && out.size < 5000) {
                    val number = if (n >= 0) c.getString(n) else null
                    if (number != null && !out.containsKey(number)) {
                        out[number] = (if (d >= 0) c.getString(d) else null) ?: ""
                        if (s >= 0 && c.getInt(s) == 1) starred.add(number)
                    }
                }
            }
        } catch (e: Exception) {
            // No permission or no contacts provider.
        }
        return out.map {
            mapOf(
                "number" to it.key,
                "name" to it.value,
                "starred" to if (starred.contains(it.key)) "1" else "0",
            )
        }
    }

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
