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
  });

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
  const LaunchAction(this.offerId, {required this.accept});
  final String offerId;
  final bool accept;
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
  Future<bool> startAvailable(DateTime until);
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

  /// Developer tools: pretend a trip started / ended.
  Future<void> simulate({required bool enter});
  Future<LaunchAction?> takeLaunchAction();

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
  Future<bool> startAvailable(DateTime until) async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('startAvailable', {
            'until': until.millisecondsSinceEpoch,
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
      final id = m?['offerId'];
      if (id is! String) return null;
      return LaunchAction(id, accept: m?['accept'] == true);
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
  );

  var background = true;
  var notificationsOpened = 0;

  @override
  Future<void> openNotificationSettings() async => notificationsOpened++;

  @override
  Future<bool> allowBackground() async => background = true;

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
  }

  @override
  Future<bool> startAvailable(DateTime until) async {
    if (token == null) return false;
    availableUntil = until;
    return true;
  }

  @override
  Future<void> stopAvailable() async => availableUntil = null;

  @override
  Future<bool> requestNotificationPermission() async => true;

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
