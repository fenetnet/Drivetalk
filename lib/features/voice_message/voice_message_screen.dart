import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Short voice note (up to 30 seconds) for someone who couldn't talk.
/// Phase 1: a simulation — nothing is recorded, stored or sent.
class VoiceMessageScreen extends ConsumerStatefulWidget {
  const VoiceMessageScreen({super.key});

  @override
  ConsumerState<VoiceMessageScreen> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends ConsumerState<VoiceMessageScreen> {
  static const _max = 30;
  Timer? _timer;
  var _seconds = 0;
  var _recording = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_recording) {
      _timer?.cancel();
      setState(() => _recording = false);
      return;
    }
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _seconds++);
      if (_seconds >= _max) {
        t.cancel();
        setState(() => _recording = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final peer = ref.watch(sessionProvider).peer;
    final c = ref.read(sessionProvider.notifier);
    if (peer == null) return const SizedBox.shrink();
    final hasRecording = !_recording && _seconds > 0;

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
                  onPressed: c.cancelVoiceMessage,
                  child: Text(l.cancel),
                ),
              ),
              Pill(
                icon: Icons.science_rounded,
                text: l.voiceMessageSimulated,
                color: const Color(0xFFFCEFD2),
              ),
              const Spacer(),
              Center(child: PersonAvatar(person: peer, size: 96)),
              const SizedBox(height: 16),
              Text(
                l.voiceMessageTitle(peer.name),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l.voiceMessageHint(_max),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: _toggle,
                  child: _recording
                      ? PulsingCircle(
                          size: 120,
                          color: AppColors.danger,
                          child: const Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                        )
                      : Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: AppColors.terracotta,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '0:${_seconds.toString().padLeft(2, '0')} / 0:$_max',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 20),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: hasRecording
                    ? () => c.sendVoiceMessage(Duration(seconds: _seconds))
                    : null,
                icon: const Icon(Icons.send_rounded),
                label: Text(l.voiceMessageSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
