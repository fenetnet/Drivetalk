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

/// For how long? 15/30/45/60 or "until I finish the drive".
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    for (final m in const [15, 30, 45, 60])
                      _BigTile(
                        label: l.minutesShort(m),
                        onTap: () => _start(minutes: m),
                      ),
                  ],
                ),
              ),
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
