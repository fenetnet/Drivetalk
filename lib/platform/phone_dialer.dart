import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DialResult { calling, openedDialer, unsupported, failed }

/// Places a regular phone call with the phone's own dialer.
abstract class PhoneDialer {
  Future<DialResult> call(String number);
}

/// Android: one-tap call (ACTION_CALL) when the "phone calls" permission is
/// granted (asked on first use); otherwise opens the dialer with the number.
/// Implemented by a tiny Kotlin bridge in MainActivity.kt.
class PlatformPhoneDialer implements PhoneDialer {
  static const _channel = MethodChannel('app.drivetalk/phone');

  @override
  Future<DialResult> call(String number) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return DialResult.unsupported;
    }
    try {
      // The bridge asks for the "phone calls" permission the first time.
      final r = await _channel.invokeMethod<String>('call', {'number': number});
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
}
