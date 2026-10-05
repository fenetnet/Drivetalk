import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Friends' photos kept on this phone, so they don't download every launch.
/// In the app's cache folder: not backed up, and the phone may clear it.
abstract class PhotoCache {
  Future<Map<String, (int, Uint8List)>> loadAll();
  Future<void> put(String userId, int version, Uint8List bytes);
  Future<void> remove(String userId);
  Future<void> clear();
}

class MemoryPhotoCache implements PhotoCache {
  final files = <String, (int, Uint8List)>{};

  @override
  Future<Map<String, (int, Uint8List)>> loadAll() async => {...files};
  @override
  Future<void> put(String userId, int version, Uint8List bytes) async =>
      files[userId] = (version, bytes);
  @override
  Future<void> remove(String userId) async => files.remove(userId);
  @override
  Future<void> clear() async => files.clear();
}

/// `cache/avatars/{user id}.{version}.jpg`
class FilePhotoCache implements PhotoCache {
  Directory? _dir;

  Future<Directory?> _folder() async {
    if (kIsWeb) return null;
    try {
      final d = _dir ??= Directory(
        '${(await getApplicationCacheDirectory()).path}/avatars',
      );
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    } catch (_) {
      return null; // No file system here: photos just download again.
    }
  }

  static final _name = RegExp(r'^([A-Za-z0-9-]+)\.(\d+)\.jpg$');

  @override
  Future<Map<String, (int, Uint8List)>> loadAll() async {
    final d = await _folder();
    if (d == null) return {};
    final out = <String, (int, Uint8List)>{};
    try {
      await for (final f in d.list()) {
        if (f is! File) continue;
        final m = _name.firstMatch(f.uri.pathSegments.last);
        if (m == null) continue;
        out[m.group(1)!] = (int.parse(m.group(2)!), await f.readAsBytes());
      }
    } catch (_) {}
    return out;
  }

  @override
  Future<void> put(String userId, int version, Uint8List bytes) async {
    await remove(userId);
    final d = await _folder();
    if (d == null) return;
    try {
      await File('${d.path}/$userId.$version.jpg').writeAsBytes(bytes);
    } catch (_) {}
  }

  @override
  Future<void> remove(String userId) async {
    final d = await _folder();
    if (d == null) return;
    try {
      await for (final f in d.list()) {
        if (f is File && f.uri.pathSegments.last.startsWith('$userId.')) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    final d = await _folder();
    if (d == null) return;
    try {
      await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}
