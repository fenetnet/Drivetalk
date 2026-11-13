import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What Google Play passed through the install (1.3.0), e.g.
/// "invite=<code>" from a friend's store link. null = nothing / unknown.
abstract class InstallReferrer {
  Future<String?> get();
}

class AndroidInstallReferrer implements InstallReferrer {
  static const _channel = MethodChannel('app.drivetalk/referrer');

  @override
  Future<String?> get() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      // No time limit here: nothing waits for it (a timer would outlive
      // short-lived screens).
      return await _channel.invokeMethod<String>('get');
    } catch (_) {
      return null;
    }
  }
}

/// Tests.
class FakeInstallReferrer implements InstallReferrer {
  FakeInstallReferrer([this.value]);
  String? value;
  var asked = 0;

  @override
  Future<String?> get() async {
    asked++;
    return value;
  }
}

final installReferrerProvider = Provider<InstallReferrer>(
  (ref) => AndroidInstallReferrer(),
);

/// The invitation code inside Google Play's referrer text, if any
/// ("invite=<code>", maybe among other parameters, maybe still encoded).
String? inviteFromReferrer(String? referrer) {
  if (referrer == null || referrer.isEmpty) return null;
  var text = referrer;
  for (var i = 0; i < 2 && text.contains('%'); i++) {
    try {
      text = Uri.decodeComponent(text);
    } catch (_) {
      break;
    }
  }
  for (final part in text.split('&')) {
    final kv = part.split('=');
    if (kv.length == 2 &&
        kv[0] == 'invite' &&
        RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(kv[1])) {
      return kv[1];
    }
  }
  return null;
}
