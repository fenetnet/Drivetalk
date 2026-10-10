import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../../real/routine_suggest.dart';
import '../availability/pick_mode_screen.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'real_common.dart';
import 'real_people.dart';

/// "Driving / walking / break / free" tapped on Home: straight to "for how
/// long?" (the first time, one short note about the phone's questions).
Future<void> openRealDuration(
  BuildContext context,
  WidgetRef ref,
  AvailabilityMode mode,
) async {
  final c = ref.read(realProvider.notifier);
  if (c.needsPermissionIntro) {
    final l = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.permIntroTitle),
        content: SingleChildScrollView(child: Text(l.permIntroBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(l.permIntroGo),
          ),
        ],
      ),
    );
    if (go != true) return;
    c.markPermissionIntroShown();
  }
  final circles = ref.read(realProvider).snapshot?.circles ?? const [];
  // A message at the bottom would fly between the two pages: clear it.
  messengerKey.currentState?.removeCurrentSnackBar();
  await navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => PickDurationScreen(
        mode: mode,
        realCircles: [for (final c in circles) (c.id, c.name)],
        onStart: (mode, minutes, circleId) => ref
            .read(realProvider.notifier)
            .startAvailability(mode, minutes, circleId: circleId),
      ),
    ),
  );
}

/// "I have time now — what are you doing?" Four buttons, one tap each.
class _ModeButtons extends ConsumerWidget {
  const _ModeButtons({required this.title, required this.busy});
  final String title;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    Widget tile(AvailabilityMode m) => Expanded(
      child: SizedBox(
        height: 96,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.terracotta,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 4,
            shadowColor: const Color(0x661565C0),
          ),
          onPressed: busy ? null : () => openRealDuration(context, ref, m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(modeIcon(m), size: 32),
              const SizedBox(height: 6),
              Text(
                modeLabel(l, m),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          l.homeWhatNow,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            tile(AvailabilityMode.driving),
            const SizedBox(width: 12),
            tile(AvailabilityMode.walking),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(AvailabilityMode.breakTime),
            const SizedBox(width: 12),
            tile(AvailabilityMode.free),
          ],
        ),
      ],
    );
  }
}

/// The automatic-driving switch, with its one-time explanation.
Future<void> setAutoDriving(
  BuildContext context,
  WidgetRef ref,
  bool on,
) async {
  final l = context.l10n;
  final c = ref.read(realProvider.notifier);
  if (!on) {
    await c.disableAutoDriving();
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l.realAutoDrivingDialogTitle),
      content: Text(l.realAutoDrivingDialogBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(l.enable),
        ),
      ],
    ),
  );
  if (ok ?? false) await c.enableAutoDriving();
}

/// Home: greeting, who's free now (avatars), and one big round
/// "I'm free now" button. When I'm free, the button becomes my status.
class RealHomeScreen extends ConsumerWidget {
  const RealHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final now = ref.watch(realNowProvider);
    final snap = s.snapshot;
    final me = snap?.me;
    final mine = myActiveAvailability(s, now);
    // People I haven't talked with in a while come first.
    final free = [...freeFriends(s, now)]
      ..sort((a, b) {
        final ta = snap?.lastTalk[a.$1.id];
        final tb = snap?.lastTalk[b.$1.id];
        if (ta == null) return tb == null ? 0 : -1;
        if (tb == null) return 1;
        return ta.compareTo(tb);
      });
    final g = genderKey(me?.gender ?? Gender.unspecified);
    final hour = now.hour;
    final greet = hour < 5
        ? l.realGreetNight
        : hour < 12
        ? l.realGreetMorning
        : hour < 17
        ? l.realGreetNoon
        : hour < 22
        ? l.realGreetEvening
        : l.realGreetNight;

    return Stack(
      children: [
        // Soft decorative circles.
        const PositionedDirectional(
          top: -120,
          end: -80,
          child: _Blob(size: 340, color: AppColors.blush),
        ),
        const PositionedDirectional(
          top: 120,
          start: -140,
          child: _Blob(size: 260, color: AppColors.mint),
        ),
        SafeArea(
          child: RefreshIndicator(
            onRefresh: c.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        greet,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                    if (me != null) RealAvatar(person: me.toPerson(), size: 42),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  me == null ? l.homeGreetingNoName : l.realHomeTitle(me.name),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (s.serverOutdated && s.admin) ...[
                  const SizedBox(height: 10),
                  MomentChip(
                    text: l.realServerOutdated(
                      s.serverSchema!,
                      kRequiredSchema,
                    ),
                    icon: Icons.system_update_alt_rounded,
                  ),
                ],
                if (s.lastError == 'offline') ...[
                  const SizedBox(height: 10),
                  MomentChip(
                    text: l.realErrorOffline,
                    icon: Icons.wifi_off_rounded,
                  ),
                ],
                const SizedBox(height: 24),
                if (snap != null && snap.friends.isEmpty)
                  const _NoFriendsCard()
                else if (snap != null && snap.hidden)
                  const _HiddenCard()
                else
                  _FreeNowCard(
                    free: free,
                    busy: busyFriends(s, now),
                    now: now,
                    meFree: mine != null,
                  ),
                // At most ONE small card at a time (the most useful one).
                if (_tipCard(s, c, now, snap) case final tip?) ...[
                  const SizedBox(height: 16),
                  tip,
                ],
                const SizedBox(height: 28),
                if (mine == null)
                  _ModeButtons(title: l.homeImFreeNow(g), busy: s.busy)
                else
                  Center(
                    child: _MyStatus(mine: mine, now: now, gender: g),
                  ),
                const SizedBox(height: 28),
                if (snap != null && snap.friends.isNotEmpty) ...[
                  _WeekCard(week: snap.weekAt(now)),
                  const SizedBox(height: 12),
                ],
                if (s.driving.supported)
                  _AutoDrivingRow(on: s.driving.enabled, busy: s.busy),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The one card under "Now": update > someone from my contacts joined >
/// routine now > routine idea > the home-screen button tip.
Widget? _tipCard(
  RealState s,
  RealController c,
  DateTime now,
  RealSnapshot? snap,
) {
  if (s.newBuild != null) return const _UpdateCard();
  if (c.newContactMatch case final m?) return _NewContactCard(match: m);
  if (c.showBackgroundTip) return const _BackgroundCard();
  if (c.dueRoutine(now) case final r?) return _RoutineCard(routine: r);
  if (c.routineSuggestion(now) case final hint?) {
    return _RoutineHintCard(hint: hint);
  }
  if (c.showWidgetTip && (snap?.friends.isNotEmpty ?? false)) {
    return const _WidgetTipCard();
  }
  return null;
}

/// Once: "a one-tap 'I'm free' button for the home screen".
class _WidgetTipCard extends ConsumerWidget {
  const _WidgetTipCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.widgets_rounded, color: AppColors.sageDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.widgetTip, style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: c.dismissWidgetTip,
              child: Text(l.gotIt),
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

/// "Free now" card: friends' faces with a green ring.
class _FreeNowCard extends StatelessWidget {
  const _FreeNowCard({
    required this.free,
    required this.busy,
    required this.now,
    required this.meFree,
  });
  final List<(RealProfile, RealAvailability)> free;

  /// Free, but in a call right now: shown after the free ones.
  final List<(RealProfile, RealAvailability)> busy;
  final DateTime now;
  final bool meFree;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  l.realFreeFriendsTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (free.isNotEmpty)
                MomentChip(text: l.realFreeCount(free.length)),
            ],
          ),
          const SizedBox(height: 16),
          if (free.isEmpty && busy.isEmpty)
            Text(
              meFree ? l.realNobodyFreeYet : l.realNobodyFree,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
            )
          else
            SizedBox(
              height: 138,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: free.length + busy.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final inCall = i >= free.length;
                  final (p, a) = inCall ? busy[i - free.length] : free[i];
                  return SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        RealAvatar(person: p.toPerson(), online: !inCall),
                        const SizedBox(height: 8),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        StatusLine(
                          icon: inCall ? Icons.call_rounded : modeIcon(a.mode),
                          // The picture says how (car, coffee…); the text
                          // just how long.
                          text: inCall
                              ? l.inCall
                              : l.timeLeftMinutes(a.minutesLeftAt(now)),
                          color: inCall
                              ? AppColors.coralDeep
                              : AppColors.inkSoft,
                          bold: inCall,
                          size: 12,
                          center: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          // Their faces don't do anything by themselves: say what does.
          if (!meFree && free.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.realFreeHint,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// When I'm free: a green circle with my status, and a small stop button.
class _MyStatus extends ConsumerWidget {
  const _MyStatus({
    required this.mine,
    required this.now,
    required this.gender,
  });
  final RealAvailability mine;
  final DateTime now;
  final String gender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    return Column(
      children: [
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const PulsingCircle(size: 236, color: AppColors.mint),
              Container(
                width: 190,
                height: 190,
                decoration: const BoxDecoration(
                  color: AppColors.sageDark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x552F6B57),
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(modeIcon(mine.mode), color: Colors.white, size: 34),
                    const SizedBox(height: 6),
                    Text(
                      l.realMeAvailableTitle(gender),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.timeLeftMinutes(mine.minutesLeftAt(now)),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Text(
          l.realWaitingForFriends,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: c.stopAvailability,
          icon: const Icon(Icons.stop_rounded),
          label: Text(l.stopAvailability),
        ),
      ],
    );
  }
}

/// "Usually free on Sundays around 17:30 — make it a routine?" (asks; never
/// does it by itself).
class _RoutineHintCard extends ConsumerWidget {
  const _RoutineHintCard({required this.hint});
  final RoutineSuggestion hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final time =
        '${(hint.minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
        '${(hint.minuteOfDay % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.coralDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.routineHint(weekdayShort(l, hint.weekday), time),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => c.dismissRoutineSuggestion(hint),
                child: Text(l.routineHintNo),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: () => c.acceptRoutineSuggestion(hint),
                child: Text(l.routineHintYes),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "A new version of DriveTalk is out" → opens the download (the phone
/// installs it over this one; friends and settings stay).
class _UpdateCard extends StatelessWidget {
  const _UpdateCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppColors.sageDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.updateAvailable,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.updateHow,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: openAppUpdate,
            child: Text(l.updateNow),
          ),
        ],
      ),
    );
  }
}

/// "It's your usual time for driving — be available for 30 min?"
class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({required this.routine});
  final Routine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.blush,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(modeIcon(routine.mode), color: AppColors.coralDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.routineDue(modeLabel(l, routine.mode), routine.durationMinutes),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => ref
                .read(realProvider.notifier)
                .startAvailability(
                  routine.mode,
                  routine.durationMinutes,
                  circleId: routine.circleId,
                ),
            child: Text(l.routineStart),
          ),
        ],
      ),
    );
  }
}

/// "Your week": how many talks, with how many different friends.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});
  final (int, int) week;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (talks, friends) = week;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.sageDark,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$talks',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.realWeekTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.sageDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  talks == 0
                      ? l.realWeekTalks(0)
                      : '${l.realWeekTalks(talks)} ${l.realWeekFriends(friends)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
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

class _AutoDrivingRow extends ConsumerWidget {
  const _AutoDrivingRow({required this.on, required this.busy});
  final bool on;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        secondary: const Icon(
          Icons.directions_car_rounded,
          color: AppColors.sageDark,
        ),
        title: Text(
          l.realAutoDriving,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        value: on,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.sageDark,
        onChanged: busy ? null : (v) => setAutoDriving(context, ref, v),
      ),
    );
  }
}

class _NoFriendsCard extends ConsumerWidget {
  const _NoFriendsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final busy = ref.watch(realProvider.select((s) => s.busy));
    return Container(
      padding: const EdgeInsets.all(22),
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
          const Icon(
            Icons.group_add_rounded,
            size: 44,
            color: AppColors.terracotta,
          ),
          const SizedBox(height: 10),
          Text(
            l.realNoFriendsTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            l.realNoFriendsBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () => ref.read(realProvider.notifier).syncContacts(),
            icon: const Icon(Icons.contacts_rounded),
            label: Text(l.realContactsButton),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => shareInvite(context, ref),
            icon: const Icon(Icons.share_rounded),
            label: Text(l.realInviteFriend),
          ),
        ],
      ),
    );
  }
}

/// Driving, nothing happening: dark, calm, one huge stop button.
class RealDriverHome extends ConsumerWidget {
  const RealDriverHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final now = ref.watch(realNowProvider);
    final mine = myActiveAvailability(s, now);
    final c = ref.read(realProvider.notifier);
    return MomentLayout(
      style: MomentStyle.dark,
      footer: l.driverSafety,
      header: MomentChip(
        text: l.realNotifChannelStatus,
        style: MomentStyle.dark,
        dot: AppColors.sage,
      ),
      top: Column(
        children: [
          PulsingCircle(
            size: 160,
            color: AppColors.sage.withValues(alpha: 0.35),
            child: Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 28),
          MomentText(l.driverSearching, size: 30, style: MomentStyle.dark),
          if (mine != null) ...[
            const SizedBox(height: 6),
            MomentText(
              l.timeLeftMinutes(mine.minutesLeftAt(now)),
              size: 20,
              style: MomentStyle.dark,
              soft: true,
            ),
          ],
        ],
      ),
      actions: [
        SecondaryPill(
          label: l.driverStop,
          style: MomentStyle.dark,
          height: 96,
          onTap: c.stopAvailability,
        ),
      ],
    );
  }
}

/// My status is hidden: so I don't see who's free either.
/// (Set by an older version of the app; this one uses "who sees me".)
class _HiddenCard extends ConsumerWidget {
  const _HiddenCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.visibility_off_rounded,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(context.l10n.hiddenNote)),
              ],
            ),
            TextButton(
              onPressed: () =>
                  ref.read(realProvider.notifier).setHideStatus(false),
              child: Text(context.l10n.hiddenUnhide),
            ),
          ],
        ),
      ),
    );
  }
}

/// Someone from my contacts joined: add them? (Nothing happens otherwise.)
class _NewContactCard extends ConsumerWidget {
  const _NewContactCard({required this.match});
  final ContactMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final busy = ref.watch(realProvider.select((s) => s.busy));
    final c = ref.read(realProvider.notifier);
    return Card(
      color: AppColors.blush,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.newContactTitle(match.name),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(l.newContactBody),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => c.addContacts([match]),
                    child: Text(l.contactsAdd),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => c.dismissMatch(match),
                  child: Text(l.contactsNo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Battery saving would stop trips and "a friend is free": allow it once.
class _BackgroundCard extends ConsumerWidget {
  const _BackgroundCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.battery_alert_rounded,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.backgroundTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l.backgroundBody),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: c.allowBackground,
                    child: Text(l.backgroundAllow),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: c.dismissBackgroundTip,
                  child: Text(l.notNowShort),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
