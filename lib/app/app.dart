import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/real/real_root.dart';
import '../l10n/app_localizations.dart';
import '../real/deep_links.dart';
import '../real/real_controller.dart';
import 'root.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class DriveTalkApp extends StatelessWidget {
  const DriveTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveTalk',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      // Hebrew + RTL first. Adding English = add app_en.arb + a locale here.
      locale: const Locale('he'),
      supportedLocales: const [Locale('he')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(),
      home: const DeepLinkListener(child: ModeGate()),
    );
  }
}

/// Demo (fake people) or the real test with friends — never mixed.
class ModeGate extends ConsumerWidget {
  const ModeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(appModeProvider)) {
      AppMode.demo => const RootGate(),
      AppMode.real => const RealRoot(),
    };
  }
}
