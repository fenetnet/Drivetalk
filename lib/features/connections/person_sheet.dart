import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import '../match/safety_actions.dart';

Future<void> showPersonSheet(BuildContext context, String personId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PersonSheet(personId: personId),
    );

/// Details of one person: relationship type (optional), in-app history,
/// and safety actions (pause / unmatch / block / report).
class PersonSheet extends ConsumerWidget {
  const PersonSheet({super.key, required this.personId});
  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final graph = ref.watch(socialGraphServiceProvider);
    final person = graph.personById(personId);
    if (person == null) return const SizedBox.shrink();
    final c = graph.connectionWith(personId);
    final pause = graph.pauseFor(personId);
    final paused = pause != null && pause.until.isAfter(now);
    final snoozeDays = ref
        .watch(matchingConfigProvider)
        .snooze
        .doNotSuggestDays;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Center(child: PersonAvatar(person: person, size: 88)),
          const SizedBox(height: 12),
          Text(
            person.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            relationshipLine(
              l,
              connection: c,
              mutualFriends: graph.mutualFriendsWith(personId),
              sharedGroups: graph.sharedGroupsWith(personId),
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            c == null
                ? l.mutualFriendsShort(graph.mutualFriendsWith(personId))
                : l.personCalls(c.callCount),
            textAlign: TextAlign.center,
          ),
          if (c != null) ...[
            const SizedBox(height: 20),
            Text(
              l.personRelationship,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in [null, ...RelationshipType.values])
                  ChoiceChip(
                    label: Text(relationshipLabel(l, t)),
                    selected: c.relationshipType == t,
                    onSelected: (_) => graph.setRelationship(personId, t),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (paused) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pause_circle_outline_rounded),
              title: Text(l.personPausedUntil(pause.until)),
              trailing: TextButton(
                onPressed: () => graph.allowSuggestions(personId),
                child: Text(l.personAllow),
              ),
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.do_not_disturb_on_outlined),
              title: Text(l.doNotSuggest),
              onTap: () => graph.pauseSuggestions(
                personId,
                PauseKind.doNotSuggest,
                now.add(Duration(days: snoozeDays)),
              ),
            ),
          if (c != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_remove_outlined),
              title: Text(l.unmatch),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    content: Text(l.personUnmatchConfirm(person.name)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: Text(l.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: Text(l.confirm),
                      ),
                    ],
                  ),
                );
                if (ok ?? false) {
                  await graph.unmatch(personId);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.block_rounded, color: AppColors.danger),
            title: Text(
              l.block,
              style: const TextStyle(color: AppColors.danger),
            ),
            onTap: () async {
              await confirmBlock(context, ref, person);
              if (context.mounted && graph.blockedIds.contains(personId)) {
                Navigator.pop(context);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined, color: AppColors.danger),
            title: Text(
              l.report,
              style: const TextStyle(color: AppColors.danger),
            ),
            onTap: () => showReportSheet(context, ref, person),
          ),
        ],
      ),
    );
  }
}
