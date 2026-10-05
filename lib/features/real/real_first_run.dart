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

    return switch (s.firstRun) {
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
