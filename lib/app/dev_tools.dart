import 'package:flutter/foundation.dart';

/// Developer/debug tools are compiled in only for debug builds or when
/// building the prototype with `--dart-define=DEV_TOOLS=true`.
/// A store/production build never shows them.
const bool kDevTools = bool.fromEnvironment(
  'DEV_TOOLS',
  defaultValue: kDebugMode,
);
