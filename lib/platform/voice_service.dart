import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/hebrew_text.dart';

enum VoiceAnswer { yes, no, none, permissionDenied, unavailable }

/// Driving: read things aloud and understand a simple "yes" / "no".
/// Speech recognition runs through the phone's own recognizer; nothing is
/// recorded or stored by the app.
abstract class VoiceService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<VoiceAnswer> listenYesNo({
    Duration timeout = const Duration(seconds: 12),
  });

  /// Asks for the microphone now (a calm moment, before driving) so the
  /// question never pops up in the middle of a drive. True when allowed.
  Future<bool> prepare();

  /// Is the microphone already allowed? (Asks nothing.)
  Future<bool> micAllowed();

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
  'סבבה',
  'כן סבבה',
  'אוקיי',
  'ברור',
  'בטח שכן',
  'בשמחה',
  'כן בבקשה',
  'יאללה בוא',
  'יאללה בואי',
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
  'לא יכול',
  'לא יכולה',
  'עסוק',
  'עסוקה',
  'אני עסוק',
  'אני עסוקה',
  'לא מתאים',
  'לא עכשיו תודה',
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
  // "OK" alone is a yes; before other words it's only a filler.
  if (_yesPhrases.contains(words.join(' '))) return VoiceAnswer.yes;
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
  static const _driving = MethodChannel('app.drivetalk/driving');
  final _tts = FlutterTts();

  /// The car's microphone (Bluetooth hands-free) while listening, when
  /// connected (D-130). True when it was switched on.
  Future<bool> _carMic(bool on) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _driving.invokeMethod<bool>('carMic', {'on': on}) ?? false;
    } catch (_) {
      return false;
    }
  }

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
    // Like a navigation app: music / Waze get quieter while we speak.
    try {
      await _tts.setAudioAttributesForNavigation();
    } catch (_) {
      // Not on this platform.
    }
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
      await _tts.speak(joinHebrewPrefixes(text), focus: true);
    } catch (_) {
      // No TTS engine — the screen still shows everything.
    }
  }

  /// Each listen belongs to one round; [stop] starts a new round, so a
  /// listen still on its way never opens the mic afterwards, and an old
  /// one never closes a newer one's mic (or the car's during a call).
  int _round = 0;

  @override
  Future<void> stop() async {
    _round++;
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete(VoiceAnswer.none);
    try {
      await _tts.stop();
      if (_stt.isListening) await _stt.stop();
    } catch (_) {}
    await _carMic(false);
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

  /// Only success is remembered: a refusal can be fixed in settings.
  Future<void> _init() async {
    if (_sttReady == true) return;
    _sttReady = await _stt.initialize(
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
        // Quiet: the phone stopped listening by itself (listen again).
        if (m.contains('no_match') || m.contains('speech_timeout')) {
          _silence = true;
        }
        final p = _pending;
        if (p != null && !p.isCompleted) p.complete(VoiceAnswer.none);
      },
    );
  }

  @override
  Future<bool> prepare() async {
    try {
      await _init();
      return _sttReady == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> micAllowed() async {
    try {
      return await _stt.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<VoiceAnswer> listenYesNo({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final simulated = _simulatedNext;
    if (simulated != null) {
      _simulatedNext = null;
      return simulated;
    }
    final round = _round;
    // Never ask for the microphone here (mid-drive): only [prepare] does.
    try {
      if (_sttReady != true) {
        if (!await _stt.hasPermission) return VoiceAnswer.permissionDenied;
        await _init();
      }
      if (_sttReady != true) {
        final denied = !(await _stt.hasPermission);
        return denied ? VoiceAnswer.permissionDenied : VoiceAnswer.unavailable;
      }
    } catch (_) {
      return VoiceAnswer.unavailable;
    }
    // The car hears better: switch to its microphone (it takes a moment).
    if (await _carMic(true)) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    final deadline = DateTime.now().add(timeout);
    var answer = VoiceAnswer.none;
    var first = true;
    // The phone's recognizer gives up after a few quiet seconds: listen
    // again until the whole time is up — time to think (owner, D-138).
    while (round == _round) {
      final left = deadline.difference(DateTime.now());
      if (left < const Duration(milliseconds: 1500)) break;
      if (first) {
        first = false;
        // "Listening now": a short beep (the screen says it too).
        await _beep();
      }
      _silence = false;
      answer = await _listenOnce(left, round);
      if (answer != VoiceAnswer.none || !_silence) break;
    }
    // Only this round's mic: a newer listen keeps its own.
    if (round == _round) {
      try {
        if (_stt.isListening) await _stt.stop();
      } catch (_) {}
      await _carMic(false);
    }
    return answer;
  }

  /// Nothing was said (the recognizer stopped by itself).
  bool _silence = false;

  Future<void> _beep() async {
    try {
      await _driving.invokeMethod<bool>('beep');
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } catch (_) {
      // No beep on this phone: the screen still shows "listening".
    }
  }

  Future<VoiceAnswer> _listenOnce(Duration timeout, int round) async {
    final completer = _pending = Completer<VoiceAnswer>();
    _heardSomething = false;
    try {
      // Stopped meanwhile (a button, the app went away): never listen.
      if (round != _round || completer.isCompleted) {
        return completer.isCompleted
            ? await completer.future
            : VoiceAnswer.none;
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
    return completer.future.timeout(
      timeout + const Duration(seconds: 1),
      onTimeout: () => VoiceAnswer.none,
    );
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

  /// Tests: was the microphone asked for?
  var prepared = 0;
  @override
  Future<bool> prepare() async {
    prepared++;
    return true;
  }

  @override
  Future<bool> micAllowed() async => prepared > 0;

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
