import 'package:drivetalk/platform/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clear spoken answers count; unclear ones do nothing', () {
    for (final yes in ['כן', 'סבבה', 'אוקיי', 'אה, כן בטח', 'ברור!', 'בשמחה']) {
      expect(parseYesNo(yes), VoiceAnswer.yes, reason: yes);
    }
    for (final no in ['לא', 'אני עסוק', 'לא יכולה', 'אוקיי לא עכשיו']) {
      expect(parseYesNo(no), VoiceAnswer.no, reason: no);
    }
    for (final unclear in ['כן... בעצם לא', 'אולי', '']) {
      expect(parseYesNo(unclear), VoiceAnswer.none, reason: unclear);
    }
  });

  test('English answers too (1.2.3)', () {
    for (final yes in [
      'Yes',
      'yeah',
      'Sure!',
      'um, yes please',
      "Let's talk",
    ]) {
      expect(parseYesNo(yes), VoiceAnswer.yes, reason: yes);
    }
    for (final no in ['No', 'nope', 'not now', "I'm busy", 'No thanks.']) {
      expect(parseYesNo(no), VoiceAnswer.no, reason: no);
    }
    for (final unclear in ['yes... actually no', 'maybe']) {
      expect(parseYesNo(unclear), VoiceAnswer.none, reason: unclear);
    }
  });
}
