import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceAnswer { yes, no, none, permissionDenied, unavailable }

/// Driving: read things aloud and understand a simple "yes" / "no".
/// Speech recognition runs through the phone's own recognizer; nothing is
/// recorded or stored by the app.
abstract class VoiceService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<VoiceAnswer> listenYesNo({
    Duration timeout = const Duration(seconds: 6),
  });

  /// Debug / tests: answer the current (or next) listen without a microphone.
  void simulateAnswer(VoiceAnswer answer);
}

/// Words we accept. Kept short and forgiving.
const _yesWords = [
  'כן',
  'בטח',
  'יאללה',
  'סבבה',
  'לדבר',
  'בוא',
  'תתקשר',
  'yes',
  'ok',
];
const _noWords = [
  'לא',
  'הבא',
  'אחר כך',
  'בטל',
  'עצור',
  'תודה לא',
  'no',
  'cancel',
];

VoiceAnswer parseYesNo(String heard) {
  final t = heard.trim().toLowerCase();
  if (t.isEmpty) return VoiceAnswer.none;
  // "No" wins if both appear (e.g. "לא, בטח שלא").
  if (_noWords.any(t.contains)) return VoiceAnswer.no;
  if (_yesWords.any(t.contains)) return VoiceAnswer.yes;
  return VoiceAnswer.none;
}

class DeviceVoiceService implements VoiceService {
  final _tts = FlutterTts();
  final _stt = SpeechToText();
  bool? _sttReady;
  Completer<VoiceAnswer>? _pending;
  VoiceAnswer? _simulatedNext;

  @override
  Future<void> speak(String text) async {
    try {
      await _tts.setLanguage('he-IL');
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(text);
    } catch (_) {
      // No TTS engine — the screen still shows everything.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
      if (_stt.isListening) await _stt.stop();
    } catch (_) {}
  }

  @override
  void simulateAnswer(VoiceAnswer answer) {
    final p = _pending;
    if (p != null && !p.isCompleted) {
      p.complete(answer);
    } else {
      _simulatedNext = answer;
    }
  }

  @override
  Future<VoiceAnswer> listenYesNo({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final simulated = _simulatedNext;
    if (simulated != null) {
      _simulatedNext = null;
      return simulated;
    }
    final completer = _pending = Completer<VoiceAnswer>();
    try {
      _sttReady ??= await _stt.initialize(
        onError: (_) {
          if (!completer.isCompleted) completer.complete(VoiceAnswer.none);
        },
      );
      if (_sttReady != true) {
        final denied = !(await _stt.hasPermission);
        return denied ? VoiceAnswer.permissionDenied : VoiceAnswer.unavailable;
      }
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'he_IL',
          listenFor: timeout,
          partialResults: true,
          cancelOnError: true,
          onDevice: false,
        ),
        onResult: (r) {
          final a = parseYesNo(r.recognizedWords);
          if (a != VoiceAnswer.none && !completer.isCompleted) {
            completer.complete(a);
          } else if (r.finalResult && !completer.isCompleted) {
            completer.complete(VoiceAnswer.none);
          }
        },
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(VoiceAnswer.unavailable);
    }
    final answer = await completer.future.timeout(
      timeout + const Duration(seconds: 1),
      onTimeout: () => VoiceAnswer.none,
    );
    try {
      if (_stt.isListening) await _stt.stop();
    } catch (_) {}
    return answer;
  }
}

/// Silent implementation for tests; answers only via [simulateAnswer].
class SilentVoiceService implements VoiceService {
  final spoken = <String>[];
  final _queue = <VoiceAnswer>[];
  Completer<VoiceAnswer>? _pending;

  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}

  @override
  void simulateAnswer(VoiceAnswer answer) {
    final p = _pending;
    if (p != null && !p.isCompleted) {
      p.complete(answer);
    } else {
      _queue.add(answer);
    }
  }

  @override
  Future<VoiceAnswer> listenYesNo({
    Duration timeout = const Duration(seconds: 6),
  }) {
    if (_queue.isNotEmpty) return Future.value(_queue.removeAt(0));
    final c = _pending = Completer<VoiceAnswer>();
    return c.future.timeout(timeout, onTimeout: () => VoiceAnswer.none);
  }
}
