import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_config.dart';

/// "Is there a newer version?" — reads the small version.json that the
/// build publishes next to the APK. No account, nothing sent about the user.
abstract class UpdateChecker {
  /// The newest build number, or null if unknown (offline etc.).
  Future<int?> latestBuild();
}

class HttpUpdateChecker implements UpdateChecker {
  @override
  Future<int?> latestBuild() async {
    try {
      final r = await http
          .get(Uri.parse(BackendConfig.latestVersionUrl))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return ((jsonDecode(r.body) as Map)['build'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }
}

class FakeUpdateChecker implements UpdateChecker {
  FakeUpdateChecker([this.build]);
  int? build;
  @override
  Future<int?> latestBuild() async => build;
}
