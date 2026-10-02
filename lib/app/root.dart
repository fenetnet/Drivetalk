import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../debug/debug_screen.dart';
import '../features/call/call_screen.dart';
import '../features/common/labels.dart';
import '../features/connections/connections_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/driver/driver_screen.dart';
import '../features/feedback/feedback_screen.dart';
import '../features/home/home_screen.dart';
import '../features/invitation/invitation_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../l10n/app_localizations.dart';
import 'app.dart';
import 'dev_tools.dart';
import 'providers.dart';
import 'session_controller.dart';

/// Decides which top-level experience is shown. Calls, invitations, driver
/// mode and feedback take over the whole screen.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  bool _takeover(SessionState s, bool driver) =>
      s.invitation != null ||
      s.phase == SessionPhase.inCall ||
      s.phase == SessionPhase.feedback ||
      driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataVersionProvider);
    final prefs = ref.watch(profileServiceProvider).prefs;
    final session = ref.watch(sessionProvider);
    final driver = ref.watch(driverModeProvider);

    // Full-screen states close any pushed pages (e.g. settings) first.
    ref.listen(sessionProvider, (prev, next) {
      final was = prev != null && _takeover(prev, ref.read(driverModeProvider));
      if (!was && _takeover(next, ref.read(driverModeProvider))) {
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
      final notice = next.notice;
      if (notice != null && notice.id != prev?.notice?.id) {
        final l = AppLocalizations.of(context);
        messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_noticeText(l, notice, ref)),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });
    ref.listen(driverModeProvider, (prev, next) {
      if (next && prev != true) {
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
    });

    final Widget body;
    if (!prefs.onboardingDone) {
      body = const OnboardingScreen();
    } else if (session.invitation != null) {
      body = InvitationScreen(driverMode: driver);
    } else if (session.phase == SessionPhase.inCall) {
      body = CallScreen(driverMode: driver);
    } else if (driver) {
      body = const DriverScreen();
    } else if (session.phase == SessionPhase.feedback) {
      body = const FeedbackScreen();
    } else {
      body = const MainShell();
    }

    return Stack(
      children: [
        Positioned.fill(child: body),
        if (kDevTools) const _DevToolsButton(),
      ],
    );
  }

  String _noticeText(AppLocalizations l, SessionNotice n, WidgetRef ref) {
    final p = n.person;
    final name = p?.name ?? '';
    final g = p == null ? 'other' : genderKey(p.gender);
    return switch (n.kind) {
      NoticeKind.declinedByOther => l.noticeDeclined(name, g),
      NoticeKind.availabilityEnded => l.noticeAvailabilityEnded,
      NoticeKind.invitationMuted => l.noticeInvitationMuted(
        ref.read(matchingConfigProvider).snooze.beaconMuteHours,
      ),
      NoticeKind.blocked => l.noticeBlocked(name, g),
      NoticeKind.reported => l.noticeReported,
      NoticeKind.pausedNotToday => l.noticePausedToday(name),
      NoticeKind.pausedForAWhile => l.noticePausedWhile(name),
    };
  }
}

class _DevToolsButton extends StatelessWidget {
  const _DevToolsButton();

  @override
  Widget build(BuildContext context) {
    // Small, semi-transparent, on the edge — out of the way of real buttons.
    return PositionedDirectional(
      end: 2,
      top: 0,
      bottom: 0,
      child: Center(
        child: Opacity(
          opacity: 0.55,
          child: FloatingActionButton.small(
            heroTag: 'devtools',
            tooltip: AppLocalizations.of(context).debugTitle,
            backgroundColor: const Color(0xFF3D405B),
            foregroundColor: Colors.white,
            onPressed: () => navigatorKey.currentState?.push(
              MaterialPageRoute<void>(builder: (_) => const DebugScreen()),
            ),
            child: const Icon(Icons.build_rounded),
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation: Home / Connections / Discover / Settings. No feed.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          ConnectionsScreen(),
          DiscoverScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_rounded),
            label: l.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_alt_rounded),
            label: l.tabConnections,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_rounded),
            label: l.tabDiscover,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_rounded),
            label: l.tabSettings,
          ),
        ],
      ),
    );
  }
}
