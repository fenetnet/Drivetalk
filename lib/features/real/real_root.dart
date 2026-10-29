import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import 'real_common.dart';
import 'real_first_run.dart';
import 'real_home.dart';
import 'real_moments.dart';
import 'real_people.dart';
import 'real_settings.dart';
import 'real_test_screen.dart';
import '../../domain/hebrew_text.dart';

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
              content: Text(joinHebrewPrefixes(_noticeText(l, n))),
              behavior: SnackBarBehavior.floating,
              duration: Duration(
                seconds:
                    n.kind == RealNoticeKind.micDenied ||
                        n.kind == RealNoticeKind.autoDrivingNoPermission
                    ? 8
                    : 4,
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
        final inCall =
            s.callStage != CallStage.none && s.callStage != CallStage.feedback;
        if (inCall && !s.callHidden) {
          body = RealCallScreen(dark: dark);
        } else if (s.invite != null) {
          body = RealInviteScreen(invite: s.invite!);
        } else if (s.firstRun != null && offer == null && waiting == null) {
          body = const RealFirstRunScreen();
        } else if (offer != null) {
          body = RealOfferScreen(offer: offer, dark: dark);
        } else if (waiting != null) {
          body = RealWaitingScreen(offer: waiting, dark: dark);
        } else if (s.callStage == CallStage.feedback && !dark) {
          // Never while driving: it waits until the drive ends.
          body = const RealFeedbackScreen();
        } else {
          body = const RealShell();
        }
        // The call set aside: a banner on top brings it back.
        if (inCall && s.callHidden && s.call != null) {
          return _BackToCall(name: s.call!.other.name, dark: dark, child: body);
        }
    }
    return body;
  }

  static bool _takeover(RealState s, DateTime now) =>
      s.invite != null ||
      (s.callStage != CallStage.none &&
          s.callStage != CallStage.feedback &&
          !s.callHidden) ||
      currentOffer(s, now) != null ||
      waitingOffer(s, now) != null;

  static String _noticeText(AppLocalizations l, RealNotice n) {
    final g = genderKey(n.gender ?? Gender.unspecified);
    return switch (n.kind) {
      RealNoticeKind.didNotWorkOut => l.realDidNotWorkOut,
      RealNoticeKind.noAnswer => l.realNoAnswer,
      RealNoticeKind.later => l.realLaterNote(n.name ?? ''),
      RealNoticeKind.quickCancelled => l.realQuickCancelled,
      RealNoticeKind.quickTooLate => l.realQuickTooLate,
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
      RealNoticeKind.autoDrivingOn => l.realAutoDrivingOn,
      RealNoticeKind.autoDrivingOff => l.realAutoDrivingOff,
      RealNoticeKind.autoDrivingNoPermission => l.realAutoDrivingNoPermission,
      RealNoticeKind.autoDrivingFailed => l.realAutoDrivingFailed,
      RealNoticeKind.unblocked => l.realUnblocked(n.name ?? ''),
      RealNoticeKind.contactsFound => l.realContactsFound(n.name ?? ''),
      RealNoticeKind.contactsNone => l.realContactsNone,
      RealNoticeKind.contactsNoPermission => l.realContactsNoPermission,
      RealNoticeKind.unblockedReconnected => l.realUnblockedBack(n.name ?? ''),
      RealNoticeKind.askFailed => switch (n.code) {
        'not_free' => l.askNotFree(n.name ?? ''),
        'busy' => l.askBusy(n.name ?? ''),
        'not_now' => l.askNotNow(n.name ?? ''),
        'call_open' => l.askCallOpen(n.name ?? ''),
        'no_number' => l.askNoNumber,
        'me_not_free' => l.askMeNotFree,
        _ => l.askFailed,
      },
      RealNoticeKind.friendKept => l.friendKept(n.name ?? ''),
    };
  }
}

/// Tabs: Home / My people / Test / Settings.
class RealShell extends ConsumerStatefulWidget {
  const RealShell({super.key});

  /// Screenshots / previews only: which tab opens first.
  static set debugInitialTab(int i) => _RealShellState.debugInitialTab = i;

  @override
  ConsumerState<RealShell> createState() => _RealShellState();
}

class _RealShellState extends ConsumerState<RealShell> {
  /// Screenshots / previews only.
  static int debugInitialTab = 0;
  var _index = debugInitialTab;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final testTab = ref.watch(
      realProvider.select((s) => s.admin && s.prefs.testTab),
    );
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

/// Opening (first time, or nothing saved yet): a small car on a moving
/// road, and a line that changes every two seconds (owner, option C).
class _Starting extends StatefulWidget {
  const _Starting();

  @override
  State<_Starting> createState() => _StartingState();
}

class _StartingState extends State<_Starting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _road = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  Timer? _next;
  var _line = 0;

  @override
  void initState() {
    super.initState();
    _next = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _line++);
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    _road.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = context.l10n.startingLines.split('|');
    final text = lines[_line % lines.length];
    return Scaffold(
      backgroundColor: AppColors.terracotta,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 90,
              child: AnimatedBuilder(
                animation: _road,
                builder: (_, _) {
                  final bob = math.sin(_road.value * 2 * math.pi) * 2;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: CustomPaint(
                          size: const Size(220, 6),
                          painter: _RoadPainter(_road.value),
                        ),
                      ),
                      Positioned(
                        bottom: 22 + bob,
                        child: const Icon(
                          Icons.directions_car_rounded,
                          size: 64,
                          color: AppColors.sand,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                text,
                key: ValueKey(_line % lines.length),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Road dashes moving under the car (RTL: the car drives to the left).
class _RoadPainter extends CustomPainter {
  _RoadPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    const dash = 22.0, gap = 18.0;
    final shift = t * (dash + gap);
    for (var x = -dash + shift; x < size.width; x += dash + gap) {
      final a = x.clamp(0.0, size.width), b = (x + dash).clamp(0.0, size.width);
      if (b > a) {
        canvas.drawLine(
          Offset(a, size.height / 2),
          Offset(b, size.height / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.t != t;
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
  final _gender = Gender.unspecified;

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
    final canGo =
        _name.text.trim().isNotEmpty &&
        (_phone.text.trim().isEmpty || normalizePhone(_phone.text) != null) &&
        !s.busy;
    return Scaffold(
      body: Stack(
        children: [
          const PositionedDirectional(
            top: -140,
            end: -100,
            child: _Blob(size: 360, color: AppColors.blush),
          ),
          const PositionedDirectional(
            top: 160,
            start: -150,
            child: _Blob(size: 260, color: AppColors.mint),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.terracotta,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x551565C0),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  l.realWelcomeHeadline,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l.realWelcomeSub,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 17,
                    height: 1.4,
                  ),
                ),
                if (s.invite != null) ...[
                  const SizedBox(height: 14),
                  MomentChip(
                    text: l.realInviteWaitingAfterJoin,
                    icon: Icons.mail_rounded,
                  ),
                ],
                if (c.googleAvailable) ...[
                  const SizedBox(height: 24),
                  if (c.googleEmail case final email?)
                    MomentChip(
                      text: l.googleConnected(email),
                      icon: Icons.check_circle_rounded,
                    )
                  else ...[
                    GoogleButton(
                      label: l.googleContinue,
                      onTap: s.busy
                          ? null
                          : () async {
                              final name = await c.googleStart();
                              if (name != null &&
                                  mounted &&
                                  _name.text.trim().isEmpty) {
                                setState(() => _name.text = name);
                              }
                            },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l.googleOr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F1565C0),
                        blurRadius: 32,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _name,
                        maxLength: 40,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: l.onbNameLabel,
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l.realPhoneRequired,
                          helperText: l.realPhoneRequiredHelp,
                          helperMaxLines: 10,
                          // Say why "let's go" is grey (e.g. a typo).
                          errorText:
                              _phone.text.trim().isNotEmpty &&
                                  normalizePhone(_phone.text) == null
                              ? l.realErrorInvalidPhone
                              : null,
                          errorMaxLines: 2,
                          prefixIcon: const Icon(Icons.phone_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryPill(
                  label: l.realJoin,
                  height: 64,
                  onTap: canGo
                      ? () => c.signIn(_name.text, _gender, phone: _phone.text)
                      : null,
                ),
                if (s.busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 16),
                Text(
                  l.realPrivacyNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// During a call I left for the main screen: one tap goes back to it.
class _BackToCall extends ConsumerWidget {
  const _BackToCall({
    required this.name,
    required this.dark,
    required this.child,
  });
  final String name;
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Column(
      children: [
        Material(
          color: AppColors.sageDark,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: () => ref.read(realProvider.notifier).hideCall(false),
              child: Container(
                constraints: BoxConstraints(minHeight: dark ? 72 : 56),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_in_talk_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.callBackToCall(name),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: dark ? 20 : 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
