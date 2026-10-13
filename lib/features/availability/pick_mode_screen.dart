import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../common/labels.dart';

/// Starts availability on the server.
typedef StartAvailability = void Function(
  AvailabilityMode mode,
  int minutes,
  String? circleId,
);

/// For how long? 10/20/30/60, "until…" (a clock) or "until I finish the
/// drive".
/// Optionally: available only to one of my private circles.
class PickDurationScreen extends StatefulWidget {
  const PickDurationScreen({
    super.key,
    required this.mode,
    required this.onStart,
    this.realCircles = const [],
  });
  final AvailabilityMode mode;
  final StartAvailability onStart;
  final List<(String, String)> realCircles;

  @override
  State<PickDurationScreen> createState() => _PickDurationState();
}

/// "Until the drive ends" = at most 3 hours (the server's limit too).
const _tripCapMinutes = 180;

class _PickDurationState extends State<PickDurationScreen> {
  String? _circleId;

  void _start({int? minutes, bool untilTripEnds = false}) {
    widget.onStart(
      widget.mode,
      untilTripEnds ? _tripCapMinutes : minutes ?? 30,
      _circleId,
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// "Until…": a clock. At most 3 hours from now (the server's limit).
  Future<void> _untilTime() async {
    final l = context.l10n;
    final now = DateTime.now();
    final soon = now.add(const Duration(hours: 1));
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: soon.hour, minute: 0),
    );
    if (picked == null || !mounted) return;
    var until = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );
    // An earlier hour means tomorrow (e.g. 00:30 picked at 23:00).
    if (!until.isAfter(now)) until = until.add(const Duration(days: 1));
    var minutes = (until.difference(now).inSeconds / 60).ceil();
    if (minutes > _tripCapMinutes) {
      minutes = _tripCapMinutes;
      final end = now.add(const Duration(minutes: _tripCapMinutes));
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l.durationUntilTimeCapped(
              '${end.hour.toString().padLeft(2, '0')}:'
              '${end.minute.toString().padLeft(2, '0')}',
            ),
          ),
        ),
      );
    }
    _start(minutes: minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mode = widget.mode;
    const cap = _tripCapMinutes;
    final circles = [
      for (final (id, name) in widget.realCircles) Circle(id: id, name: name),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(modeIcon(mode)),
            const SizedBox(width: 8),
            Text(modeLabel(l, mode)),
          ],
        ),
      ),
      body: SafeArea(
        // Scrolls only if it doesn't fit (small phone, large text).
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.pickDurationTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (circles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l.availableTo,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(l.availableToEveryone),
                      selected: _circleId == null,
                      onSelected: (_) => setState(() => _circleId = null),
                    ),
                    for (final c in circles)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: _circleId == c.id,
                        onSelected: (_) => setState(() => _circleId = c.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              // "Until…" right under the minutes, not at the bottom.
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  for (final m in const [10, 20, 30, 60])
                    _BigTile(
                      label: l.minutesShort(m),
                      onTap: () => _start(minutes: m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _untilTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  l.durationUntilTime,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 12),
              if (mode == AvailabilityMode.driving) ...[
                FilledButton.icon(
                  onPressed: () => _start(untilTripEnds: true),
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(l.durationUntilTripEnds),
                ),
                const SizedBox(height: 8),
                Text(
                  l.durationTripNote(cap ~/ 60),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  const _BigTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
