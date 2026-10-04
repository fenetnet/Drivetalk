import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'real_models.dart';

/// SHA-256 (hex) of the international form — what leaves the phone instead
/// of the number itself. Null for something that isn't a phone number.
String? hashPhone(String raw) {
  final e = e164Phone(raw);
  return e == null ? null : sha256.convert(utf8.encode(e)).toString();
}
