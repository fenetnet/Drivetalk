import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'safety_actions.dart';

/// One suggested person + why they were suggested.
/// Actions: talk now / next / not today / don't suggest for a while.
class SuggestionView extends ConsumerWidget {
  const SuggestionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final session = ref.watch(sessionProvider);
    final s = session.suggestion;
    if (s == null) return const SizedBox.shrink();
    final controller = ref.read(sessionProvider.notifier);
    final person = s.person;
    final mine = ref.watch(availabilityServiceProvider).mine;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (mine != null)
                Pill(
                  icon: modeIcon(mine.mode),
                  text: mine.untilTripEnds
                      ? l.durationUntilTripEnds
                      : l.timeLeftMinutes(mine.minutesLeftAt(now)),
                  color: const Color(0xFFDCEBE3),
                  textColor: AppColors.sageDark,
                ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: l.more,
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (v) {
                  if (v == 'block') confirmBlock(context, ref, person);
                  if (v == 'report') showReportSheet(context, ref, person);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'block', child: Text(l.block)),
                  PopupMenuItem(value: 'report', child: Text(l.report)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  PersonAvatar(person: person, size: 112),
                  const SizedBox(height: 16),
                  Text(
                    person.name,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relationshipLine(
                      l,
                      connection: s.candidate.input.connection,
                      mutualFriends: s.candidate.input.mutualFriends,
                      sharedGroups: s.candidate.input.sharedGroups,
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      Pill(text: tierLabel(l, s.candidate.tier)),
                      if (s.isExploration)
                        Pill(
                          icon: Icons.auto_awesome_rounded,
                          text: l.explorationBadge,
                          color: const Color(0xFFFCEFD2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final r in s.candidate.reasons)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            reasonIcon(r),
                            size: 22,
                            color: AppColors.terracotta,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              reasonText(l, r, person),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sageDark,
              minimumSize: const Size.fromHeight(60),
            ),
            onPressed: controller.talkNow,
            icon: const Icon(Icons.call_rounded),
            label: Text(l.talkNow),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: controller.next,
            icon: const Icon(Icons.skip_next_rounded),
            label: Text(l.next),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: controller.notToday,
                  child: Text(l.notToday),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: controller.doNotSuggestForAWhile,
                  child: Text(l.doNotSuggest, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
