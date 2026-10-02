import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Mutual quick connect: "Calling Dad in 5 seconds" with one huge Cancel.
/// Shown only when BOTH sides pre-approved each other.
class QuickConnectScreen extends ConsumerWidget {
  const QuickConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final now = ref.watch(nowProvider);
    final peer = session.peer;
    final at = session.quickConnectAt;
    if (peer == null || at == null) return const SizedBox.shrink();
    final seconds = at.difference(now).inMilliseconds <= 0
        ? 0
        : (at.difference(now).inMilliseconds / 1000).ceil();

    return Scaffold(
      backgroundColor: AppColors.driverBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: PulsingCircle(
                  size: 130,
                  color: AppColors.sage,
                  child: PersonAvatar(person: peer, size: 122),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l.quickConnectTitle(peer.name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.quickConnectIn(seconds),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                l.quickConnectWhy,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const Spacer(),
              SizedBox(
                height: 110,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    textStyle: const TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: ref
                      .read(sessionProvider.notifier)
                      .cancelQuickConnect,
                  icon: const Icon(Icons.close_rounded, size: 44),
                  label: Text(l.cancel),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
