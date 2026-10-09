import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';

/// "I usually drive at 08:00 on Sun–Thu." At those times Home offers a
/// one-tap "become available". (Real reminders come with notifications.)
class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final routines = ref.watch(realProvider.select((s) => s.routines));
    final circles = [
      for (final c
          in ref.watch(realProvider).snapshot?.circles ?? const <RealCircle>[])
        (c.id, c.name),
    ];
    String circleName(String? id) => id == null
        ? l.routineEveryone
        : circles.where((c) => c.$1 == id).firstOrNull?.$2 ?? l.routineEveryone;
    Future<void> save(List<Routine> list) =>
        ref.read(realProvider.notifier).saveRoutines(list);

    return Scaffold(
      appBar: AppBar(title: Text(l.routinesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final r = await showModalBottomSheet<Routine>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => _RoutineEditor(circles: circles),
          );
          if (r != null) await save([...routines, r]);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l.routineAdd),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            l.realRoutinesIntro,
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          if (routines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text(l.routinesEmpty)),
            ),
          for (final r in routines)
            Card(
              child: ListTile(
                leading: Icon(modeIcon(r.mode), color: AppColors.terracotta),
                title: Text(
                  r.name ?? modeLabel(l, r.mode),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${weekdaysText(l, r.weekdays)} · '
                  '${_clock(r.minuteOfDay)}–'
                  '${_clock((r.minuteOfDay + r.durationMinutes) % (24 * 60))}'
                  ' · ${circleName(r.circleId)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: l.routineDelete,
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        content: Text(l.routineDeleteConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: Text(l.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: Text(l.routineDeleteGo),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await save([
                      for (final x in routines)
                        if (x.id != r.id) x,
                    ]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _clock(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

class _RoutineEditor extends StatefulWidget {
  const _RoutineEditor({this.circles = const []});

  /// Real mode: my circles as (id, name).
  final List<(String, String)> circles;

  @override
  State<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<_RoutineEditor> {
  var _days = {7, 1, 2, 3, 4}; // Sun–Thu
  var _time = const TimeOfDay(hour: 8, minute: 0);
  var _mode = AvailabilityMode.driving;
  var _minutes = 45;
  String? _name;
  String? _circleId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.routineAdd, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (name, mode, hour, minute) in [
                  (l.routineNameToWork, AvailabilityMode.driving, 7, 30),
                  (l.routineNameHome, AvailabilityMode.driving, 17, 0),
                  (l.routineNameWalk, AvailabilityMode.walking, 19, 0),
                  (l.routineNameBreak, AvailabilityMode.breakTime, 12, 30),
                ])
                  ChoiceChip(
                    label: Text(name),
                    selected: _name == name,
                    onSelected: (_) => setState(() {
                      _name = name;
                      _mode = mode;
                      _time = TimeOfDay(hour: hour, minute: minute);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in const [7, 1, 2, 3, 4, 5, 6])
                  FilterChip(
                    label: Text(weekdayShort(l, d)),
                    selected: _days.contains(d),
                    onSelected: (v) => setState(() {
                      _days = {..._days};
                      v ? _days.add(d) : _days.remove(d);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                '${_clock(_time.hour * 60 + _time.minute)}–'
                '${_clock((_time.hour * 60 + _time.minute + _minutes) % 1440)}',
              ),
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (t != null) setState(() => _time = t);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final m in AvailabilityMode.values)
                  ChoiceChip(
                    label: Text(modeLabel(l, m)),
                    selected: _mode == m,
                    onSelected: (_) => setState(() => _mode = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final m in const [15, 30, 45, 60, 90])
                  ChoiceChip(
                    label: Text(l.minutesShort(m)),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
            if (widget.circles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l.routineAvailableTo,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text(l.routineEveryone),
                    selected: _circleId == null,
                    onSelected: (_) => setState(() => _circleId = null),
                  ),
                  for (final (id, name) in widget.circles)
                    ChoiceChip(
                      label: Text(name),
                      selected: _circleId == id,
                      onSelected: (_) => setState(() => _circleId = id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _days.isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      Routine(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        weekdays: _days,
                        minuteOfDay: _time.hour * 60 + _time.minute,
                        durationMinutes: _minutes,
                        mode: _mode,
                        name: _name,
                        circleId: _circleId,
                      ),
                    ),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
