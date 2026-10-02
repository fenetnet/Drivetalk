import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/session_controller.dart';
import '../app/theme.dart';
import '../features/common/labels.dart';
import '../features/common/widgets.dart';

/// Shows how the matching engine sees everyone right now: score breakdown,
/// tier and reasons for ranked people, and why the others were filtered out.
class MatchingInspector extends ConsumerWidget {
  const MatchingInspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    ref.watch(nowProvider);
    final session = ref.watch(sessionProvider);
    final result = ref
        .watch(matchingFacadeProvider)
        .rank(requireAvailable: false, excludeIds: session.skippedIds);

    return Scaffold(
      appBar: AppBar(title: Text(l.debugInspector)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              l.debugInspectorNote,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
          SectionTitle(l.debugInspectorRanked),
          for (final c in result.ranked)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Card(
                child: ExpansionTile(
                  shape: const Border(),
                  leading: PersonAvatar(person: c.input.person, size: 40),
                  title: Text(c.input.person.name),
                  subtitle: Text(
                    '${tierLabel(l, c.tier)} · ${l.debugScore(c.score.toStringAsFixed(2))}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in c.contributions.entries)
                      if (e.value != 0)
                        Row(
                          children: [
                            Expanded(child: Text(featureLabel(l, e.key))),
                            Text(
                              e.value.toStringAsFixed(2),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: e.value < 0
                                    ? AppColors.danger
                                    : AppColors.sageDark,
                              ),
                            ),
                          ],
                        ),
                    const Divider(),
                    for (final r in c.reasons)
                      Text('• ${reasonText(l, r, c.input.person)}'),
                  ],
                ),
              ),
            ),
          SectionTitle(l.debugInspectorRejected),
          for (final r in result.rejected)
            ListTile(
              dense: true,
              leading: PersonAvatar(person: r.input.person, size: 32),
              title: Text(r.input.person.name),
              subtitle: Text(filterLabel(l, r.reason)),
            ),
        ],
      ),
    );
  }
}
