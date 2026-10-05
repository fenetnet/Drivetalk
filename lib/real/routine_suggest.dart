import '../domain/models.dart';

/// "You're usually free on Sundays around 17:30 — make it a routine?"
/// Worked out only on this phone, from when I marked myself free.
class RoutineSuggestion {
  const RoutineSuggestion({
    required this.weekday,
    required this.minuteOfDay,
    required this.mode,
  });
  final int weekday;
  final int minuteOfDay;
  final AvailabilityMode mode;

  /// To remember "no thanks" for this slot.
  String get key => 'w$weekday-$minuteOfDay';
}

/// At least [minDays] different days in the last 4 weeks, same weekday,
/// within the same half hour, and no routine near it yet.
RoutineSuggestion? suggestRoutine({
  required List<(DateTime, AvailabilityMode)> log,
  required List<Routine> routines,
  required Set<String> dismissed,
  required DateTime now,
  int minDays = 3,
}) {
  final since = now.subtract(const Duration(days: 28));
  final days = <String, Set<String>>{};
  final modes = <String, List<AvailabilityMode>>{};
  for (final (t, mode) in log) {
    if (t.isBefore(since) || t.isAfter(now)) continue;
    final minute = ((t.hour * 60 + t.minute) / 30).round() * 30 % (24 * 60);
    final key = 'w${t.weekday}-$minute';
    (days[key] ??= {}).add('${t.year}-${t.month}-${t.day}');
    (modes[key] ??= []).add(mode);
  }
  RoutineSuggestion? best;
  var bestCount = 0;
  for (final e in days.entries) {
    if (e.value.length < minDays || e.value.length <= bestCount) continue;
    if (dismissed.contains(e.key)) continue;
    final parts = e.key.substring(1).split('-');
    final weekday = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final covered = routines.any(
      (r) =>
          r.weekdays.contains(weekday) && (r.minuteOfDay - minute).abs() <= 45,
    );
    if (covered) continue;
    final ms = modes[e.key]!;
    final mode = AvailabilityMode.values.reduce(
      (a, b) => ms.where((m) => m == a).length >= ms.where((m) => m == b).length
          ? a
          : b,
    );
    best = RoutineSuggestion(weekday: weekday, minuteOfDay: minute, mode: mode);
    bestCount = e.value.length;
  }
  return best;
}
