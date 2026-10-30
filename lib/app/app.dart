import 'package:flutter/material.dart';

import '../features/real/real_root.dart';
import '../l10n/app_localizations.dart';
import '../real/deep_links.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class DriveTalkApp extends StatelessWidget {
  const DriveTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveBond',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      // Hebrew + RTL first. Adding English = add app_en.arb + a locale here.
      locale: const Locale('he'),
      supportedLocales: const [Locale('he')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(),
      home: const DeepLinkListener(child: RealRoot()),
    );
  }
}
