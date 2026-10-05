import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'real/local_store.dart';
import 'real/real_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? store;
  try {
    store = await SharedPreferences.getInstance();
  } catch (_) {
    store = null; // e.g. blocked storage in a browser preview
  }

  var version = '?';
  int? build;
  try {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version} (${info.buildNumber})';
    build = int.tryParse(info.buildNumber);
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(PrefsLocalStore(store)),
        appVersionProvider.overrideWithValue(version),
        appBuildProvider.overrideWithValue(build),
      ],
      child: const DriveTalkApp(),
    ),
  );
}
