import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DialResult { calling, openedDialer, unsupported, failed }

/// Places a regular phone call with the phone's own dialer.
abstract class PhoneDialer {
  /// Starts at once: a direct call when allowed, otherwise the dialer with
  /// the number ready. Never asks for a permission at that moment.
  /// [direct] false: always the dialer (the user turned instant calls off).
  Future<DialResult> call(String number, {bool direct = true});

  /// May the call start without an extra tap?
  Future<bool> canCallDirectly() async => false;

  /// Ask for direct calls ahead of time (a calm moment, not during an offer).
  Future<bool> requestDirectCall() async => false;
}

/// Android: one-tap call (ACTION_CALL) when the "phone calls" permission was
/// granted ahead of time; otherwise opens the dialer with the number.
/// Implemented by a tiny Kotlin bridge in MainActivity.kt.
class PlatformPhoneDialer implements PhoneDialer {
  static const _channel = MethodChannel('app.drivetalk/phone');

  @override
  Future<DialResult> call(String number, {bool direct = true}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return DialResult.unsupported;
    }
    try {
      final r = await _channel.invokeMethod<String>('call', {
        'number': number,
        'direct': direct,
      });
      return switch (r) {
        'calling' => DialResult.calling,
        'dialer' => DialResult.openedDialer,
        _ => DialResult.failed,
      };
    } on PlatformException {
      return DialResult.failed;
    } on MissingPluginException {
      return DialResult.unsupported;
    }
  }

  @override
  Future<bool> canCallDirectly() => _ask('canCallDirectly');

  @override
  Future<bool> requestDirectCall() => _ask('requestDirectCall');

  Future<bool> _ask(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
