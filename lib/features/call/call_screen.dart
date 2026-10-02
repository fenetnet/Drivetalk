import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/conversation_starters.dart';
import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../../platform/phone_dialer.dart';
import '../../services/call_service.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// The call. Two kinds:
/// - Regular phone call (the phone's own dialer does the talking; this screen
///   just waits with a big "we're done").
/// - In-app call for people whose numbers stay private (simulated in Phase 1),
///   with mute / end and the failure states (dropped, on hold, weak signal).
class CallScreen extends ConsumerWidget {
  const CallScreen({super.key, required this.driverMode});
  final bool driverMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final session = ref.watch(sessionProvider);
    final now = ref.watch(nowProvider);
    final peer = session.peer;
    final c = ref.read(sessionProvider.notifier);
    if (peer == null) return const SizedBox.shrink();
    final isPhone = session.callMethod == CallMethod.phone;
    final elapsed = now.difference(session.callStartedAt ?? now);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final fg = driverMode ? Colors.white : AppColors.ink;
    final network = ref.watch(networkServiceProvider);
    final mine = ref.watch(availabilityServiceProvider).mine;
    final expired = mine != null && !mine.isActiveAt(now);
    final me = ref.watch(profileServiceProvider).me;
    final starter = driverMode
        ? null
        : ref.watch(startersProvider).forPair(me, peer);
    final testNumber = ref.watch(profileServiceProvider).prefs.testDialNumber;

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
                icon: isPhone ? Icons.call_rounded : Icons.headset_mic_rounded,
                text: isPhone ? l.callViaPhone : l.callInApp,
                color: const Color(0xFFFCEFD2),
              ),
              if (!isPhone && network.weakSignal && !session.callDropped) ...[
                const SizedBox(height: 8),
                Pill(
                  icon: Icons.signal_cellular_alt_1_bar_rounded,
                  text: l.callWeakSignal,
                  color: const Color(0xFFFFE3D6),
                ),
              ],
              if (expired) ...[
                const SizedBox(height: 8),
                Text(
                  l.callWindowEndedKeepTalking,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fg.withValues(alpha: 0.6)),
                ),
              ],
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
              const SizedBox(height: 12),
              if (isPhone) ...[
                Text(
                  l.callPhoneSimulated(peer.name),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fg.withValues(alpha: 0.7)),
                ),
                if (!driverMode) ...[
                  const SizedBox(height: 8),
                  if (testNumber != null && testNumber.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.phone_forwarded_rounded),
                      label: Text(l.callDialTestNumber),
                      onPressed: () async {
                        final r = await ref
                            .read(phoneDialerProvider)
                            .call(testNumber);
                        if (r == DialResult.unsupported ||
                            r == DialResult.failed) {
                          messengerKey.currentState?.showSnackBar(
                            SnackBar(content: Text(l.callDialUnsupported)),
                          );
                        }
                      },
                    )
                  else
                    Text(
                      l.callSetTestNumberHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                ],
              ] else
                Text(
                  l.callAudioOnly,
                  style: TextStyle(color: fg.withValues(alpha: 0.6)),
                ),
              if (starter != null) ...[
                const SizedBox(height: 16),
                Text(
                  l.starterLine(starter),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.sageDark,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const Spacer(),
              if (session.callDropped)
                _Problem(
                  icon: Icons.signal_wifi_off_rounded,
                  text: l.callDropped,
                  primary: l.callRetry,
                  onPrimary: c.retryDroppedCall,
                  secondary: l.callEnd,
                  onSecondary: c.endCall,
                  dark: driverMode,
                )
              else if (session.callOnHold)
                _Problem(
                  icon: Icons.phone_paused_rounded,
                  text: l.callOnHold,
                  primary: l.callResume,
                  onPrimary: c.resumeFromHold,
                  secondary: l.callEnd,
                  onSecondary: c.endCall,
                  dark: driverMode,
                )
              else if (isPhone)
                SizedBox(
                  width: double.infinity,
                  height: 96,
                  child: _CallButton(
                    icon: Icons.check_rounded,
                    label: l.callWeAreDone,
                    color: AppColors.sageDark,
                    fg: Colors.white,
                    onTap: c.endCall,
                  ),
                )
              else
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
                            : (driverMode
                                  ? AppColors.driverCard
                                  : Colors.white),
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

class _Problem extends StatelessWidget {
  const _Problem({
    required this.icon,
    required this.text,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.dark,
  });
  final IconData icon;
  final String text;
  final String primary;
  final VoidCallback onPrimary;
  final String secondary;
  final VoidCallback onSecondary;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Column(
      children: [
        Icon(icon, size: 40, color: AppColors.danger),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, color: fg),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _CallButton(
                icon: Icons.refresh_rounded,
                label: primary,
                color: AppColors.sageDark,
                fg: Colors.white,
                onTap: onPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _CallButton(
                icon: Icons.call_end_rounded,
                label: secondary,
                color: AppColors.danger,
                fg: Colors.white,
                onTap: onSecondary,
              ),
            ),
          ],
        ),
      ],
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
