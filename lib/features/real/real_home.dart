import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../availability/pick_mode_screen.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'real_common.dart';
import 'real_people.dart';

void openRealAvailabilityPicker(WidgetRef ref) {
  final circles = ref.read(realProvider).snapshot?.circles ?? const [];
  navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => PickModeScreen(
        realCircles: [for (final c in circles) (c.id, c.name)],
        onStart: (mode, minutes, circleId) => ref
            .read(realProvider.notifier)
            .startAvailability(mode, minutes, circleId: circleId),
      ),
    ),
  );
}

/// Home in real mode: one big "I'm free now", or my status + who's free.
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
    final free = freeFriends(s, now);
    final g = genderKey(me?.gender ?? Gender.unspecified);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: c.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    me == null ? l.homeGreetingNoName : l.homeGreeting(me.name),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Pill(
                  icon: Icons.verified_rounded,
                  text: l.realBadge,
                  color: const Color(0xFFDCEBE3),
                  textColor: AppColors.sageDark,
                ),
              ],
            ),
            if (s.lastError == 'offline') ...[
              const SizedBox(height: 8),
              Text(
                l.realErrorOffline,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            if (mine == null)
              SizedBox(
                height: 120,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: s.busy
                      ? null
                      : () => openRealAvailabilityPicker(ref),
                  icon: const Icon(Icons.record_voice_over_rounded, size: 36),
                  label: Text(l.homeImFreeNow(g)),
                ),
              )
            else
              _MyStatusCard(mine: mine, now: now, gender: g),
            const SizedBox(height: 24),
            if (snap != null && snap.friends.isEmpty)
              const _NoFriendsCard()
            else ...[
              Text(
                l.realFreeFriendsTitle,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (free.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l.realNobodyFree,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                )
              else
                for (final (p, a) in free.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: PersonAvatar(person: p.toPerson(), size: 44),
                    title: Text(p.name),
                    subtitle: Text(
                      '${modeLabel(l, a.mode)} · '
                      '${l.timeLeftMinutes(a.minutesLeftAt(now))}',
                    ),
                    trailing: Icon(modeIcon(a.mode), color: AppColors.sage),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MyStatusCard extends ConsumerWidget {
  const _MyStatusCard({
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
    return Card(
      color: const Color(0xFFDCEBE3),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(modeIcon(mine.mode), color: AppColors.sageDark, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.realMeAvailableTitle(gender),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  l.timeLeftMinutes(mine.minutesLeftAt(now)),
                  style: const TextStyle(color: AppColors.sageDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.realWaitingForFriends,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: c.stopAvailability,
              icon: const Icon(Icons.stop_rounded),
              label: Text(l.stopAvailability),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFriendsCard extends ConsumerWidget {
  const _NoFriendsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.group_add_rounded,
              size: 48,
              color: AppColors.terracotta,
            ),
            const SizedBox(height: 10),
            Text(
              l.realNoFriendsTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              l.realNoFriendsBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => shareInvite(context, ref),
              icon: const Icon(Icons.share_rounded),
              label: Text(l.realInviteFriend),
            ),
            TextButton(
              onPressed: () => openInviteCodeSheet(context, ref),
              child: Text(l.realHaveCode),
            ),
          ],
        ),
      ),
    );
  }
}

/// Driving, nothing happening: huge stop button, nothing to read.
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
      dark: true,
      footer: l.driverSafety,
      top: Column(
        children: [
          const PulsingCircle(
            size: 120,
            child: Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          MomentText(l.driverSearching, size: 30, dark: true),
          if (mine != null)
            MomentText(
              l.timeLeftMinutes(mine.minutesLeftAt(now)),
              size: 20,
              dark: true,
              soft: true,
            ),
        ],
      ),
      actions: [
        BigActionButton(
          label: l.driverStop,
          icon: Icons.stop_rounded,
          color: AppColors.driverCard,
          onTap: c.stopAvailability,
        ),
      ],
    );
  }
}
