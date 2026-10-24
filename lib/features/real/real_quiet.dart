import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';

String _hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// "א–ה", "ו, ש" or "every day" (three days or more in a row get a dash).
String quietDaysLabel(AppLocalizations l, int? days) {
  if (days == null || days & 127 == 127) return l.quietEveryDay;
  final letters = l.quietDayLetters.split(',');
  final parts = <String>[];
  var d = 0;
  while (d < 7) {
    if (days & (1 << d) == 0) {
      d++;
      continue;
    }
    var end = d;
    while (end + 1 < 7 && days & (1 << (end + 1)) != 0) {
      end++;
    }
    if (end - d >= 2) {
      parts.add('${letters[d]}–${letters[end]}');
    } else {
      for (var x = d; x <= end; x++) {
        parts.add(letters[x]);
      }
    }
    d = end + 1;
  }
  return parts.join(', ');
}

String _rangeLine(AppLocalizations l, QuietRange r) =>
    l.quietRangeLine(quietDaysLabel(l, r.days), _hhmm(r.from), _hhmm(r.to));

/// The line under "Quiet hours" in Settings.
String quietSummary(BuildContext context, MyStatus? st) {
  final l = AppLocalizations.of(context);
  final ranges = st?.quietRanges ?? const <QuietRange>[];
  if (ranges.isEmpty) return l.settingsQuietOff;
  if (ranges.length == 1) {
    final r = ranges.single;
    return r.everyDay
        ? l.settingsQuietOn(_hhmm(r.from), _hhmm(r.to))
        : l.settingsQuietOnDays(
            quietDaysLabel(l, r.days),
            _hhmm(r.from),
            _hhmm(r.to),
          );
  }
  return l.quietMany(
    '${ranges.length}',
    [for (final r in ranges) _rangeLine(l, r)].join(' · '),
  );
}

/// Quiet hours: several schedules (D-124), e.g. Sunday–Thursday nights and
/// other hours on the weekend. Only automatic trips are affected.
class QuietHoursScreen extends ConsumerWidget {
  const QuietHoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final ranges = s.snapshot?.status.quietRanges ?? const <QuietRange>[];

    Future<void> edit(int? index) async {
      final r = await pickQuietRange(
        context,
        index == null ? null : ranges[index],
      );
      if (r == null) return;
      final next = [...ranges];
      if (index == null) {
        next.add(r);
      } else {
        next[index] = r;
      }
      await c.setQuietRanges(next);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsQuietHours)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.quietScreenBody, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          if (ranges.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l.quietNone,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            ),
          for (var i = 0; i < ranges.length; i++)
            Card(
              key: ValueKey('quiet-range-$i'),
              child: ListTile(
                leading: const Icon(
                  Icons.bedtime_rounded,
                  color: AppColors.terracotta,
                ),
                title: Text(
                  '${_hhmm(ranges[i].from)}–${_hhmm(ranges[i].to)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(quietDaysLabel(l, ranges[i].days)),
                onTap: s.busy ? null : () => edit(i),
                trailing: IconButton(
                  tooltip: l.quietDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: s.busy
                      ? null
                      : () => c.setQuietRanges([...ranges]..removeAt(i)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (ranges.length < 4)
            FilledButton.icon(
              key: const ValueKey('quiet-add'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: s.busy ? null : () => edit(null),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.quietAdd, style: const TextStyle(fontSize: 17)),
            ),
        ],
      ),
    );
  }
}

/// From, to, then the days. Null = closed on the way.
Future<QuietRange?> pickQuietRange(
  BuildContext context,
  QuietRange? current,
) async {
  final l = AppLocalizations.of(context);
  final from = await showTimePicker(
    context: context,
    helpText: l.quietPickFrom,
    initialTime: TimeOfDay(
      hour: (current?.from ?? 22 * 60) ~/ 60,
      minute: (current?.from ?? 0) % 60,
    ),
  );
  if (from == null || !context.mounted) return null;
  final to = await showTimePicker(
    context: context,
    helpText: l.quietPickTo,
    initialTime: TimeOfDay(
      hour: (current?.to ?? 7 * 60) ~/ 60,
      minute: (current?.to ?? 0) % 60,
    ),
  );
  if (to == null || !context.mounted) return null;
  final f = from.hour * 60 + from.minute;
  final t = to.hour * 60 + to.minute;
  if (f == t) return null;
  final days = await pickQuietDays(context, current?.days ?? 127);
  if (days == null) return null;
  return QuietRange(f, t, days);
}

/// Which days (bit 0 = Sunday). Null = closed.
Future<int?> pickQuietDays(BuildContext context, int initial) =>
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (d) {
        final l = AppLocalizations.of(d);
        final letters = l.quietDayLetters.split(',');
        var days = initial;
        return StatefulBuilder(
          builder: (d, set) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.quietPickDays,
                    style: Theme.of(d).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < 7; i++)
                        FilterChip(
                          key: ValueKey('quiet-day-$i'),
                          label: Text(letters[i]),
                          selected: days & (1 << i) != 0,
                          onSelected: (on) => set(
                            () =>
                                days = on ? days | (1 << i) : days & ~(1 << i),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: days == 0 ? null : () => Navigator.pop(d, days),
                    child: Text(l.quietDaysSave),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
