import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/voice_service.dart';
import '../../app/providers.dart';
import 'real_common.dart';

/// "Test drive" (owner): a practice question, as in the car — read aloud,
/// answered "yes" / "no" by voice or with the buttons. Nobody is asked,
/// nothing reaches the server. At the end of the first steps, and any time
/// from Settings (also to check the microphone before a drive).
class TestDriveScreen extends ConsumerStatefulWidget {
  const TestDriveScreen({super.key});

  @override
  ConsumerState<TestDriveScreen> createState() => _TestDriveState();
}

enum _Step { intro, asking, yes, no, notHeard }

class _TestDriveState extends ConsumerState<TestDriveScreen> {
  var _step = _Step.intro;
  var _listening = false;
  // A newer round (or leaving) makes an older answer count for nothing.
  var _round = 0;

  // Kept from the start: the screen may be gone when it's needed (leaving).
  late final VoiceService _voice = ref.read(voiceServiceProvider);

  @override
  void initState() {
    super.initState();
    _voice; // read now, while the screen is up
  }

  @override
  void dispose() {
    _round++;
    _voice.stop();
    super.dispose();
  }

  Future<void> _start() async {
    final l = AppLocalizations.of(context);
    final round = ++_round;
    setState(() => _step = _Step.asking);
    // The microphone question comes now, in a calm moment.
    await _voice.prepare();
    if (!mounted || round != _round) return;
    await _voice.speak(l.testDriveQuestion);
    if (!mounted || round != _round) return;
    setState(() => _listening = true);
    final heard = await _voice.listenYesNo(
      timeout: const Duration(seconds: 10),
    );
    if (!mounted || round != _round) return;
    setState(() => _listening = false);
    switch (heard) {
      case VoiceAnswer.yes:
        await _answer(true);
      case VoiceAnswer.no:
        await _answer(false);
      default:
        setState(() => _step = _Step.notHeard);
    }
  }

  Future<void> _answer(bool yes) async {
    final l = AppLocalizations.of(context);
    final round = ++_round;
    await _voice.stop();
    if (!mounted || round != _round) return;
    setState(() {
      _listening = false;
      _step = yes ? _Step.yes : _Step.no;
    });
    await _voice.speak(yes ? l.voiceHeardYes : l.voiceHeardNo);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const style = MomentStyle.dark;
    Widget friend() => Container(
      width: 150,
      height: 150,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.sand,
        shape: BoxShape.circle,
      ),
      child: Text(
        l.testDriveFriendInitial,
        style: const TextStyle(
          fontSize: 60,
          fontWeight: FontWeight.w800,
          color: Color(0xFF6B4210),
        ),
      ),
    );

    return switch (_step) {
      _Step.intro => MomentLayout(
        style: style,
        top: Column(
          children: [
            const Icon(
              Icons.directions_car_rounded,
              size: 72,
              color: AppColors.sand,
            ),
            const SizedBox(height: 24),
            MomentText(l.testDriveTitle, style: style),
            const SizedBox(height: 12),
            MomentText(l.testDriveBody, size: 17, soft: true, style: style),
          ],
        ),
        actions: [
          PrimaryPill(label: l.testDriveStart, style: style, onTap: _start),
          SecondaryPill(
            label: l.close,
            style: style,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      _Step.asking => MomentLayout(
        style: style,
        top: Column(
          children: [
            friend(),
            const SizedBox(height: 24),
            MomentText(l.testDriveQuestion, size: 30, style: style),
            const SizedBox(height: 16),
            if (_listening)
              Text(
                l.driverListening,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.sand,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        actions: [
          PrimaryPill(
            label: l.testDriveYes,
            style: style,
            height: 96,
            color: AppColors.sage,
            onTap: () => _answer(true),
          ),
          SecondaryPill(
            label: l.testDriveNo,
            style: style,
            height: 80,
            onTap: () => _answer(false),
          ),
        ],
      ),
      _Step.yes || _Step.no || _Step.notHeard => MomentLayout(
        style: style,
        top: Column(
          children: [
            Icon(
              _step == _Step.notHeard
                  ? Icons.mic_off_rounded
                  : Icons.check_circle_rounded,
              size: 80,
              color: _step == _Step.notHeard ? AppColors.sand : AppColors.sage,
            ),
            const SizedBox(height: 24),
            MomentText(switch (_step) {
              _Step.yes => l.testDriveYesTitle,
              _Step.no => l.testDriveNoTitle,
              _ => l.testDriveNotHeardTitle,
            }, style: style),
            const SizedBox(height: 12),
            MomentText(
              switch (_step) {
                _Step.yes => l.testDriveYesBody,
                _Step.no => l.testDriveNoBody,
                _ => l.testDriveNotHeardBody,
              },
              size: 17,
              soft: true,
              style: style,
            ),
          ],
        ),
        actions: [
          PrimaryPill(
            label: l.testDriveDone,
            style: style,
            onTap: () => Navigator.of(context).pop(),
          ),
          SecondaryPill(label: l.testDriveAgain, style: style, onTap: _start),
        ],
      ),
    };
  }
}
