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
}
