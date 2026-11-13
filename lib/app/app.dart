import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/real/real_root.dart';
import '../l10n/app_localizations.dart';
import '../real/deep_links.dart';
import '../real/real_controller.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class DriveTalkApp extends ConsumerWidget {
  const DriveTalkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hebrew (RTL) or English (LTR): chosen in settings, else the phone's
    // language (1.2.3).
    final chosen = ref.watch(realProvider.select((s) => s.prefs.language));
    final locale = appLocale(chosen, ref.watch(phoneLocaleProvider));
    return MaterialApp(
      title: 'DriveBond',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      locale: locale,
      supportedLocales: const [Locale('he'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(),
      home: const DeepLinkListener(child: RealRoot()),
    );
  }
}
