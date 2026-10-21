import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DrivingStatus {
  const DrivingStatus({
    this.supported = false,
    this.permission = false,
    this.enabled = false,
    this.inVehicle = false,
    this.configured = false,
    this.carName = '',
    this.background = true,
    this.notifications = true,
    this.watching = true,
    this.log = '',
    this.inCallNow = false,
    this.fullScreen = true,
    this.friendsWidget = false,
  });

  /// The background watcher runs now (Android); the app re-arms it when
  /// I'm free and it doesn't.
  final bool watching;

  /// The phone's own short log (trip start/end and why, pushes,
  /// notifications, calls) — for the test info only.
  final String log;

  /// The phone is in a call right now (as the app detects it).
  final bool inCallNow;

  /// A question may open the app while driving (D-130).
  final bool fullScreen;

  /// The "who's free now" widget is on the home screen (D-133).
  final bool friendsWidget;

  /// Notifications are allowed for DriveTalk (Android).
  final bool notifications;

  /// Battery saving won't stop the background service (Android).
  final bool background;

  /// The car's Bluetooth the user picked ('' = none).
  final String carName;
  final bool supported;

  /// This phone has its background device token (for notifications).
  final bool configured;
  final bool permission;
  final bool enabled;
  final bool inVehicle;
}

/// "Talk now" (or a tap) on a driving notification that opened the app.
class LaunchAction {
  const LaunchAction(
    this.offerId, {
    required this.accept,
    this.askFriend,
    this.wake = false,
    this.name,
    this.kind,
  });
  final String offerId;
  final bool accept;

  /// Opened on the screen by a question while driving (D-130): ask it
  /// aloud at once, with the name the notification had (D-138).
  final bool wake;
  final String? name;
  final String? kind;

  /// "Talk" on "X is on the way" (D-119): ask this friend now.
  final String? askFriend;
}

/// Automatic driving availability (Android: Activity Recognition — motion
/// sensors, no GPS). Opt-in. While a trip is detected, a small Android
/// service marks me available and shows "X is free — talk?" notifications,
/// even when the app is closed. It never starts a call by itself.
abstract class DrivingDetector {
  Future<DrivingStatus> status();
  Future<bool> requestPermission();
  Future<bool> enable({
    required String url,
    required String key,
    required String token,
    required int minutes,
    required Map<String, String> texts,
  });
  Future<void> disable();

  /// Give the phone its device token (background notifications while I'm
  /// free, even with the app closed). No detection by itself.
  Future<void> configure({
    required String url,
    required String key,
    required String token,
    required Map<String, String> texts,
  });

  /// Forget the token (signing out).
  Future<void> forget();

  /// I'm free until [until]: watch for friends in the background.
  /// [endWithTrip]: "for the whole trip" — it also ends when the trip does.
  Future<bool> startAvailable(
    DateTime until, {
    bool endWithTrip = false,
    bool driving = false,
  });

  /// Android 14+: the settings switch for "full-screen notifications"
  /// (a question opens the app while driving, D-130).
  Future<void> allowFullScreen();

  /// The "who's free now" widget's list (JSON, D-133).
  Future<void> setWidgetFriends(String json);
  Future<void> stopAvailable();
  Future<bool> requestNotificationPermission();

  /// The phone's notification settings for DriveTalk (to turn them on/off).
  Future<void> openNotificationSettings();

  /// One tap "allow running in the background" (battery saving off for
  /// DriveTalk), so trips and "a friend is free" keep working.
  Future<bool> allowBackground();

  /// Routines for the phone's alarm (JSON from RealController).
  Future<void> setRoutines(String json);

  /// Friend id → the name saved in my contacts, for the background
  /// notifications (stays on the phone).
  Future<void> setNames(Map<String, String> names);

  /// Paired Bluetooth devices (name, address) — to pick the car.
  Future<List<(String, String)>> bondedDevices();
  Future<void> setCar(String address, String name);

  /// Refresh the notification texts (after an app update).
  Future<void> updateTexts(Map<String, String> texts);

  /// The app started this call itself: the background service shouldn't
  /// also say "tap to call X" about it.
  Future<void> callHandled(String offerId);

  /// Developer tools: pretend a trip started / ended.
  Future<void> simulate({required bool enter});
  Future<LaunchAction?> takeLaunchAction();

  /// This phone's push address (Firebase); null when push isn't set up.
  Future<String?> pushToken();

  /// The server saved this phone's push address (true) or not (false).
  Future<void> setPushReady(bool on);

  /// "enter", "exit" (trip) and "action" (a notification was tapped).
  Stream<String> get events;
}

class AndroidDrivingDetector implements DrivingDetector {
  static const _channel = MethodChannel('app.drivetalk/driving');
  static const _events = EventChannel('app.drivetalk/driving/events');

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<DrivingStatus> status() async {
    if (!_android) return const DrivingStatus();
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('status');
      return DrivingStatus(
        supported: m?['supported'] == true,
        permission: m?['permission'] == true,
        enabled: m?['enabled'] == true,
        inVehicle: m?['inVehicle'] == true,
        configured: m?['configured'] == true,
        carName: '${m?['carName'] ?? ''}',
        background: m?['background'] != false,
        notifications: m?['notifications'] != false,
        watching: m?['watching'] != false,
        log: '${m?['log'] ?? ''}',
        inCallNow: m?['inCallNow'] == true,
        fullScreen: m?['fullScreen'] != false,
        friendsWidget: m?['friendsWidget'] == true,
      );
    } catch (_) {
      return const DrivingStatus();
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> enable({
    required String url,
    required String key,
    required String token,
    required int minutes,
    required Map<String, String> texts,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('enable', {
            'url': url,
            'key': key,
            'token': token,
            'minutes': minutes,
            'texts': texts,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('disable');
    } catch (_) {}
  }

  @override
  Future<void> configure({
    required String url,
    required String key,
    required String token,
    required Map<String, String> texts,
  }) => _call('configure', {
    'url': url,
    'key': key,
    'token': token,
    'texts': texts,
  });

  @override
  Future<void> forget() => _call('forget');

  @override
  Future<bool> startAvailable(
    DateTime until, {
    bool endWithTrip = false,
    bool driving = false,
  }) async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('startAvailable', {
            'until': until.millisecondsSinceEpoch,
            'endWithTrip': endWithTrip,
            'driving': driving,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stopAvailable() => _call('stopAvailable');

  @override
  Future<List<(String, String)>> bondedDevices() async {
    if (!_android) return const [];
    try {
      final list = await _channel.invokeListMethod<Object?>('bondedDevices');
      return [
        for (final d in list ?? const [])
          if (d is Map) ('${d['name']}', '${d['address']}'),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> setCar(String address, String name) =>
      _call('setCar', {'address': address, 'name': name});

  @override
  Future<void> setRoutines(String json) => _call('setRoutines', {'json': json});

  @override
  Future<void> setNames(Map<String, String> names) =>
      _call('setNames', {'json': jsonEncode(names)});

  @override
  Future<void> openNotificationSettings() => _call('openNotificationSettings');

  @override
  Future<void> allowFullScreen() => _call('allowFullScreen');

  @override
  Future<void> setWidgetFriends(String json) =>
      _call('widgetFriends', {'json': json});

  @override
  Future<bool> allowBackground() async {
    if (!_android) return true;
    try {
      return await _channel.invokeMethod<bool>('allowBackground') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('notificationPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (_) {}
  }

  @override
  Future<void> updateTexts(Map<String, String> texts) async {
    try {
      await _channel.invokeMethod<void>('texts', {'texts': texts});
    } catch (_) {}
  }

  @override
  Future<void> callHandled(String offerId) =>
      _call('callHandled', {'offer': offerId});

  @override
  Future<void> setPushReady(bool on) => _call('pushReady', {'on': on});

  @override
  Future<String?> pushToken() async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<String>('pushToken');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> simulate({required bool enter}) async {
    try {
      await _channel.invokeMethod<void>('simulate', {'enter': enter});
    } catch (_) {}
  }

  @override
  Future<LaunchAction?> takeLaunchAction() async {
    if (!_android) return null;
    try {
      final m = await _channel.invokeMapMethod<String, Object?>(
        'takeLaunchAction',
      );
      final ask = m?['ask'];
      if (ask is String) {
        return LaunchAction('', accept: false, askFriend: ask);
      }
      final id = m?['offerId'];
      if (id is! String) return null;
      return LaunchAction(
        id,
        accept: m?['accept'] == true,
        wake: m?['wake'] == true,
        name: m?['name'] as String?,
        kind: m?['kind'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get events {
    if (!_android) return const Stream.empty();
    return _events
        .receiveBroadcastStream()
        .map((e) => '$e')
        .handleError((Object _) {});
  }
}

/// Tests (and phones without the feature).
class FakeDrivingDetector implements DrivingDetector {
  FakeDrivingDetector({this.supported = true, this.grantPermission = true});
  final bool supported;
  bool grantPermission;
  var enabled = false;
  var inVehicle = false;
  String? token;
  DateTime? availableUntil;
  LaunchAction? pendingAction;
  final _events = StreamController<String>.broadcast(sync: true);

  @override
  Future<DrivingStatus> status() async => DrivingStatus(
    supported: supported,
    permission: grantPermission,
    enabled: enabled,
    inVehicle: inVehicle,
    configured: token != null,
    carName: carName,
    background: background,
    notifications: notifications,
    watching: watching,
    fullScreen: fullScreen,
    friendsWidget: friendsWidget,
  );

  /// Like the native watcher: runs while I'm free (tests can stop it).
  var watching = false;
  var background = true;
  var notifications = true;
  var notificationsOpened = 0;

  @override
  Future<void> openNotificationSettings() async => notificationsOpened++;

  @override
  Future<bool> allowBackground() async => background = true;

  var fullScreen = true;

  @override
  Future<void> allowFullScreen() async => fullScreen = true;

  /// The widget: installed (tests), and the last list sent.
  var friendsWidget = false;
  String? widgetJson;

  @override
  Future<void> setWidgetFriends(String json) async => widgetJson = json;

  @override
  Future<bool> requestPermission() async => grantPermission;

  @override
  Future<bool> enable({
    required String url,
    required String key,
    required String token,
    required int minutes,
    required Map<String, String> texts,
  }) async {
    if (!supported || !grantPermission) return false;
    enabled = true;
    this.token = token;
    return true;
  }

  @override
  Future<void> disable() async {
    enabled = false;
  }

  @override
  Future<void> updateTexts(Map<String, String> texts) async {}

  final handledCalls = <String>[];

  @override
  Future<void> callHandled(String offerId) async => handledCalls.add(offerId);

  /// Tests: this phone's push address (null = push not set up).
  String? push;

  @override
  Future<String?> pushToken() async => push;

  var pushReady = false;

  @override
  Future<void> setPushReady(bool on) async => pushReady = on;

  @override
  Future<void> configure({
    required String url,
    required String key,
    required String token,
    required Map<String, String> texts,
  }) async {
    if (supported) this.token = token;
  }

  @override
  Future<void> forget() async {
    token = null;
    enabled = false;
    availableUntil = null;
    watching = false;
  }

  /// The last "for the whole trip" flag passed with [startAvailable].
  var endWithTrip = false;
  var startAvailableCalls = 0;

  /// The last "my free time is driving" passed (D-130).
  var driving = false;

  @override
  Future<bool> startAvailable(
    DateTime until, {
    bool endWithTrip = false,
    bool driving = false,
  }) async {
    if (token == null) return false;
    startAvailableCalls++;
    availableUntil = until;
    this.endWithTrip = endWithTrip;
    this.driving = driving;
    watching = true;
    return true;
  }

  @override
  Future<void> stopAvailable() async {
    availableUntil = null;
    endWithTrip = false;
    watching = false;
  }

  @override
  Future<bool> requestNotificationPermission() async => notifications = true;

  List<(String, String)> devices = const [('Car Audio', 'AA:BB')];
  String carName = '';

  @override
  Future<List<(String, String)>> bondedDevices() async => devices;

  @override
  Future<void> setCar(String address, String name) async => carName = name;

  String routinesJson = '[]';
  @override
  Future<void> setRoutines(String json) async => routinesJson = json;

  Map<String, String> names = {};

  @override
  Future<void> setNames(Map<String, String> names) async => this.names = names;

  @override
  Future<void> simulate({required bool enter}) async {
    inVehicle = enter;
    _events.add(enter ? 'enter' : 'exit');
  }

  @override
  Future<LaunchAction?> takeLaunchAction() async {
    final a = pendingAction;
    pendingAction = null;
    return a;
  }

  void tapNotification(LaunchAction a) {
    pendingAction = a;
    _events.add('action');
  }

  @override
  Stream<String> get events => _events.stream;
}
