import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Phone numbers from the phone's contacts (numbers only). They are hashed
/// in the app before anything is sent (see RealController.syncContacts).
abstract class ContactsReader {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<List<String>> phoneNumbers();
}

class AndroidContactsReader implements ContactsReader {
  static const _channel = MethodChannel('app.drivetalk/contacts');

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> hasPermission() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> phoneNumbers() async {
    if (!_android) return const [];
    try {
      final list = await _channel.invokeListMethod<String>('phoneNumbers');
      return list ?? const [];
    } catch (_) {
      return const [];
    }
  }
}

/// Tests.
class FakeContactsReader implements ContactsReader {
  FakeContactsReader({this.numbers = const [], this.granted = true});
  List<String> numbers;
  bool granted;
  var asked = false;

  @override
  Future<bool> hasPermission() async => granted && asked;
  @override
  Future<bool> requestPermission() async {
    asked = true;
    return granted;
  }

  @override
  Future<List<String>> phoneNumbers() async => granted ? numbers : const [];
}
