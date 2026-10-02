import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/conversation_starters.dart';
import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../../matching/matching_engine.dart';
import '../../services/call_service.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'safety_actions.dart';

/// A few people to choose from (normal mode), each with why they're suggested.
class SuggestionView extends ConsumerWidget {
  const SuggestionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final session = ref.watch(sessionProvider);
    final controller = ref.read(sessionProvider.notifier);
    final mine = ref.watch(availabilityServiceProvider).mine;
    final options = session.options;
    if (options.isEmpty) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.optionsTitle(options.length),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (mine != null)
              Pill(
                icon: modeIcon(mine.mode),
                text: mine.untilTripEnds
                    ? l.durationUntilTripEnds
                    : l.timeLeftMinutes(mine.minutesLeftAt(now)),
                color: const Color(0xFFDCEBE3),
                textColor: AppColors.sageDark,
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final s in options) ...[
          _OptionCard(suggestion: s),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: controller.moreOptions,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l.moreOptions),
        ),
        TextButton(
          onPressed: controller.stopAvailability,
          child: Text(l.stopAvailability),
        ),
      ],
    );
  }
}

class _OptionCard extends ConsumerWidget {
  const _OptionCard({required this.suggestion});
  final Suggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = suggestion;
    final person = s.person;
    final controller = ref.read(sessionProvider.notifier);
    final me = ref.watch(profileServiceProvider).me;
    final starter = ref.watch(startersProvider).forPair(me, person);
    final viaPhone = controller.callMethodFor(person) == CallMethod.phone;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PersonAvatar(person: person, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        relationshipLine(
                          l,
                          connection: s.candidate.input.connection,
                          mutualFriends: s.candidate.input.mutualFriends,
                          sharedGroups: s.candidate.input.sharedGroups,
                        ),
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: l.more,
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) => switch (v) {
                    'today' => controller.notToday(s),
                    'while' => controller.doNotSuggestForAWhile(s),
                    'block' => confirmBlock(context, ref, person),
                    _ => showReportSheet(context, ref, person),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'today', child: Text(l.notToday)),
                    PopupMenuItem(value: 'while', child: Text(l.doNotSuggest)),
                    PopupMenuItem(value: 'block', child: Text(l.block)),
                    PopupMenuItem(value: 'report', child: Text(l.report)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
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
            const SizedBox(height: 8),
            for (final r in s.candidate.reasons)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(reasonIcon(r), size: 18, color: AppColors.terracotta),
                    const SizedBox(width: 8),
                    Expanded(child: Text(reasonText(l, r, person))),
                  ],
                ),
              ),
            if (starter != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: AppColors.sageDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.starterLine(starter),
                      style: const TextStyle(
                        color: AppColors.sageDark,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sageDark,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => controller.talkNow(s),
                icon: Icon(
                  viaPhone ? Icons.call_rounded : Icons.headset_mic_rounded,
                ),
                label: Text(s.alreadyAccepted ? l.talkNowAccepted : l.talkNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
