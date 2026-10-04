import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DrivingStatus {
  const DrivingStatus({
    this.supported = false,
    this.permission = false,
    this.enabled = false,
    this.inVehicle = false,
  });
  final bool supported;
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
  LaunchAction? pendingAction;
  final _events = StreamController<String>.broadcast(sync: true);

  @override
  Future<DrivingStatus> status() async => DrivingStatus(
    supported: supported,
    permission: grantPermission,
    enabled: enabled,
    inVehicle: inVehicle,
  );

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
    token = null;
  }

  @override
  Future<void> updateTexts(Map<String, String> texts) async {}

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
