import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Phase 1: simulated audio call — name, avatar, timer, mute, end.
/// Big buttons in all modes so it is safe to use in a car mount.
class CallScreen extends ConsumerWidget {
  const CallScreen({super.key, required this.driverMode});
  final bool driverMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final now = ref.watch(nowProvider);
    final peer = session.peer;
    final c = ref.read(sessionProvider.notifier);
    if (peer == null) return const SizedBox.shrink();
    final elapsed = now.difference(session.callStartedAt ?? now);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final fg = driverMode ? Colors.white : AppColors.ink;

    return Scaffold(
      backgroundColor: driverMode
          ? AppColors.driverBg
          : const Color(0xFFF3E9DF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Pill(
                icon: Icons.science_rounded,
                text: l.callSimulated,
                color: const Color(0xFFFCEFD2),
              ),
              const Spacer(),
              PersonAvatar(person: peer, size: 140),
              const SizedBox(height: 20),
              Text(
                peer.name,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$mm:$ss',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 28,
                  color: fg.withValues(alpha: 0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.callAudioOnly,
                style: TextStyle(color: fg.withValues(alpha: 0.6)),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _CallButton(
                      icon: session.muted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: session.muted ? l.callUnmute : l.callMute,
                      color: session.muted
                          ? AppColors.sand
                          : (driverMode ? AppColors.driverCard : Colors.white),
                      fg: session.muted || !driverMode
                          ? AppColors.ink
                          : Colors.white,
                      onTap: c.toggleMute,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CallButton(
                      icon: Icons.call_end_rounded,
                      label: l.callEnd,
                      color: AppColors.danger,
                      fg: Colors.white,
                      onTap: c.endCall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.fg,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
