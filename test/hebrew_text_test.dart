import 'package:drivetalk/domain/hebrew_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a Hebrew prefix before an English name gets a hyphen', () {
    expect(joinHebrewPrefixes('מתחברים לDani…'), 'מתחברים ל-Dani…');
    expect(joinHebrewPrefixes('ולDani יש זמן'), 'ול-Dani יש זמן');
    expect(joinHebrewPrefixes('מתחברים לדני…'), 'מתחברים לדני…');
    expect(joinHebrewPrefixes('יוני Dani'), 'יוני Dani');
    expect(joinHebrewPrefixes('לא עכשיו'), 'לא עכשיו');
  });
}
