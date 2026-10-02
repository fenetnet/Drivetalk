import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// "Looking for someone who fits to talk with you right now."
class SearchingView extends ConsumerWidget {
  const SearchingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final session = ref.watch(sessionProvider);
    final mine = ref.watch(availabilityServiceProvider).mine;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (mine != null)
            _AvailabilityHeader(
              icon: modeIcon(mine.mode),
              text: mine.untilTripEnds
                  ? l.durationUntilTripEnds
                  : l.timeLeftMinutes(mine.minutesLeftAt(now)),
            ),
          const Spacer(),
          const PulsingCircle(
            size: 140,
            child: Icon(
              Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l.searchingTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            session.beaconSent
                ? l.beaconSent(session.beaconRecipients)
                : l.searchingNoOneYet,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: ref.read(sessionProvider.notifier).stopAvailability,
              child: Text(l.stopAvailability),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityHeader extends StatelessWidget {
  const _AvailabilityHeader({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Pill(
        icon: icon,
        text: text,
        color: const Color(0xFFDCEBE3),
        textColor: AppColors.sageDark,
      ),
    );
  }
}
