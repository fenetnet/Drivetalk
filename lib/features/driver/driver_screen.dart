import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Driver mode: no feed, no long text, no typing, no scrolling lists.
/// At most three huge actions. Shown when the device is probably in a vehicle
/// or availability mode is "driving".
class DriverScreen extends ConsumerWidget {
  const DriverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final session = ref.watch(sessionProvider);
    final c = ref.read(sessionProvider.notifier);
    final mine = ref.watch(availabilityServiceProvider).mine;
    final available = mine != null && mine.isActiveAt(now);

    final Widget content;
    switch (session.phase) {
      case SessionPhase.suggestion when session.suggestion != null:
        final s = session.suggestion!;
        content = _DriverLayout(
          top: Column(
            children: [
              PersonAvatar(person: s.person, size: 120),
              const SizedBox(height: 16),
              _BigText(s.person.name, size: 40),
              const SizedBox(height: 8),
              // Who they are to me — one short line, nothing to read.
              _BigText(
                relationshipLine(
                  l,
                  connection: s.candidate.input.connection,
                  mutualFriends: s.candidate.input.mutualFriends,
                  sharedGroups: s.candidate.input.sharedGroups,
                ),
                size: 20,
                color: Colors.white70,
              ),
            ],
          ),
          actions: [
            _DriverButton(
              label: l.driverCall,
              icon: Icons.call_rounded,
              color: AppColors.sageDark,
              onTap: c.talkNow,
              big: true,
            ),
            _DriverButton(
              label: l.driverNext,
              icon: Icons.skip_next_rounded,
              onTap: c.next,
            ),
            _DriverButton(
              label: l.driverStop,
              icon: Icons.stop_rounded,
              onTap: c.stopAvailability,
            ),
          ],
        );
      case SessionPhase.waitingForAnswer when session.suggestion != null:
        final s = session.suggestion!;
        content = _DriverLayout(
          top: Column(
            children: [
              PulsingCircle(
                size: 120,
                color: AppColors.sage,
                child: PersonAvatar(person: s.person, size: 112),
              ),
              const SizedBox(height: 16),
              _BigText(l.driverWaiting(s.person.name), size: 26),
            ],
          ),
          actions: [
            _DriverButton(
              label: l.cancel,
              icon: Icons.close_rounded,
              onTap: c.cancelWaiting,
            ),
          ],
        );
      case SessionPhase.searching:
        content = _DriverLayout(
          top: Column(
            children: [
              const PulsingCircle(
                size: 120,
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 16),
              _BigText(l.driverSearching, size: 32),
              if (available && !mine.untilTripEnds)
                _BigText(
                  l.timeLeftMinutes(mine.minutesLeftAt(now)),
                  size: 20,
                  color: Colors.white70,
                ),
            ],
          ),
          actions: [
            _DriverButton(
              label: l.driverStop,
              icon: Icons.stop_rounded,
              onTap: c.stopAvailability,
            ),
          ],
        );
      default:
        content = available
            ? _DriverLayout(
                top: Column(
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                    const SizedBox(height: 16),
                    _BigText(
                      mine.untilTripEnds
                          ? l.durationUntilTripEnds
                          : l.timeLeftMinutes(mine.minutesLeftAt(now)),
                      size: 30,
                    ),
                  ],
                ),
                actions: [
                  _DriverButton(
                    label: l.driverFindAnother,
                    icon: Icons.call_rounded,
                    color: AppColors.sageDark,
                    onTap: c.searchAgain,
                    big: true,
                  ),
                  _DriverButton(
                    label: l.driverStop,
                    icon: Icons.stop_rounded,
                    onTap: c.stopAvailability,
                  ),
                ],
              )
            : _DriverLayout(
                top: Column(
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                    const SizedBox(height: 16),
                    _BigText(l.driverInVehicle, size: 26),
                  ],
                ),
                actions: [
                  _DriverButton(
                    label: l.driverBecomeAvailable,
                    icon: Icons.record_voice_over_rounded,
                    color: AppColors.terracotta,
                    big: true,
                    onTap: () => c.startAvailability(
                      AvailabilityMode.driving,
                      untilTripEnds: true,
                    ),
                  ),
                ],
              );
    }

    return Scaffold(
      backgroundColor: AppColors.driverBg,
      body: SafeArea(child: content),
    );
  }
}

class _DriverLayout extends StatelessWidget {
  const _DriverLayout({required this.top, required this.actions});
  final Widget top;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Center(child: top)),
          for (final a in actions) ...[a, const SizedBox(height: 14)],
          Text(
            l.driverSafety,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BigText extends StatelessWidget {
  const _BigText(this.text, {this.size = 24, this.color = Colors.white});
  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600),
  );
}

class _DriverButton extends StatelessWidget {
  const _DriverButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.driverCard,
    this.big = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: big ? 110 : 84,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: TextStyle(
            fontFamily: 'Rubik',
            fontSize: big ? 32 : 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: big ? 44 : 34),
        label: Text(label),
      ),
    );
  }
}
