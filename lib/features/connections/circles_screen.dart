import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Private circles, e.g. "חברים מהצבא". When becoming available I can choose
/// to be available only to one circle. Nobody sees my circles.
class CirclesScreen extends ConsumerWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final profile = ref.watch(profileServiceProvider);
    final graph = ref.watch(socialGraphServiceProvider);
    final circles = profile.prefs.circles;

    Future<void> save(List<Circle> c) =>
        profile.updatePrefs(profile.prefs.copyWith(circles: c));

    return Scaffold(
      appBar: AppBar(title: Text(l.circlesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(l.circleAdd),
        onPressed: () async {
          final name = await _askName(context, l.circleAdd);
          if (name == null || name.isEmpty) return;
          await save([
            ...circles,
            Circle(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: name,
            ),
          ]);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            l.circlesIntro,
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          for (final c in circles)
            Card(
              child: ExpansionTile(
                shape: const Border(),
                leading: const Icon(Icons.bubble_chart_rounded),
                title: Text(c.name),
                subtitle: Text(l.circleMembers(c.memberIds.length)),
                children: [
                  for (final conn in graph.connections)
                    if (graph.personById(conn.personId) case final p?)
                      CheckboxListTile(
                        secondary: PersonAvatar(person: p, size: 36),
                        title: Text(p.name),
                        value: c.memberIds.contains(p.id),
                        onChanged: (v) => save([
                          for (final x in circles)
                            if (x.id != c.id)
                              x
                            else
                              x.copyWith(
                                memberIds: (v ?? false)
                                    ? {...x.memberIds, p.id}
                                    : ({...x.memberIds}..remove(p.id)),
                              ),
                        ]),
                      ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l.circleDelete),
                    onPressed: () => save([
                      for (final x in circles)
                        if (x.id != c.id) x,
                    ]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _askName(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.circleNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }
}
