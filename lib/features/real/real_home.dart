import 'real_permissions.dart';

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
import 'real_about.dart';
import 'real_common.dart';
import 'real_free.dart';
import 'real_people.dart';

/// "I'm driving" / "I have time" on Home (D-156): one tap, 30 minutes, to
/// the groups chosen last time (the first time, one short note first).
Future<void> startFree(
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
  await c.quickStart(mode);
}

RealState s0(WidgetRef ref) => ref.read(realProvider);

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
        const _MissingPermissions(),
        const _MilestoneParty(),
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
                    // 🔥 my talks through the app (owner, D-159).
                    if (c.talkCount > 0)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Tooltip(
                          message: l.fireTooltip(c.talkCount),
                          triggerMode: TooltipTriggerMode.tap,
                          child: Container(
                            key: const ValueKey('fire'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1E0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '🔥 ${c.talkCount}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Mine on: the same gold ring friends see (owner, D-155).
                    if (me != null)
                      InstantRing(
                        on: snap?.autoYes ?? false,
                        child: RealAvatar(person: me.toPerson(), size: 42),
                      ),
                    // "About DriveBond": what's special, the permissions.
                    IconButton(
                      key: const ValueKey('about'),
                      tooltip: l.aboutTitle,
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.terracotta,
                        size: 30,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutScreen(),
                        ),
                      ),
                    ),
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
                if (s.cached) ...[
                  const SizedBox(height: 10),
                  MomentChip(text: l.homeUpdating, icon: Icons.sync_rounded),
                ],
                const _HealthLine(),
                if (c.showGoogleCard) ...[
                  const SizedBox(height: 12),
                  _GoogleCard(onClose: c.dismissGoogleCard),
                ],
                if (c.showWhatsNew) ...[
                  const SizedBox(height: 12),
                  _WhatsNewCard(onClose: c.dismissWhatsNew),
                ],
                if (_topCard(s, c) case final top?) ...[
                  const SizedBox(height: 12),
                  top,
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
                    me: me,
                    mine: mine,
                    hiddenFree: snap?.status.hiddenFree ?? 0,
                    anonymous: snap?.status.anonymous ?? false,
                  ),
                // Then: "I'm driving" / "I have time" — or me, free (D-156).
                const SizedBox(height: 20),
                if (mine == null)
                  StartButtons(onStart: (m) => startFree(context, ref, m))
                else ...[
                  MyFreeCard(mine: mine, now: now, gender: g),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _HowFriendsSeeMe(mine: mine, now: now),
                  ),
                ],
                // Until the first talk: the way there, in 3 steps (D-159).
                if (c.showJourney) ...[
                  const SizedBox(height: 16),
                  const _JourneyCard(),
                ],
                // The two automatic switches, together (owner).
                const SizedBox(height: 16),
                AutoCard(onAutoDriving: (v) => setAutoDriving(context, ref, v)),
                // At most ONE small card at a time (the most useful one).
                if (_tipCard(s, c, now, snap) case final tip?) ...[
                  const SizedBox(height: 16),
                  tip,
                ],
                const SizedBox(height: 24),
                if (snap != null && snap.friends.isNotEmpty) ...[
                  _WeekCard(week: snap.weekAt(now)),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// At the top of Home (owner, 1.1.2): a new version, or someone new — added
/// me, just became a friend, or joined from my contacts.
Widget? _topCard(RealState s, RealController c) {
  if (s.newBuild != null) return const _UpdateCard();
  // Someone added me from their contacts: keep them?
  if (c.pendingFriend case final f?) return _PendingFriendCard(friend: f);
  if (c.newFriend case final f?) return _NewFriendCard(friend: f);
  if (c.newContactMatch case final m?) return _NewContactCard(match: m);
  return null;
}

/// The one card under "Now": routine now > routine idea > the home-screen
/// button tip.
Widget? _tipCard(
  RealState s,
  RealController c,
  DateTime now,
  RealSnapshot? snap,
) {
  // "Still free?" after a question I didn't answer — only here, in the app.
  if (myActiveAvailability(s, now)?.missed ?? false) return const _MissedCard();
  if (s.driving.enabled && (snap?.status.autoMissed ?? 0) >= 2) {
    return const _AutoMissedCard();
  }
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
    this.me,
    this.mine,
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

  /// Me, first in the row while I'm free — like friends see me.
  final RealProfile? me;
  final RealAvailability? mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final total = free.length + hiddenFree;
    final self = me != null && mine != null ? (me!, mine!) : null;
    final shift = self == null ? 0 : 1;
    final others = free.length + busy.length + notNow.length;
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
          if (others + shift > 0)
            SizedBox(
              height: 138,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: others + shift,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (_, j) {
                  if (self != null && j == 0) {
                    return _MeFace(
                      me: self.$1,
                      mine: self.$2,
                      now: now,
                      autoYes:
                          ref.watch(realProvider).snapshot?.autoYes ?? false,
                    );
                  }
                  final i = j - shift;
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
                            InstantRing(
                              on:
                                  !inCall &&
                                  !faded &&
                                  (ref
                                          .watch(realProvider)
                                          .snapshot
                                          ?.instant
                                          .contains(p.id) ??
                                      false),
                              // Gold only, never green under it (owner).
                              child: RealAvatar(
                                person: p.toPerson(),
                                online: !inCall && !snapInstant(s0(ref), p.id),
                              ),
                            ),
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
          if (others == 0 && hiddenFree == 0)
            Text(
              meFree ? l.realNobodyFreeYet : l.realNobodyFree,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
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

/// Me in the row of free people: my picture, "me", and my time left.
class _MeFace extends StatelessWidget {
  const _MeFace({
    required this.me,
    required this.mine,
    required this.now,
    this.autoYes = false,
  });

  /// My "yes automatically" is on: the same gold ring friends see (owner).
  final bool autoYes;
  final RealProfile me;
  final RealAvailability mine;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      key: const ValueKey('me-free'),
      width: 76,
      child: Column(
        children: [
          InstantRing(
            on: autoYes,
            child: RealAvatar(person: me.toPerson(), online: !autoYes),
          ),
          const SizedBox(height: 8),
          Text(
            l.meInRow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: StatusLine(
              icon: modeIcon(mine.mode),
              text: timeLeftLabel(l, mine, now),
              color: AppColors.inkSoft,
              size: 12,
              center: true,
            ),
          ),
        ],
      ),
    );
  }
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
  await c.tapFriend(friend);
}

/// A free friend who can't be asked right now: say so gently, never why
/// (it may be their own choice).
/// If it's because of me (they added me and I haven't kept them yet),
/// I can undo it right there.
Future<void> _notNowNote(
  BuildContext context,
  WidgetRef ref,
  RealProfile p,
) async {
  final l = context.l10n;
  final c = ref.read(realProvider.notifier);
  final mine =
      ref.read(realProvider).snapshot?.status.pending.contains(p.id) ?? false;
  // Why, when it's about the two of us (D-142); otherwise the general
  // note — it may be their own choice.
  final why = mine ? null : await c.askWhy(p);
  if (!context.mounted) return;
  final body = switch (why) {
    _ when mine => l.freeNotNowMine(p.name),
    'call_open' => l.askCallOpen(p.name),
    'not_now' => l.askNotNow(p.name),
    _ => l.freeNotNowBody,
  };
  return showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l.freeNotNowTitle(p.name)),
      content: Text(body),
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

/// "Your first talk in 3 steps" (owner, D-159): add a friend, say I'm
/// free, talk. Shown until the first talk.
class _JourneyCard extends ConsumerWidget {
  const _JourneyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final friends = s.snapshot?.friends.isNotEmpty ?? false;
    Widget step(int n, String text, bool done) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.terracotta : Colors.transparent,
              border: Border.all(color: AppColors.terracotta, width: 2),
            ),
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    '$n',
                    style: const TextStyle(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: done ? AppColors.inkSoft : null,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
    return Card(
      key: const ValueKey('journey'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.journeyTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            step(1, l.journeyStep1, friends),
            step(2, l.journeyStep2, c.wasFree),
            step(3, l.journeyStep3, false),
            if (!friends) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => shareInvite(context, ref),
                icon: const Icon(Icons.share_rounded),
                label: Text(l.realInviteFriend),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The first talk, then 5 / 10 / 25 / 50 / 100: a small party, once each
/// (owner, D-159). After the first: an offer to turn auto-yes on.
class _MilestoneParty extends ConsumerStatefulWidget {
  const _MilestoneParty();

  @override
  ConsumerState<_MilestoneParty> createState() => _MilestonePartyState();
}

class _MilestonePartyState extends ConsumerState<_MilestoneParty> {
  var _showing = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(realProvider.select((s) => s.snapshot?.talks.length));
    final due = ref.read(realProvider.notifier).milestoneDue;
    if (due != null && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _party(due));
    }
    return const SizedBox.shrink();
  }

  Future<void> _party(int n) async {
    if (!mounted) return;
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    c.milestoneSeen(n);
    final first = n == 1;
    final stars = ref.read(realProvider).snapshot?.autoYesMin ?? 3;
    final offerAuto =
        first && !(ref.read(realProvider).snapshot?.autoYes ?? true);
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: Text(first ? '🎉' : '🔥', style: const TextStyle(fontSize: 56)),
        title: Text(
          first ? l.milestoneFirstTitle : l.milestoneTitle(n),
          textAlign: TextAlign.center,
        ),
        content: Text(
          first
              ? (c.autoYesWasLocked
                    ? l.milestoneUnlockedBody(stars)
                    : l.milestoneFirstBody(stars))
              : l.milestoneBody(n),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          if (offerAuto) ...[
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(l.milestoneFirstGo),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(l.firstRunLater),
            ),
          ] else
            FilledButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(l.milestoneOk),
            ),
        ],
      ),
    );
    if (go == true) await c.setAutoYes(on: true);
    if (mounted) setState(() => _showing = false);
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

/// "Friends see: free · driving · 20 more min" — or, in a call, that they
/// see me in a call and no questions come meanwhile.
class _HowFriendsSeeMe extends ConsumerWidget {
  const _HowFriendsSeeMe({required this.mine, required this.now});
  final RealAvailability mine;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hide = ref.watch(realProvider).snapshot?.status.hideInCall ?? false;
    final inCall = mine.inCallAt(now);
    final text = !inCall
        ? l.friendsSeeMeFree(
            modeLabel(l, mine.mode),
            timeLeftLabel(l, mine, now),
          )
        : hide
        ? l.friendsSeeMeHidden
        : l.friendsSeeMeInCall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          inCall ? Icons.phone_in_talk_rounded : Icons.visibility_rounded,
          size: 18,
          color: AppColors.inkSoft,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// An update needs a new phone permission and it's missing: the list with
/// "allow all", once (D-136). Not on every update.
class _MissingPermissions extends ConsumerStatefulWidget {
  const _MissingPermissions();

  @override
  ConsumerState<_MissingPermissions> createState() =>
      _MissingPermissionsState();
}

class _MissingPermissionsState extends ConsumerState<_MissingPermissions> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final c = ref.read(realProvider.notifier);
    if (!await c.shouldAskMissingPermissions() || !mounted) return;
    await navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (r) => Scaffold(
          body: SafeArea(
            child: PermissionsStep(onDone: () => Navigator.of(r).pop()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "Is everything OK?": a phone setting that stops DriveBond from working
/// (notifications, running in the background, calls, the microphone) —
/// one line with a fix, until it's fixed or hidden for a week (owner).
class _HealthLine extends ConsumerStatefulWidget {
  const _HealthLine();

  @override
  ConsumerState<_HealthLine> createState() => _HealthLineState();
}

class _HealthLineState extends ConsumerState<_HealthLine> {
  PhonePermission? _missing;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final c = ref.read(realProvider.notifier);
    final m = await c.healthIssue();
    if (mounted && m != _missing) setState(() => _missing = m);
  }

  @override
  Widget build(BuildContext context) {
    final m = _missing;
    if (m == null) return const SizedBox.shrink();
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final what = switch (m) {
      PhonePermission.notifications => l.permsNotifTitle,
      PhonePermission.calls => l.permsCallTitle,
      PhonePermission.mic => l.permsMicTitle,
      PhonePermission.background => l.permsBgTitle,
      PhonePermission.fullScreen => l.permsFullTitle,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: AppColors.terracotta.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 6),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.terracotta,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.healthMissing(what),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await c.askPermission(m);
                  await _check();
                },
                child: Text(l.healthFix),
              ),
              IconButton(
                tooltip: l.close,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  c.hideHealthIssue(m);
                  setState(() => _missing = null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "What's new" once after an update (owner): three short lines.
class _WhatsNewCard extends StatelessWidget {
  const _WhatsNewCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      key: const ValueKey('whatsNew'),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.whatsNewTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
              ],
            ),
            Text(l.whatsNewBody, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// Once, on Home: keep the account with Google (owner: no lost friends on
/// a new phone).
class _GoogleCard extends ConsumerWidget {
  const _GoogleCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Card(
      key: const ValueKey('googleCard'),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_rounded, color: AppColors.terracotta),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.googleCardTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Text(
                l.googleCardBody,
                style: const TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: GoogleButton(
                label: l.googleCardAction,
                onTap: () => connectGoogleFlow(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// They'd say yes to me at once (D-153).
bool snapInstant(RealState s, String id) =>
    s.snapshot?.instant.contains(id) ?? false;
