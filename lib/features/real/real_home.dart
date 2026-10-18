import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../real/backend_config.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../../real/routine_suggest.dart';
import '../availability/pick_mode_screen.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'real_common.dart';
import 'real_quick.dart';
import 'real_people.dart';

/// "Driving / walking / break / free" tapped on Home: straight to "for how
/// long?" (the first time, one short note about the phone's questions).
Future<void> openRealDuration(
  BuildContext context,
  WidgetRef ref,
  AvailabilityMode mode,
) async {
  // Read everything now: the screen behind may change (a trip starts, a
  // question arrives) while the picker is open, and its `ref` goes with it.
  final c = ref.read(realProvider.notifier);
  final circles = ref.read(realProvider).snapshot?.circles ?? const [];
  final tripDetection = ref.read(realProvider).driving.enabled;
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
  // A message at the bottom would fly between the two pages: clear it.
  messengerKey.currentState?.removeCurrentSnackBar();
  await navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => PickDurationScreen(
        mode: mode,
        realCircles: [for (final c in circles) (c.id, c.name)],
        tripDetection: tripDetection,
        onStart: (mode, minutes, circleId, {untilTripEnds = false}) =>
            c.startAvailability(
              mode,
              minutes,
              circleId: circleId,
              untilTripEnds: untilTripEnds,
            ),
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
    final free = friendsToShow(s, now);
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
                if (isRealDriving(s, now)) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: () => c.showNormalView(false),
                    icon: const Icon(Icons.directions_car_rounded),
                    label: Text(
                      l.driverBack,
                      style: const TextStyle(fontSize: 18),
                    ),
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
                    notNow: [
                      for (final f in freeFriends(s, now))
                        if (!free.any((x) => x.$1.id == f.$1.id)) f,
                    ],
                    now: now,
                    meFree: mine != null,
                    hiddenFree: snap?.status.hiddenFree ?? 0,
                    anonymous: snap?.status.anonymous ?? false,
                  ),
                // A friend turned quick connect on for me (D-112): its
                // own place, never hidden behind another card.
                if (c.quickAsk case final f?) ...[
                  const SizedBox(height: 16),
                  QuickAskCard(friend: f),
                ],
                // At most ONE small card at a time (the most useful one).
                if (_tipCard(s, c, now, snap) case final tip?) ...[
                  const SizedBox(height: 16),
                  tip,
                ],
                // Who's free first, then my buttons (the owner's choice).
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
  // "Still free?" after a question I didn't answer — only here, in the app.
  if (myActiveAvailability(s, now)?.missed ?? false) return const _MissedCard();
  if (s.newBuild != null) return const _UpdateCard();
  if (s.driving.enabled && (snap?.status.autoMissed ?? 0) >= 2) {
    return const _AutoMissedCard();
  }
  // Someone added me from their contacts: keep them?
  if (c.pendingFriend case final f?) return _PendingFriendCard(friend: f);
  if (c.newFriend case final f?) return _NewFriendCard(friend: f);
  if (c.newContactMatch case final m?) return _NewContactCard(match: m);
  if (c.showQuickIntro) return const QuickIntroCard();
  if (c.showAddNumber) return const _AddNumberCard();
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
class _FreeNowCard extends ConsumerWidget {
  const _FreeNowCard({
    required this.free,
    required this.busy,
    required this.now,
    required this.meFree,
    this.hiddenFree = 0,
    this.anonymous = false,
    this.notNow = const [],
  });

  /// Free, but they can't be asked right now (shown faded, last; why is
  /// never said — it may be their private choice).
  final List<(RealProfile, RealAvailability)> notNow;

  /// Free friends without a name (their choice, or mine — D-103).
  final int hiddenFree;
  final bool anonymous;
  final List<(RealProfile, RealAvailability)> free;

  /// Free, but in a call right now: shown after the free ones.
  final List<(RealProfile, RealAvailability)> busy;
  final DateTime now;
  final bool meFree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final total = free.length + hiddenFree;
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
              if (total > 0) MomentChip(text: l.realFreeCount(total)),
            ],
          ),
          const SizedBox(height: 16),
          if (free.isEmpty && busy.isEmpty && notNow.isEmpty && hiddenFree == 0)
            Text(
              meFree ? l.realNobodyFreeYet : l.realNobodyFree,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
            )
          else if (free.isNotEmpty || busy.isNotEmpty || notNow.isNotEmpty)
            SizedBox(
              height: 138,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: free.length + busy.length + notNow.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final faded = i >= free.length + busy.length;
                  final inCall = !faded && i >= free.length;
                  final (p, a) = faded
                      ? notNow[i - free.length - busy.length]
                      : inCall
                      ? busy[i - free.length]
                      : free[i];
                  return SizedBox(
                    width: 76,
                    child: Opacity(
                      opacity: faded ? 0.45 : 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        // Tap a free friend: ask them now.
                        onTap: inCall
                            ? null
                            : faded
                            ? () => _notNowNote(context, ref, p)
                            : () => askFreeFriend(context, ref, p),
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
                            // Smaller rather than cut ("עוד 60 דק׳").
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: StatusLine(
                                icon: inCall
                                    ? Icons.call_rounded
                                    : modeIcon(a.mode),
                                // The picture says how (car, coffee…); the text
                                // just how long.
                                text: inCall
                                    ? l.inCall
                                    : faded
                                    ? l.freeNotNow
                                    : timeLeftLabel(l, a, now),
                                color: inCall
                                    ? AppColors.coralDeep
                                    : AppColors.inkSoft,
                                bold: inCall,
                                size: 12,
                                center: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (hiddenFree > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l.hiddenFreeLine(hiddenFree),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          if (anonymous && total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.anonymousSeeNote,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
              ),
            ),
          // Their faces can be tapped: say so.
          if (free.isNotEmpty)
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
                // Large phone text: smaller rather than cut.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                        timeLeftLabel(l, mine, now),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Friends free that I can ask: say I may tap them. Nobody free: the
        // card above already says so — nothing more here.
        if (askableFriends(ref.watch(realProvider), now).isNotEmpty) ...[
          Text(
            l.realTapOrWait,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            // A trip ends by itself: nothing to extend.
            if (!mine.auto)
              OutlinedButton.icon(
                onPressed: () => _extend(context, ref),
                icon: const Icon(Icons.more_time_rounded),
                label: Text(l.extendButton),
              ),
            OutlinedButton.icon(
              onPressed: c.stopAvailability,
              icon: const Icon(Icons.stop_rounded),
              label: Text(l.stopAvailability),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _extend(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  // Read before the sheet: this card may be gone when it closes.
  final c = ref.read(realProvider.notifier);
  final minutes = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (d) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.extendTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final m in const [10, 20, 30, 60]) ...[
                  Expanded(
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => Navigator.pop(d, m),
                      // One line, smaller if needed (never "+1\n0").
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l.extendBy(m), maxLines: 1),
                      ),
                    ),
                  ),
                  if (m != 60) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (minutes != null) await c.extendAvailability(minutes);
}

/// Free friends I can ask, people I haven't talked with in a while first.
List<(RealProfile, RealAvailability)> friendsToShow(RealState s, DateTime now) {
  final last = s.snapshot?.lastTalk ?? const <String, DateTime>{};
  return [...askableFriends(s, now)]..sort((a, b) {
    final ta = last[a.$1.id];
    final tb = last[b.$1.id];
    if (ta == null) return tb == null ? 0 : -1;
    if (tb == null) return 1;
    return ta.compareTo(tb);
  });
}

/// "15 more min" — or, on an automatic trip (its end isn't known), just
/// what it is.
String timeLeftLabel(AppLocalizations l, RealAvailability a, DateTime now) =>
    a.auto ? modeLabel(l, a.mode) : l.timeLeftMinutes(a.minutesLeftAt(now));

/// Tap a free friend: "talk with X now?" → they're asked (my tap is my
/// yes). If I'm not free yet, I'm marked free for 30 minutes first.
Future<void> askFreeFriend(
  BuildContext context,
  WidgetRef ref,
  RealProfile friend,
) async {
  final l = context.l10n;
  // Read before the dialog: the card that opened it may be gone after.
  final c = ref.read(realProvider.notifier);
  final meFree =
      myActiveAvailability(ref.read(realProvider), ref.read(realNowProvider)) !=
      null;
  final go = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l.askTitle(friend.name)),
      content: Text(meFree ? l.askBody : l.askBodyNotFree),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(l.askYes),
        ),
      ],
    ),
  );
  if (go != true) return;
  if (!meFree && !await c.startAvailability(AvailabilityMode.free, 30)) {
    return;
  }
  await c.askFriend(friend);
}

/// A free friend who can't be asked right now: say so gently, never why
/// (it may be their own choice).
/// If it's because of me (they added me and I haven't kept them yet),
/// I can undo it right there.
Future<void> _notNowNote(BuildContext context, WidgetRef ref, RealProfile p) {
  final l = context.l10n;
  final c = ref.read(realProvider.notifier);
  final mine =
      ref.read(realProvider).snapshot?.status.pending.contains(p.id) ?? false;
  return showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l.freeNotNowTitle(p.name)),
      content: Text(mine ? l.freeNotNowMine(p.name) : l.freeNotNowBody),
      actions: [
        if (mine) ...[
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l.close)),
          FilledButton(
            onPressed: () {
              Navigator.pop(d);
              c.approveFriend(p);
            },
            child: Text(l.pendingKeep),
          ),
        ] else
          FilledButton(onPressed: () => Navigator.pop(d), child: Text(l.close)),
      ],
    ),
  );
}

/// I didn't answer a question: no more questions (and friends see me as
/// not free) until I say so.
class _MissedCard extends ConsumerWidget {
  const _MissedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final busy = ref.watch(realProvider.select((s) => s.busy));
    return Card(
      color: AppColors.blush,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.missedTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(l.missedBody),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : c.stillFree,
                    child: Text(l.missedYes),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: busy ? null : c.stopAvailability,
                  child: Text(l.missedNo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Trips in a row with no answer: keep automatic detection? (Only here.)
class _AutoMissedCard extends ConsumerWidget {
  const _AutoMissedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final busy = ref.watch(realProvider.select((s) => s.busy));
    return Card(
      color: AppColors.blush,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.autoMissedTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(l.autoMissedBody),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => c.keepAuto(keep: true),
                    child: Text(l.autoMissedKeep),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: busy ? null : () => c.keepAuto(keep: false),
                  child: Text(l.autoMissedOff),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Someone added me from their contacts, but I don't have their number:
/// they don't see when I'm free until I keep them.
class _PendingFriendCard extends ConsumerWidget {
  const _PendingFriendCard({required this.friend});
  final RealProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final busy = ref.watch(realProvider.select((s) => s.busy));
    return Card(
      color: AppColors.mint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RealAvatar(person: friend.toPerson(), size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.pendingTitle(friend.name),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l.pendingBody(friend.name)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => c.approveFriend(friend),
                    child: Text(l.pendingKeep),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          c.dismissNewFriend(friend);
                          await c.unmatch(friend);
                        },
                  child: Text(l.pendingRemove),
                ),
              ],
            ),
          ],
        ),
      ),
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
                  BackendConfig.store ? l.updateHowStore : l.updateHow,
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
        // The app's usual switch colors (same as in Settings).
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
    // A question went unanswered: two big buttons, nothing else.
    if (mine != null && mine.missed) {
      return MomentLayout(
        style: MomentStyle.dark,
        footer: l.driverSafety,
        top: Column(
          children: [
            MomentText(l.missedTitle, size: 30, style: MomentStyle.dark),
          ],
        ),
        actions: [
          PrimaryPill(
            label: l.missedYes,
            style: MomentStyle.dark,
            height: 110,
            onTap: s.busy ? null : c.stillFree,
          ),
          SecondaryPill(
            label: l.missedNo,
            style: MomentStyle.dark,
            height: 88,
            onTap: c.stopAvailability,
          ),
        ],
      );
    }
    // The first minutes of an automatic trip: no questions yet.
    if (mine != null && mine.quietAt(now)) {
      return MomentLayout(
        style: MomentStyle.dark,
        footer: l.driverSafety,
        top: Column(
          children: [
            const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 24),
            MomentText(l.graceTitle, size: 30, style: MomentStyle.dark),
            const SizedBox(height: 8),
            MomentText(
              l.graceBody,
              size: 20,
              style: MomentStyle.dark,
              soft: true,
            ),
          ],
        ),
        actions: [
          PrimaryPill(
            label: l.graceReady,
            style: MomentStyle.dark,
            height: 110,
            onTap: s.busy ? null : c.readyNow,
          ),
          SecondaryPill(
            label: l.graceNotThisTrip,
            style: MomentStyle.dark,
            height: 88,
            onTap: c.stopAvailability,
          ),
        ],
      );
    }
    final free = friendsToShow(s, now);
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
          if (free.isEmpty) ...[
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
            MomentText(l.driverNobody, size: 30, style: MomentStyle.dark),
            const SizedBox(height: 6),
            MomentText(
              l.driverNobodyBody,
              size: 18,
              style: MomentStyle.dark,
              soft: true,
            ),
          ] else ...[
            // Who's free now: up to 3 big circles, one tap asks (D-107).
            MomentText(l.driverFreeTitle, size: 28, style: MomentStyle.dark),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (p, a) in free.take(3))
                  Expanded(
                    child: _DriverFriend(
                      friend: p,
                      label: modeLabel(l, a.mode),
                      onTap: s.busy ? null : () => c.askFriend(p),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            MomentText(
              l.driverFreeHint,
              size: 18,
              style: MomentStyle.dark,
              soft: true,
            ),
          ],
          if (mine != null && !mine.auto) ...[
            const SizedBox(height: 6),
            // Mine, clearly (not a friend's time).
            MomentText(
              l.driverMyTimeLeft(mine.minutesLeftAt(now)),
              size: 20,
              style: MomentStyle.dark,
              soft: true,
            ),
          ],
        ],
      ),
      actions: [
        SecondaryPill(
          // Same words as on the regular screen.
          label: l.stopAvailability,
          style: MomentStyle.dark,
          height: 96,
          onTap: c.stopAvailability,
        ),
        // A look at the regular screen (back with one tap from there).
        TextButton(
          onPressed: () => c.showNormalView(true),
          child: Text(
            l.driverNormalView,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// One free friend on the driver screen: a big picture, name, what
/// they're doing. The whole thing is one big button.
class _DriverFriend extends StatelessWidget {
  const _DriverFriend({
    required this.friend,
    required this.label,
    required this.onTap,
  });
  final RealProfile friend;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            HeroAvatar(
              person: friend.toPerson(),
              size: 88,
              ring: AppColors.driverRing,
            ),
            const SizedBox(height: 10),
            Text(
              friend.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
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

/// No number yet: friends can't find me in their contacts, nobody can
/// call me. One tap to add it (or "not now" for a week).
class _AddNumberCard extends ConsumerWidget {
  const _AddNumberCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    return Card(
      color: AppColors.blush,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_rounded, color: AppColors.coralDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.addNumberTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l.addNumberBody),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => editMyPhone(context, ref),
                    child: Text(l.addNumberGo),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: c.addNumberLater,
                  child: Text(l.realNotNow),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Someone joined my list without me adding them here (they found me in
/// their contacts, or used my invitation): say so once, and offer a group
/// (which decides when they see me free).
class _NewFriendCard extends ConsumerWidget {
  const _NewFriendCard({required this.friend});
  final RealProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    return Card(
      color: AppColors.mint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RealAvatar(person: friend.toPerson(), size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.newFriendTitle(friend.name),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l.newFriendBody),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: FriendCirclesPicker(friend: friend),
                          ),
                        ),
                      );
                      c.dismissNewFriend(friend);
                    },
                    child: Text(l.newFriendGroup),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => c.dismissNewFriend(friend),
                  child: Text(l.newFriendOk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
