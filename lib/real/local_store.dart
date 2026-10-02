import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small key-value storage on this phone (app mode, real-mode settings).
/// Never holds secrets — the login session is stored by Supabase itself.
abstract class LocalStore {
  String? getString(String key);
  Future<void> setString(String key, String? value);
}

class MemoryLocalStore implements LocalStore {
  final values = <String, String>{};
  @override
  String? getString(String key) => values[key];
  @override
  Future<void> setString(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class PrefsLocalStore implements LocalStore {
  PrefsLocalStore(this._prefs);
  final SharedPreferences? _prefs;
  @override
  String? getString(String key) {
    try {
      return _prefs?.getString(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setString(String key, String? value) async {
    try {
      if (value == null) {
        await _prefs?.remove(key);
      } else {
        await _prefs?.setString(key, value);
      }
    } catch (_) {
      // Storage unavailable (e.g. a browser preview): keep going.
    }
  }
}

/// Overridden in main() with [PrefsLocalStore].
final localStoreProvider = Provider<LocalStore>((ref) => MemoryLocalStore());
