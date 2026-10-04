import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../real/real_controller.dart';
import '../common/labels.dart';

/// "I usually drive at 08:00 on Sun–Thu." At those times Home offers a
/// one-tap "become available". (Real reminders come with notifications.)
class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key, this.real = false});

  /// Real mode: the phone turns availability on by itself at these times.
  final bool real;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final profile = ref.watch(profileServiceProvider);
    final routines = real
        ? ref.watch(realProvider.select((s) => s.routines))
        : profile.prefs.routines;
    Future<void> save(List<Routine> list) => real
        ? ref.read(realProvider.notifier).saveRoutines(list)
        : profile.updatePrefs(profile.prefs.copyWith(routines: list));

    return Scaffold(
      appBar: AppBar(title: Text(l.routinesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final r = await showModalBottomSheet<Routine>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => const _RoutineEditor(),
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
            real ? l.realRoutinesIntro : l.routinesIntro,
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
                  '${_time(r.minuteOfDay)} · ${modeLabel(l, r.mode)} · '
                  '${l.minutesShort(r.durationMinutes)}',
                ),
                subtitle: Text(weekdaysText(l, r.weekdays)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => save([
                    for (final x in routines)
                      if (x.id != r.id) x,
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _time(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

class _RoutineEditor extends StatefulWidget {
  const _RoutineEditor();

  @override
  State<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<_RoutineEditor> {
  var _days = {7, 1, 2, 3, 4}; // Sun–Thu
  var _time = const TimeOfDay(hour: 8, minute: 0);
  var _mode = AvailabilityMode.driving;
  var _minutes = 30;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
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
              label: Text(_time.format(context)),
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
                for (final m in const [15, 30, 45, 60])
                  ChoiceChip(
                    label: Text(l.minutesShort(m)),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
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
