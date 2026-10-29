import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import 'real_common.dart';

/// "Until when" for a pause: a time today, "tomorrow", a weekday, a date.
String pauseWhen(AppLocalizations l, DateTime until, DateTime now) {
  final u = until.toLocal();
  final n = now.toLocal();
  final days = DateTime(
    u.year,
    u.month,
    u.day,
  ).difference(DateTime(n.year, n.month, n.day)).inDays;
  String two(int x) => x.toString().padLeft(2, '0');
  if (days <= 0) return l.pauseUntilTime('${two(u.hour)}:${two(u.minute)}');
  if (days == 1) return l.pauseUntilTomorrow;
  if (days < 7) return l.pauseUntilDay(weekdayShort(l, u.weekday));
  return l.pauseUntilDate('${u.day}.${u.month}');
}

/// On a friend's card: my pause after a call, with "cancel" (D-113).
class PauseTile extends ConsumerWidget {
  const PauseTile({super.key, required this.friend});
  final RealProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(realProvider);
    final now = ref.watch(realNowProvider);
    final snap = s.snapshot;
    final p = snap?.pauses[friend.id];
    if (snap == null || p == null || !p.until.isAfter(now)) {
      return const SizedBox.shrink();
    }
    final quickStill = snap.quickBoth(friend.id) && !p.chosen;
    return ListTile(
      leading: const Icon(Icons.pause_circle_rounded, color: AppColors.inkSoft),
      title: Text(l.pauseTitle(pauseWhen(l, p.until, now))),
      subtitle: Text(
        [l.pauseBody(friend.name), if (quickStill) l.pauseQuickNote].join(' '),
      ),
      trailing: TextButton(
        onPressed: s.busy
            ? null
            : () => ref.read(realProvider.notifier).clearPause(friend),
        child: Text(l.pauseCancel),
      ),
    );
  }
}
