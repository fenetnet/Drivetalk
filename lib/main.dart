import 'package:flutter/foundation.dart';
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

  final container = ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(PrefsLocalStore(store)),
      appVersionProvider.overrideWithValue(version),
      appBuildProvider.overrideWithValue(build),
    ],
  );

  // A crash: a short technical note to the owner (no personal data).
  void report(String kind, Object error, StackTrace? stack) {
    if (!kReleaseMode) return;
    try {
      container.read(realProvider.notifier).reportCrash(kind, error, stack);
    } catch (_) {
      // Never crash while reporting a crash.
    }
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    report('flutter', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    report('dart', error, stack);
    return true;
  };

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DriveTalkApp(),
    ),
  );
}
