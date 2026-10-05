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

/// Whole answers we accept — nothing else. "Yes… actually no", "let's not
/// talk", "sure, but not now" or two voices are not clear answers, so
/// nothing happens (the big buttons are always there).
const _yesPhrases = {
  'כן',
  'כן כן',
  'כן בטח',
  'בטח',
  'יאללה',
  'כן יאללה',
  'בוא נדבר',
  'כן בוא נדבר',
  'בואי נדבר',
  'כן בואי נדבר',
  'תתקשר',
  'כן תתקשר',
  'yes',
  'ok',
  'okay',
};
const _noPhrases = {
  'לא',
  'לא לא',
  'לא עכשיו',
  'לא תודה',
  'תודה לא',
  'אחר כך',
  'לא כרגע',
  'בטל',
  'no',
  'not now',
};
const _fillers = {'אה', 'אמ', 'אממ', 'אהה', 'אוקיי'};

VoiceAnswer parseYesNo(String heard) {
  final words = heard
      .toLowerCase()
      .replaceAll(RegExp(r'[.,!?…:;"׳״\-]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  // Leading "uh"/"um" don't change the answer.
  while (words.isNotEmpty && _fillers.contains(words.first)) {
    words.removeAt(0);
  }
  final t = words.join(' ');
  if (t.isEmpty) return VoiceAnswer.none;
  if (_yesPhrases.contains(t)) return VoiceAnswer.yes;
  if (_noPhrases.contains(t)) return VoiceAnswer.no;
  return VoiceAnswer.none;
}

class DeviceVoiceService implements VoiceService {
  final _tts = FlutterTts();
  final _stt = SpeechToText();
  bool? _sttReady;
  bool _onDeviceFailed = false;
  bool _heardSomething = false;
  Completer<VoiceAnswer>? _pending;
  VoiceAnswer? _simulatedNext;

  bool _configured = false;

  /// Short, brisk, slightly faster than default, with a Hebrew voice that
  /// runs on the phone itself when there is one.
  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.setLanguage('he-IL');
    await _tts.setSpeechRate(0.58); // 0.5 = normal on Android
    await _tts.setPitch(1.05);
    await _tts.awaitSpeakCompletion(true);
    try {
      final voices = await _tts.getVoices as List?;
      final hebrew = [
        for (final v in voices ?? const [])
          if (v is Map && '${v['locale']}'.toLowerCase().startsWith('he')) v,
      ];
      if (hebrew.isEmpty) return;
      // Prefer voices that work on the phone itself (nothing sent out).
      hebrew.sort((a, b) => _voiceScore(b).compareTo(_voiceScore(a)));
      final best = hebrew.first;
      await _tts.setVoice({
        'name': '${best['name']}',
        'locale': '${best['locale']}',
      });
    } catch (_) {
      // Keep the engine's default Hebrew voice.
    }
  }

  static int _voiceScore(Map<dynamic, dynamic> v) {
    final name = '${v['name']}'.toLowerCase();
    var score = 0;
    if (name.contains('local')) score += 2;
    if (name.contains('network')) score -= 2;
    if ('${v['quality']}'.toLowerCase().contains('high')) score += 1;
    return score;
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _configure();
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
      _heardSomething = false;
      _sttReady ??= await _stt.initialize(
        onError: (e) {
          // No offline Hebrew model: next time use the phone's recognizer.
          final m = e.errorMsg.toLowerCase();
          if (!_heardSomething &&
              (m.contains('language') ||
                  m.contains('server') ||
                  m.contains('network') ||
                  m.contains('not_supported'))) {
            _onDeviceFailed = true;
          }
          final p = _pending;
          if (p != null && !p.isCompleted) p.complete(VoiceAnswer.none);
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
          // Only the finished sentence counts ("yes… actually no").
          partialResults: false,
          cancelOnError: true,
          // On the phone itself when it can; otherwise the phone's own
          // recognizer service (see the privacy policy).
          onDevice: !_onDeviceFailed,
        ),
        onResult: (r) {
          if (!r.finalResult || completer.isCompleted) return;
          _heardSomething = true;
          completer.complete(parseYesNo(r.recognizedWords));
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
