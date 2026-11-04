import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../real/backend_config.dart';

/// What Google hands back: a one-time proof for our server, plus the name
/// and email (shown on this phone only).
class GoogleToken {
  const GoogleToken(this.idToken, {this.email, this.name});
  final String idToken;
  final String? email;
  final String? name;
}

/// "Continue with Google" (owner: no duplicate accounts on a new phone).
abstract class GoogleAuth {
  /// Shown only where it works (Android with the app's Google client id).
  bool get available;

  /// The account picker. null = the person closed it.
  Future<GoogleToken?> signIn();

  /// Next time the picker asks again (after signing out).
  Future<void> signOut();
}

class DeviceGoogleAuth implements GoogleAuth {
  bool _ready = false;

  @override
  bool get available =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      BackendConfig.googleWebClientId.isNotEmpty;

  Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: BackendConfig.googleWebClientId,
    );
    _ready = true;
  }

  @override
  Future<GoogleToken?> signIn() async {
    await _init();
    try {
      final a = await GoogleSignIn.instance.authenticate();
      final token = a.authentication.idToken;
      if (token == null) return null;
      return GoogleToken(token, email: a.email, name: a.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to forget.
    }
  }
}

/// Tests: a fixed Google account (or none).
class FakeGoogleAuth implements GoogleAuth {
  FakeGoogleAuth({this.token});
  GoogleToken? token;
  int signOuts = 0;

  @override
  bool get available => true;

  @override
  Future<GoogleToken?> signIn() async => token;

  @override
  Future<void> signOut() async => signOuts++;
}
