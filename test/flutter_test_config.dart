import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// The tests run on a "Hebrew phone", like most of our users (1.2.3: the
/// app follows the phone's language). English has its own test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // The live test talks to a real server: no test binding (it blocks the
  // network); it sets its own language.
  if (Platform.environment['SUPABASE_LIVE_URL']?.isNotEmpty ?? false) {
    await testMain();
    return;
  }
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localeTestValue = const Locale('he', 'IL');
  binding.platformDispatcher.localesTestValue = const [Locale('he', 'IL')];
  await testMain();
}
