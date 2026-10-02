import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../common/labels.dart';

/// Step 1: what are you doing? (driving / walking / break / just free)
class PickModeScreen extends StatelessWidget {
  const PickModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.pickModeTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    for (final m in AvailabilityMode.values)
                      _BigTile(
                        icon: modeIcon(m),
                        label: modeLabel(l, m),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PickDurationScreen(mode: m),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 2: for how long? 15/30/45/60 or "until I finish the drive".
/// Optionally: available only to one of my private circles.
class PickDurationScreen extends ConsumerStatefulWidget {
  const PickDurationScreen({super.key, required this.mode});
  final AvailabilityMode mode;

  @override
  ConsumerState<PickDurationScreen> createState() => _PickDurationState();
}

class _PickDurationState extends ConsumerState<PickDurationScreen> {
  String? _circleId;

  void _start({int? minutes, bool untilTripEnds = false}) {
    ref
        .read(sessionProvider.notifier)
        .startAvailability(
          widget.mode,
          minutes: minutes,
          untilTripEnds: untilTripEnds,
          circleId: _circleId,
        );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mode = widget.mode;
    final cap = ref
        .watch(matchingConfigProvider)
        .snooze
        .drivingSafetyCapMinutes;
    final circles = ref.watch(profileServiceProvider).prefs.circles;
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
  const _BigTile({required this.label, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
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
              if (icon != null) ...[
                Icon(icon, size: 44, color: AppColors.terracotta),
                const SizedBox(height: 12),
              ],
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
