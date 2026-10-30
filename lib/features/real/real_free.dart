import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/models.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import 'real_common.dart';

/// Simple Home (owner, D-156): "I'm driving" / "I have time" — one tap, 30
/// minutes; the time ("until when") and who sees it ("available to") can
/// be changed after. No separate driver screen.

/// "I'm driving" (big) and "I have time" (small), then who sees it.
class StartButtons extends ConsumerWidget {
  const StartButtons({super.key, required this.onStart});

  /// Starts (asks for the first-time permission note when needed).
  final Future<void> Function(AvailabilityMode mode) onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final busy = ref.watch(realProvider.select((s) => s.busy));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 96,
                child: FilledButton(
                  key: const ValueKey('startDriving'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.terracotta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0x661565C0),
                  ),
                  onPressed: busy
                      ? null
                      : () => onStart(AvailabilityMode.driving),
                  // Large phone text: smaller rather than cut.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_car_rounded, size: 34),
                        const SizedBox(height: 4),
                        Text(
                          l.startDriving,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 96,
                child: OutlinedButton(
                  key: const ValueKey('startFree'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.sageDark,
                    side: const BorderSide(color: AppColors.sage, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: busy ? null : () => onStart(AvailabilityMode.free),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_cafe_rounded, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          l.startFree,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l.startHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
        ),
        const SizedBox(height: 10),
        const Center(child: AudienceChip()),
      ],
    );
  }
}

/// "Available to: everyone ▾" — tap to choose groups.
class AudienceChip extends ConsumerWidget {
  const AudienceChip({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.watch(realProvider);
    final text = l.audienceLabel(audienceText(l, ref));
    return InkWell(
      key: const ValueKey('audience'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => openAudienceSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: 0.16) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: onDark ? null : Border.all(color: const Color(0xFFDCE3EE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: onDark ? Colors.white : AppColors.ink,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: onDark ? Colors.white : AppColors.terracotta,
            ),
          ],
        ),
      ),
    );
  }
}

/// "everyone", "family, close friends", "everyone except work".
String audienceText(AppLocalizations l, WidgetRef ref) {
  final c = ref.read(realProvider.notifier);
  final circles = ref.read(realProvider).snapshot?.circles ?? const [];
  final a = c.audience;
  final names = [
    for (final id in a.ids)
      if (circles.where((x) => x.id == id).firstOrNull case final x?) x.name,
  ];
  if (names.isEmpty) return l.audienceAll;
  return a.except ? l.audienceAllBut(names.join(', ')) : names.join(', ');
}

/// "Who sees I'm free?": only the groups I tick — or everyone but them.
Future<void> openAudienceSheet(BuildContext context, WidgetRef ref) async {
  final c = ref.read(realProvider.notifier);
  final circles = [...?ref.read(realProvider).snapshot?.circles];
  final start = c.audience;
  final picked = {...start.ids};
  var except = start.except;
  final save = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final l = AppLocalizations.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.audienceTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.audienceOnlyTab)),
                    ButtonSegment(
                      value: true,
                      label: Text(l.audienceExceptTab),
                    ),
                  ],
                  selected: {except},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => except = v.first),
                ),
                const SizedBox(height: 10),
                Text(
                  except ? l.audienceExceptNote : l.audienceOnlyNote,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 4),
                if (circles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(l.audienceNoGroups),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final g in circles)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: picked.contains(g.id),
                            title: Text(
                              g.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              l.audienceMembers(g.memberIds.length),
                            ),
                            onChanged: (v) => setState(
                              () => v == true
                                  ? picked.add(g.id)
                                  : picked.remove(g.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                PrimaryPill(
                  label: l.save,
                  onTap: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (save ?? false) {
    await c.setAudienceChoice([
      for (final g in circles)
        if (picked.contains(g.id)) g.id,
    ], except: except);
  }
}

/// "For how long?": 15 minutes … 3 hours, or until a time of day.
Future<void> openTimeSheet(
  BuildContext context,
  WidgetRef ref,
  RealAvailability mine,
) async {
  final c = ref.read(realProvider.notifier);
  final now = ref.read(realNowProvider);
  final cap = mine.startedAt.add(const Duration(hours: 3));
  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    // Small phones / large text: the whole list scrolls (review D-164).
    isScrollControlled: true,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      final options = [
        (15, l.time15),
        (30, l.time30),
        (45, l.time45),
        (60, l.time60),
        (90, l.time90),
        (120, l.time120),
        (180, l.time180),
      ];
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.timeTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (m, label) in options)
                    if (!now
                        .add(Duration(minutes: m))
                        .isAfter(cap.add(const Duration(minutes: 1))))
                      ChoiceChip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 16),
                        ),
                        selected: (mine.minutesLeftAt(now) - m).abs() < 3,
                        onSelected: (_) =>
                            Navigator.pop(ctx, now.add(Duration(minutes: m))),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(l.timeUntil),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(mine.expiresAt),
                  );
                  if (t == null || !ctx.mounted) return;
                  var at = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    t.hour,
                    t.minute,
                  );
                  if (at.isBefore(now)) at = at.add(const Duration(days: 1));
                  Navigator.pop(ctx, at);
                },
              ),
              Text(
                l.timeMaxNote,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const AudienceChip(),
            ],
          ),
        ),
      );
    },
  );
  if (picked != null) await c.setUntil(picked);
}

/// I'm free: "you're driving" / "you have time", the time (tap to change),
/// who sees it, and "end".
class MyFreeCard extends ConsumerWidget {
  const MyFreeCard({
    super.key,
    required this.mine,
    required this.now,
    required this.gender,
  });
  final RealAvailability mine;
  final DateTime now;
  final String gender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = ref.read(realProvider.notifier);
    final driving = mine.mode == AvailabilityMode.driving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('myFree'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.sageDark,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x552F6B57),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    driving
                        ? Icons.directions_car_rounded
                        : Icons.local_cafe_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      driving
                          ? l.meDrivingTitle(gender)
                          : l.meFreeTitle(gender),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (mine.auto)
                    Flexible(
                      child: Text(
                        l.autoTripEnds,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: InkWell(
                          key: const ValueKey('timeLeft'),
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => openTimeSheet(context, ref, mine),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l.timeLeftEdit(mine.minutesLeftAt(now)),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: AudienceChip(onDark: true),
              ),
              // The first minutes of an automatic trip: no questions yet —
              // ready now, or not this trip.
              if (mine.quietAt(now)) ...[
                const SizedBox(height: 12),
                Text(
                  '${l.graceTitle}. ${l.graceBody}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.sageDark,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: c.readyNow,
                        child: Text(l.graceReady),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: c.stopAvailability,
                        child: Text(l.graceNotThisTrip),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: OutlinedButton.icon(
            onPressed: c.stopAvailability,
            icon: const Icon(Icons.stop_rounded),
            label: Text(l.endFree),
          ),
        ),
      ],
    );
  }
}

/// The two automatic switches, together (owner): first "free automatically
/// while driving", then "yes automatically while driving".
class AutoCard extends ConsumerWidget {
  const AutoCard({super.key, required this.onAutoDriving});

  /// Turns automatic availability on/off (with its one-time note).
  final void Function(bool on) onAutoDriving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final yes = s.snapshot?.autoYes ?? false;
    final locked = c.autoYesLocked && !yes;
    return Card(
      key: const ValueKey('autoCard'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: yes
            ? const BorderSide(color: instantGold, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          if (s.driving.supported)
            SwitchListTile(
              secondary: const Icon(
                Icons.directions_car_rounded,
                color: AppColors.terracotta,
              ),
              title: Text(
                l.realAutoDriving,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              value: s.driving.enabled,
              onChanged: s.busy ? null : onAutoDriving,
            ),
          SwitchListTile(
            key: const ValueKey('autoYes'),
            secondary: const Icon(Icons.bolt_rounded, color: instantGold),
            title: Text(
              l.autoYesTitle,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              locked
                  ? l.autoYesLockedBody
                  : yes
                  ? l.homeAutoYesOnBody(s.snapshot?.autoYesMin ?? 3)
                  : l.homeAutoYesOffBody,
            ),
            activeThumbColor: Colors.white,
            activeTrackColor: instantGold,
            value: yes,
            // New here: opens after the first talk (owner, D-161).
            onChanged: s.busy || s.snapshot == null || locked
                ? null
                : (v) => c.setAutoYes(on: v),
          ),
        ],
      ),
    );
  }
}
