import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../availability/pick_mode_screen.dart';
import '../availability/searching_view.dart';
import '../common/labels.dart';
import '../match/suggestion_view.dart';
import '../match/waiting_view.dart';

/// Home: availability status and the big "I'm free now" button.
/// While a window is active, Home shows the live session instead.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final Widget child = switch (session.phase) {
      SessionPhase.searching => const SearchingView(),
      SessionPhase.suggestion => const SuggestionView(),
      SessionPhase.waitingForAnswer => const WaitingView(),
      _ => const _IdleHome(),
    };
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(session.phase), child: child),
        ),
      ),
    );
  }
}

class _IdleHome extends ConsumerWidget {
  const _IdleHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final me = ref.watch(profileServiceProvider).me;
    final prefs = ref.watch(profileServiceProvider).prefs;
    final mine = ref.watch(availabilityServiceProvider).mine;
    final active = mine != null && mine.isActiveAt(now);
    final availableCount = ref
        .watch(matchingFacadeProvider)
        .rank()
        .ranked
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            me.name.isEmpty ? l.homeGreetingNoName : l.homeGreeting(me.name),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            active ? l.homeRestingTitle : l.homeStatusUnavailable,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 16),
          ),
          if (prefs.autoDrivingAvailability) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.directions_car_rounded,
                  size: 18,
                  color: AppColors.sageDark,
                ),
                const SizedBox(width: 6),
                Text(
                  l.homeAutoDrivingOn,
                  style: const TextStyle(color: AppColors.sageDark),
                ),
              ],
            ),
          ],
          const Spacer(),
          if (active)
            _RestingCard(
              timeLeft: mine.untilTripEnds
                  ? l.durationUntilTripEnds
                  : l.timeLeftMinutes(mine.minutesLeftAt(now)),
              mode: modeLabel(l, mine.mode),
              icon: modeIcon(mine.mode),
            )
          else
            Center(
              child: _BigFreeButton(
                label: l.homeImFreeNow(genderKey(me.gender)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PickModeScreen(),
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (!active)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Text(
                l.homeAvailableCount(availableCount),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
              ),
            ),
        ],
      ),
    );
  }
}

class _BigFreeButton extends StatelessWidget {
  const _BigFreeButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.terracotta,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: AppColors.terracotta.withValues(alpha: 0.5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 230,
            height: 230,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.record_voice_over_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestingCard extends ConsumerWidget {
  const _RestingCard({
    required this.timeLeft,
    required this.mode,
    required this.icon,
  });
  final String timeLeft;
  final String mode;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final controller = ref.read(sessionProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.sageDark),
            const SizedBox(height: 8),
            Text(mode, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              timeLeft,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.searchAgain,
                icon: const Icon(Icons.search_rounded),
                label: Text(l.homeFindAnother),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: controller.stopAvailability,
                child: Text(l.stopAvailability),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
