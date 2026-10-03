import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import '../common/labels.dart';
import 'real_common.dart';
import 'real_home.dart';
import 'real_moments.dart';
import 'real_people.dart';
import 'real_settings.dart';
import 'real_test_screen.dart';

/// Real (two-user test) mode: what to show right now.
class RealRoot extends ConsumerWidget {
  const RealRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(realProvider);
    final now = ref.watch(realNowProvider);
    final dark = isRealDriving(s, now);

    ref.listen(realProvider, (prev, next) {
      // Full-screen moments close pushed pages (settings, code entry…).
      final nowT = ref.read(realClockProvider)();
      final was = prev != null && _takeover(prev, nowT);
      if (!was && _takeover(next, nowT)) {
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
      final n = next.notice;
      if (n != null && n.id != prev?.notice?.id) {
        final l = AppLocalizations.of(context);
        messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_noticeText(l, n)),
              behavior: SnackBarBehavior.floating,
              duration: Duration(
                seconds: n.kind == RealNoticeKind.micDenied ? 8 : 4,
              ),
            ),
          );
      }
    });

    final Widget body;
    switch (s.phase) {
      case RealPhase.notConfigured:
        body = const _NotConfigured();
      case RealPhase.starting:
        body = const _Starting();
      case RealPhase.signedOut:
        body = const RealOnboarding();
      case RealPhase.ready:
        final offer = currentOffer(s, now);
        final waiting = waitingOffer(s, now);
        if (s.callStage != CallStage.none &&
            s.callStage != CallStage.feedback) {
          body = RealCallScreen(dark: dark);
        } else if (s.invite != null) {
          body = RealInviteScreen(invite: s.invite!);
        } else if (offer != null) {
          body = RealOfferScreen(offer: offer, dark: dark);
        } else if (waiting != null) {
          body = RealWaitingScreen(offer: waiting, dark: dark);
        } else if (s.callStage == CallStage.feedback && !dark) {
          // Never while driving: it waits until the drive ends.
          body = const RealFeedbackScreen();
        } else if (dark) {
          body = const RealDriverHome();
        } else {
          body = const RealShell();
        }
    }
    return body;
  }

  static bool _takeover(RealState s, DateTime now) =>
      s.invite != null ||
      (s.callStage != CallStage.none && s.callStage != CallStage.feedback) ||
      currentOffer(s, now) != null ||
      waitingOffer(s, now) != null;

  static String _noticeText(AppLocalizations l, RealNotice n) {
    final g = genderKey(n.gender ?? Gender.unspecified);
    return switch (n.kind) {
      RealNoticeKind.didNotWorkOut => l.realDidNotWorkOut,
      RealNoticeKind.connected => l.realConnected(n.name ?? ''),
      RealNoticeKind.inviteProblem => inviteProblemText(l, n.code),
      RealNoticeKind.error => realErrorText(l, n.code ?? 'unknown'),
      RealNoticeKind.blocked => l.noticeBlocked(n.name ?? '', g),
      RealNoticeKind.reported => l.noticeReported,
      RealNoticeKind.unmatched => l.realUnmatched(n.name ?? ''),
      RealNoticeKind.feedbackThanks => l.realFeedbackThanks,
      RealNoticeKind.saved => l.realSaved,
      RealNoticeKind.dialFailed => l.realDialFailed,
      RealNoticeKind.micDenied => l.noticeMicDenied,
    };
  }
}

/// Tabs: Home / My people / Test / Settings.
class RealShell extends ConsumerStatefulWidget {
  const RealShell({super.key});

  @override
  ConsumerState<RealShell> createState() => _RealShellState();
}

class _RealShellState extends ConsumerState<RealShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final testTab = ref.watch(realProvider.select((s) => s.prefs.testTab));
    final pages = [
      const RealHomeScreen(),
      const RealPeopleScreen(),
      if (testTab) const RealTestScreen(),
      const RealSettingsScreen(),
    ];
    final index = _index.clamp(0, pages.length - 1);
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_rounded),
            label: l.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_alt_rounded),
            label: l.realTabPeople,
          ),
          if (testTab)
            NavigationDestination(
              icon: const Icon(Icons.fact_check_rounded),
              label: l.realTabTest,
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

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.l10n.realStarting),
          ],
        ),
      ),
    );
  }
}

class _NotConfigured extends ConsumerWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 72,
                color: AppColors.inkSoft,
              ),
              const SizedBox(height: 20),
              Text(
                l.realNotConfiguredTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                l.realNotConfiguredBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () =>
                    ref.read(appModeProvider.notifier).set(AppMode.demo),
                child: Text(l.realBackToDemo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First time in real mode: a name (and optionally a phone number).
class RealOnboarding extends ConsumerStatefulWidget {
  const RealOnboarding({super.key});

  @override
  ConsumerState<RealOnboarding> createState() => _RealOnboardingState();
}

class _RealOnboardingState extends ConsumerState<RealOnboarding> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  // No gender question (owner decision D-044).
  final _gender = Gender.male;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final canGo = _name.text.trim().isNotEmpty && !s.busy;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.realWelcomeTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(appModeProvider.notifier).set(AppMode.demo),
                  child: Text(l.realBackToDemo),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.realWelcomeBody,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 16),
            ),
            if (s.invite != null) ...[
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFDCEBE3),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_rounded, color: AppColors.sageDark),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l.realInviteWaitingAfterJoin)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              maxLength: 40,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.onbNameLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l.realPhoneLabel,
                helperText: l.realPhoneHelp,
                helperMaxLines: 4,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: canGo
                  ? () => c.signIn(
                      _name.text,
                      _gender,
                      phone: _phone.text.trim().isEmpty ? null : _phone.text,
                    )
                  : null,
              child: s.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(l.realJoin),
            ),
            const SizedBox(height: 16),
            Text(
              l.realPrivacyNote,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
