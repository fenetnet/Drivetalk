import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Short post-call feedback. Never shown while driving.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  FeedbackRating? _rating;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final peer = ref.watch(sessionProvider).peer;
    final me = ref.watch(profileServiceProvider).me;
    final c = ref.read(sessionProvider.notifier);
    if (peer == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: c.skipFeedback,
                  child: Text(l.skip),
                ),
              ),
              const Spacer(),
              Center(child: PersonAvatar(person: peer, size: 96)),
              const SizedBox(height: 20),
              if (_rating == null) ...[
                Text(
                  l.feedbackQuestion(genderKey(me.gender)),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 28),
                for (final (r, label, icon) in [
                  (
                    FeedbackRating.veryGood,
                    l.feedbackVeryGood,
                    Icons.sentiment_very_satisfied_rounded,
                  ),
                  (
                    FeedbackRating.good,
                    l.feedbackGood,
                    Icons.sentiment_satisfied_rounded,
                  ),
                  (
                    FeedbackRating.notReally,
                    l.feedbackNotReally,
                    Icons.sentiment_neutral_rounded,
                  ),
                ]) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _rating = r),
                    icon: Icon(icon, color: AppColors.terracotta),
                    label: Text(label, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 12),
                ],
              ] else ...[
                Text(
                  l.feedbackAgainQuestion,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            c.submitFeedback(_rating!, wantAgain: true),
                        child: Text(l.yes),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            c.submitFeedback(_rating!, wantAgain: false),
                        child: Text(l.no),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => c.submitFeedback(_rating!),
                  child: Text(l.skip),
                ),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
