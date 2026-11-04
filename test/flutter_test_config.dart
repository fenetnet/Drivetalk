import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// The tests run on a "Hebrew phone", like most of our users (1.2.3: the
/// app follows the phone's language). English has its own test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localeTestValue = const Locale('he', 'IL');
  binding.platformDispatcher.localesTestValue = const [Locale('he', 'IL')];
  await testMain();
}
