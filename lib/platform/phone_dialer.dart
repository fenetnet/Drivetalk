import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum DialResult { calling, openedDialer, unsupported, failed }

/// Places a regular phone call with the phone's own dialer.
abstract class PhoneDialer {
  Future<DialResult> call(String number);
}

/// Android: one-tap call (ACTION_CALL) when the "phone calls" permission is
/// granted; otherwise opens the dialer with the number filled in.
/// Implemented by a tiny Kotlin bridge in MainActivity.kt.
class PlatformPhoneDialer implements PhoneDialer {
  static const _channel = MethodChannel('app.drivetalk/phone');

  @override
  Future<DialResult> call(String number) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return DialResult.unsupported;
    }
    try {
      final status = await Permission.phone.request();
      final direct = status.isGranted;
      final ok = await _channel.invokeMethod<bool>('call', {
        'number': number,
        'direct': direct,
      });
      if (ok != true) return DialResult.failed;
      return direct ? DialResult.calling : DialResult.openedDialer;
    } on PlatformException {
      return DialResult.failed;
    } on MissingPluginException {
      return DialResult.unsupported;
    }
  }
}
