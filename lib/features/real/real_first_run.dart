import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../real/real_controller.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'real_common.dart';
import 'real_people.dart';

/// Right after joining: get to at least one person DriveTalk can work with,
/// then explain the idea in one sentence. Never a social-network screen.
class RealFirstRunScreen extends ConsumerWidget {
  const RealFirstRunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final friends = s.snapshot?.friends ?? const [];

    Widget icon(IconData i) => Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: AppColors.terracotta,
        shape: BoxShape.circle,
      ),
      child: Icon(i, color: Colors.white, size: 60),
    );

    Widget texts(String title, String body) => Column(
      children: [
        MomentText(title, size: 28),
        const SizedBox(height: 12),
        MomentText(body, size: 16, soft: true),
      ],
    );

    final me = s.snapshot?.me;
    return switch (s.firstRun) {
      // A picture, so friends recognize me. Optional; one sentence says
      // where to add it later.
      FirstRunStep.photo => MomentLayout(
        top: Column(
          children: [
            GestureDetector(
              onTap: me == null || s.busy
                  ? null
                  : () => _pickPhoto(context, ref, me.photoVersion > 0),
              child: (me?.photoVersion ?? 0) > 0
                  ? PersonAvatar(person: me!.toPerson(), size: 120)
                  : icon(Icons.add_a_photo_rounded),
            ),
            const SizedBox(height: 32),
            texts(l.firstRunPhotoTitle, l.firstRunPhotoBody),
            const SizedBox(height: 16),
            MomentText(l.firstRunPhotoLater, size: 14, soft: true),
          ],
        ),
        actions: [
          if ((me?.photoVersion ?? 0) > 0)
            PrimaryPill(label: l.next, onTap: c.firstRunNext)
          else
            PrimaryPill(
              label: l.firstRunPhotoGo,
              icon: Icons.photo_camera_rounded,
              onTap: me == null || s.busy
                  ? null
                  : () => _pickPhoto(context, ref, false),
            ),
          if (me?.photo == null)
            SecondaryPill(label: l.firstRunLater, onTap: c.firstRunNext),
        ],
      ),
      FirstRunStep.contacts => MomentLayout(
        top: Column(
          children: [
            icon(Icons.contacts_rounded),
            const SizedBox(height: 32),
            texts(l.firstRunContactsTitle, l.firstRunContactsBody),
          ],
        ),
        actions: [
          PrimaryPill(
            label: l.firstRunContactsGo,
            icon: Icons.search_rounded,
            onTap: s.busy ? null : c.firstRunFindPeople,
          ),
          SecondaryPill(label: l.skip, onTap: c.firstRunNext),
        ],
      ),
      FirstRunStep.result when c.contactMatches.isNotEmpty => MomentLayout(
        top: Column(
          children: [
            MomentText(l.contactsPickTitle, size: 28),
            const SizedBox(height: 8),
            MomentText(l.contactsPickBody, size: 16, soft: true),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ContactPickList(),
              ),
            ),
          ],
        ),
        actions: [PrimaryPill(label: l.next, onTap: c.firstRunNext)],
      ),
      FirstRunStep.result when friends.isNotEmpty => MomentLayout(
        top: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final f in friends.take(6))
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PersonAvatar(person: f.toPerson(), size: 64),
                      const SizedBox(height: 6),
                      Text(f.name, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 28),
            MomentText(l.firstRunFound(friends.length), size: 28),
          ],
        ),
        actions: [PrimaryPill(label: l.next, onTap: c.firstRunNext)],
      ),
      FirstRunStep.result => MomentLayout(
        top: Column(
          children: [
            icon(Icons.person_add_alt_1_rounded),
            const SizedBox(height: 32),
            texts(l.firstRunNoneTitle, l.firstRunNoneBody),
          ],
        ),
        actions: [
          PrimaryPill(
            label: l.realInviteFriend,
            icon: Icons.share_rounded,
            onTap: () => shareInvite(context, ref),
          ),
          SecondaryPill(label: l.firstRunLater, onTap: c.firstRunNext),
        ],
      ),
      FirstRunStep.routine => const _RoutineStep(),
      _ => MomentLayout(
        style: MomentStyle.green,
        top: Column(
          children: [
            icon(Icons.call_rounded),
            const SizedBox(height: 32),
            texts(l.firstRunMagicTitle, l.firstRunMagicBody),
          ],
        ),
        actions: [
          PrimaryPill(
            label: l.firstRunMagicGo,
            style: MomentStyle.green,
            onTap: c.firstRunNext,
          ),
        ],
      ),
    };
  }
}

/// "When are you usually on the road?" — morning / evening / not fixed.
class _RoutineStep extends ConsumerStatefulWidget {
  const _RoutineStep();

  @override
  ConsumerState<_RoutineStep> createState() => _RoutineStepState();
}

class _RoutineStepState extends ConsumerState<_RoutineStep> {
  var _morning = false;
  var _evening = false;
  var _morningAt = const TimeOfDay(hour: 7, minute: 30);
  var _eveningAt = const TimeOfDay(hour: 17, minute: 0);

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<TimeOfDay?> _pick(TimeOfDay initial) => showTimePicker(
    context: context,
    initialTime: initial,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final busy = ref.watch(realProvider.select((s) => s.busy));
    Widget option({
      required String label,
      required bool on,
      required VoidCallback toggle,
      required VoidCallback changeTime,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: FilterChip(
              label: SizedBox(
                width: double.infinity,
                child: Text(label, style: const TextStyle(fontSize: 17)),
              ),
              selected: on,
              onSelected: (_) => toggle(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
          ),
          IconButton(
            tooltip: l.firstRunRoutineChangeTime,
            icon: const Icon(Icons.edit_calendar_rounded),
            onPressed: changeTime,
          ),
        ],
      ),
    );
    return MomentLayout(
      top: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.terracotta,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 28),
          MomentText(l.firstRunRoutineTitle, size: 28),
          const SizedBox(height: 10),
          MomentText(l.firstRunRoutineBody, size: 16, soft: true),
          const SizedBox(height: 20),
          option(
            label: l.firstRunRoutineMorning(_hhmm(_morningAt)),
            on: _morning,
            toggle: () => setState(() => _morning = !_morning),
            changeTime: () async {
              final t = await _pick(_morningAt);
              if (t != null) {
                setState(() {
                  _morningAt = t;
                  _morning = true;
                });
              }
            },
          ),
          option(
            label: l.firstRunRoutineEvening(_hhmm(_eveningAt)),
            on: _evening,
            toggle: () => setState(() => _evening = !_evening),
            changeTime: () async {
              final t = await _pick(_eveningAt);
              if (t != null) {
                setState(() {
                  _eveningAt = t;
                  _evening = true;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        PrimaryPill(
          label: l.next,
          onTap: busy || (!_morning && !_evening)
              ? null
              : () => c.firstRunRoutines(
                  morning: _morning
                      ? _morningAt.hour * 60 + _morningAt.minute
                      : null,
                  evening: _evening
                      ? _eveningAt.hour * 60 + _eveningAt.minute
                      : null,
                ),
        ),
        SecondaryPill(label: l.firstRunRoutineNone, onTap: c.firstRunNext),
      ],
    );
  }
}

/// Pick my picture; once saved, go on to the next step.
Future<void> _pickPhoto(
  BuildContext context,
  WidgetRef ref,
  bool hasPhoto,
) async {
  if (await editMyPhoto(context, ref, hasPhoto: hasPhoto)) {
    ref.read(realProvider.notifier).firstRunNext();
  }
}
