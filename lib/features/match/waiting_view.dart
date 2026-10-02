import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Waiting for the other side to say yes. No auto-connect, ever.
class WaitingView extends ConsumerWidget {
  const WaitingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(sessionProvider).suggestion;
    if (s == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          PulsingCircle(
            size: 120,
            color: AppColors.sage,
            child: PersonAvatar(person: s.person, size: 112),
          ),
          const SizedBox(height: 24),
          Text(
            l.waitingTitle(s.person.name),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l.waitingSubtitle,
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: ref.read(sessionProvider.notifier).cancelWaiting,
              child: Text(l.cancel),
            ),
          ),
        ],
      ),
    );
  }
}
