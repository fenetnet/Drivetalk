package app.drivetalk.drivetalk

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_OFFER = "drivetalk_offer"
        const val EXTRA_ACCEPT = "drivetalk_accept"

        /** The app is on screen: it reads questions aloud itself (and
         *  listens for yes/no), so the background service stays quiet. */
        @Volatile var onScreen = false
    }

    override fun onResume() {
        super.onResume()
        onScreen = true
    }

    override fun onPause() {
        onScreen = false
        super.onPause()
    }

    private val callPermissionRequest = 4711
    private val drivingPermissionRequest = 4712
    private val contactsPermissionRequest = 4713
    private val notificationPermissionRequest = 4714
    private val bluetoothPermissionRequest = 4715
    private var pendingBluetoothResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingContactsResult: MethodChannel.Result? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingDrivingResult: MethodChannel.Result? = null

    /** "Talk now" / tap from a driving notification, waiting for the app. */
    private var launchAction: Map<String, Any>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        readLaunchAction(intent)
        // Android can drop the detection registration (an update, clearing
        // Play services data): arm it again whenever the app opens.
        if (DrivingStore(this).enabled) DrivingDetection.register(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (readLaunchAction(intent)) DrivingEvents.send("action")
    }

    private fun readLaunchAction(intent: Intent?): Boolean {
        val offer = intent?.getStringExtra(EXTRA_OFFER) ?: return false
        // "Talk now" counts only for an offer this phone really showed
        // (another app could send the same intent; then it only opens).
        val accept = intent.getBooleanExtra(EXTRA_ACCEPT, false) &&
            DrivingStore(this).wasShown(offer)
        launchAction = mapOf(
            "offerId" to offer,
            "accept" to accept,
        )
        intent.removeExtra(EXTRA_OFFER)
        DrivingNotifications.cancelOffer(this, offer)
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureDriving(flutterEngine)
        configureContacts(flutterEngine)
        // Regular phone call through the phone's own dialer.
        // With the CALL_PHONE permission: one tap (ACTION_CALL).
        // Without it: the dialer opens with the number filled in (ACTION_DIAL).
        // Returns "calling", "dialer" or "failed".
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.drivetalk/phone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Never asks for a permission here: the call starts at once,
                    // directly if allowed, otherwise in the dialer.
                    "call" -> {
                        val number = call.argument<String>("number")
                        if (number.isNullOrBlank()) {
                            result.success("failed")
                        } else {
                            // "direct" false: the user turned instant calls off.
                            val allow = call.argument<Boolean>("direct") ?: true
                            result.success(place(number, direct = allow && hasCallPermission()))
                        }
                    }
                    "canCallDirectly" -> result.success(hasCallPermission())
                    // Asked ahead, on a calm screen (not during an offer).
                    "requestDirectCall" -> {
                        if (hasCallPermission() || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            result.success(hasCallPermission())
                        } else {
                            pendingResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.CALL_PHONE),
                                callPermissionRequest,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Automatic driving availability (opt-in). See DrivingDetection.kt.
    private fun notificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        return nm.areNotificationsEnabled()
    }

    /** The phone's notification settings for this app (turn on / off). */
    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // Nothing to open on this phone.
        }
    }

    /** Not stopped by battery saving (true on Android before 6). */
    private fun backgroundAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /** The system "allow running in background?" question (one tap);
     *  if a phone doesn't offer it, its battery settings list. */
    private fun askAllowBackground(): Boolean {
        if (backgroundAllowed()) return true
        return try {
            startActivity(
                Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:$packageName")),
            )
            true
        } catch (e: Exception) {
            try {
                startActivity(Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                true
            } catch (e2: Exception) {
                false
            }
        }
    }

    private fun configureDriving(flutterEngine: FlutterEngine) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        EventChannel(messenger, "app.drivetalk/driving/events").setStreamHandler(DrivingEvents)
        MethodChannel(messenger, "app.drivetalk/driving").setMethodCallHandler { call, result ->
            val store = DrivingStore(this)
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "supported" to true,
                        "permission" to DrivingDetection.hasPermission(this),
                        "enabled" to store.enabled,
                        "inVehicle" to store.inVehicle,
                        "configured" to store.configured,
                        "carName" to store.carName,
                        "background" to backgroundAllowed(),
                        "notifications" to notificationsAllowed(),
                    ),
                )
                // Battery saving must not stop the background service.
                "allowBackground" -> result.success(askAllowBackground())
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }
                "requestPermission" -> requestDrivingPermissions(result)
                "enable" -> {
                    @Suppress("UNCHECKED_CAST")
                    val texts = (call.argument<Map<String, String>>("texts") ?: emptyMap())
                    store.save(
                        url = call.argument<String>("url") ?: "",
                        key = call.argument<String>("key") ?: "",
                        token = call.argument<String>("token") ?: "",
                        minutes = call.argument<Int>("minutes") ?: 120,
                        texts = texts,
                    )
                    DrivingNotifications.ensureChannels(this)
                    DrivingDetection.register(this) { ok ->
                        if (!ok) store.enabled = false
                        runOnUiThread { result.success(ok) }
                    }
                }
                "disable" -> {
                    // Detection off; the device token stays for "I'm free"
                    // notifications.
                    DrivingDetection.unregister(this)
                    if (store.inVehicle) DrivingService.end(this)
                    store.enabled = false
                    store.inVehicle = false
                    result.success(true)
                }
                "configure" -> {
                    @Suppress("UNCHECKED_CAST")
                    store.configure(
                        url = call.argument<String>("url") ?: "",
                        key = call.argument<String>("key") ?: "",
                        token = call.argument<String>("token") ?: "",
                        texts = call.argument<Map<String, String>>("texts") ?: emptyMap(),
                    )
                    DrivingNotifications.ensureChannels(this)
                    Routines.schedule(this)
                    result.success(true)
                }
                "forget" -> {
                    DrivingDetection.unregister(this)
                    DrivingService.quietEnd(this)
                    store.clear()
                    result.success(true)
                }
                "startAvailable" -> {
                    if (!store.configured) {
                        result.success(false)
                    } else {
                        store.availableUntil = (call.argument<Number>("until") ?: 0).toLong()
                        DrivingService.startManual(this)
                        QuickFree.refreshAll(this)
                        result.success(true)
                    }
                }
                "stopAvailable" -> {
                    store.availableUntil = 0L
                    DrivingService.quietEnd(this)
                    QuickFree.refreshAll(this)
                    result.success(true)
                }
                "bondedDevices" -> withBluetooth(result) {
                    val adapter = (getSystemService(BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager)?.adapter
                    val list = try {
                        adapter?.bondedDevices?.map {
                            mapOf("name" to (it.name ?: it.address), "address" to it.address)
                        } ?: emptyList()
                    } catch (e: SecurityException) {
                        emptyList()
                    }
                    result.success(list)
                }
                "setNames" -> {
                    store.names = call.argument<String>("json") ?: "{}"
                    result.success(true)
                }
                "setRoutines" -> {
                    store.routines = call.argument<String>("json") ?: "[]"
                    Routines.schedule(this)
                    result.success(true)
                }
                "setCar" -> {
                    store.carAddress = call.argument<String>("address") ?: ""
                    store.carName = call.argument<String>("name") ?: ""
                    result.success(true)
                }
                "notificationPermission" -> requestNotificationPermission(result)
                "texts" -> {
                    @Suppress("UNCHECKED_CAST")
                    store.saveTexts(call.argument<Map<String, String>>("texts") ?: emptyMap())
                    DrivingNotifications.ensureChannels(this)
                    result.success(true)
                }
                "simulate" -> {
                    DrivingReceiver.onVehicle(this, call.argument<Boolean>("enter") == true)
                    result.success(true)
                }
                "takeLaunchAction" -> {
                    result.success(launchAction)
                    launchAction = null
                }
                else -> result.notImplemented()
            }
        }
    }

    // Friends from contacts: numbers only, hashed in the app before sending.
    private fun configureContacts(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.drivetalk/contacts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasContactsPermission())
                    "requestPermission" -> {
                        if (hasContactsPermission() || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            result.success(hasContactsPermission())
                        } else {
                            pendingContactsResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.READ_CONTACTS),
                                contactsPermissionRequest,
                            )
                        }
                    }
                    "contacts" -> {
                        if (!hasContactsPermission()) {
                            result.success(emptyList<Map<String, String>>())
                        } else {
                            Thread {
                                val list = ContactsReader.contacts(this)
                                runOnUiThread { result.success(list) }
                            }.start()
                        }
                    }
                    "phoneNumbers" -> {
                        if (!hasContactsPermission()) {
                            result.success(emptyList<String>())
                        } else {
                            Thread {
                                val numbers = ContactsReader.phoneNumbers(this)
                                runOnUiThread { result.success(numbers) }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasContactsPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    private fun withBluetooth(result: MethodChannel.Result, body: () -> Unit) {
        if (Build.VERSION.SDK_INT < 31 ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        ) {
            body()
            return
        }
        pendingBluetoothResult = result
        pendingBluetoothBody = body
        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), bluetoothPermissionRequest)
    }

    private var pendingBluetoothBody: (() -> Unit)? = null

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingNotificationResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequest)
    }

    private fun requestDrivingPermissions(result: MethodChannel.Result) {
        val wanted = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED
        ) {
            wanted.add(Manifest.permission.ACTIVITY_RECOGNITION)
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            wanted.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (wanted.isEmpty() || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(DrivingDetection.hasPermission(this))
            return
        }
        pendingDrivingResult = result
        requestPermissions(wanted.toTypedArray(), drivingPermissionRequest)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == bluetoothPermissionRequest) {
            val r = pendingBluetoothResult
            val body = pendingBluetoothBody
            pendingBluetoothResult = null
            pendingBluetoothBody = null
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                body?.invoke()
            } else {
                r?.success(emptyList<Map<String, String>>())
            }
            return
        }
        if (requestCode == notificationPermissionRequest) {
            val r = pendingNotificationResult
            pendingNotificationResult = null
            r?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            return
        }
        if (requestCode == contactsPermissionRequest) {
            val r = pendingContactsResult
            pendingContactsResult = null
            r?.success(hasContactsPermission())
            return
        }
        if (requestCode == drivingPermissionRequest) {
            val r = pendingDrivingResult
            pendingDrivingResult = null
            r?.success(DrivingDetection.hasPermission(this))
            return
        }
        if (requestCode != callPermissionRequest) return
        val result = pendingResult
        pendingResult = null
        if (result == null) return
        result.success(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
    }

    private fun hasCallPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED

    private fun place(number: String, direct: Boolean): String = try {
        val action = if (direct) Intent.ACTION_CALL else Intent.ACTION_DIAL
        startActivity(Intent(action, Uri.parse("tel:$number")))
        if (direct) "calling" else "dialer"
    } catch (e: Exception) {
        "failed"
    }
}
