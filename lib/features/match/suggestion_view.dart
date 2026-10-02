import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/conversation_starters.dart';
import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../../matching/match_reason.dart';
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

/// Compact by default: who, one reason, one button. Tap for more.
class _OptionCard extends ConsumerStatefulWidget {
  const _OptionCard({required this.suggestion});
  final Suggestion suggestion;

  @override
  ConsumerState<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends ConsumerState<_OptionCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = widget.suggestion;
    final person = s.person;
    final controller = ref.read(sessionProvider.notifier);
    final me = ref.watch(profileServiceProvider).me;
    final now = ref.watch(nowProvider);
    final starter = ref.watch(startersProvider).forPair(me, person);
    final viaPhone = controller.callMethodFor(person) == CallMethod.phone;
    final minutes = s.candidate.input.availability?.minutesLeftAt(now);
    // The single most telling reason (availability is shown separately).
    final mainReason = s.candidate.reasons
        .where((r) => r is! AvailableForReason)
        .firstOrNull;
    final who = relationshipLine(
      l,
      connection: s.candidate.input.connection,
      mutualFriends: s.candidate.input.mutualFriends,
      sharedGroups: s.candidate.input.sharedGroups,
    );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PersonAvatar(person: person, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                person.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (s.isExploration) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: AppColors.terracotta,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          [
                            if (minutes != null && minutes > 0)
                              l.timeLeftMinutes(minutes),
                            who,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                        if (mainReason != null)
                          Text(
                            reasonText(l, mainReason, person),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sageDark,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: () => controller.talkNow(s),
                    icon: Icon(
                      viaPhone ? Icons.call_rounded : Icons.headset_mic_rounded,
                      size: 20,
                    ),
                    label: Text(l.talkShort),
                  ),
                ],
              ),
              if (_expanded) ...[
                const Divider(height: 20),
                for (final r in s.candidate.reasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          reasonIcon(r),
                          size: 18,
                          color: AppColors.terracotta,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(reasonText(l, r, person))),
                      ],
                    ),
                  ),
                if (starter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l.starterLine(starter),
                      style: const TextStyle(
                        color: AppColors.sageDark,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => controller.notToday(s),
                      child: Text(l.notToday),
                    ),
                    TextButton(
                      onPressed: () => controller.doNotSuggestForAWhile(s),
                      child: Text(l.doNotSuggest),
                    ),
                    TextButton(
                      onPressed: () => confirmBlock(context, ref, person),
                      child: Text(l.block),
                    ),
                    TextButton(
                      onPressed: () => showReportSheet(context, ref, person),
                      child: Text(l.report),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
