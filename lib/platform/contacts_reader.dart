import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A number from the phone's contacts and the name saved for it here.
/// Numbers are hashed before anything is sent; names never leave the phone.
class PhoneContact {
  const PhoneContact(this.number, this.name);
  final String number;
  final String name;
}

/// The phone's contacts (see RealController.syncContacts).
abstract class ContactsReader {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<List<PhoneContact>> contacts();
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
  Future<List<PhoneContact>> contacts() async {
    if (!_android) return const [];
    try {
      final list = await _channel.invokeListMethod<Object?>('contacts');
      return [
        for (final m in list ?? const [])
          if (m is Map)
            PhoneContact('${m['number'] ?? ''}', '${m['name'] ?? ''}'),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// Tests.
class FakeContactsReader implements ContactsReader {
  FakeContactsReader({
    this.numbers = const [],
    this.names = const {},
    this.granted = true,
  });
  List<String> numbers;

  /// Number → the name saved for it (tests).
  Map<String, String> names;
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
  Future<List<PhoneContact>> contacts() async => granted
      ? [for (final n in numbers) PhoneContact(n, names[n] ?? '')]
      : const [];
}
