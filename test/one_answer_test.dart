import 'package:drivetalk/real/supabase_backend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Server 78 (D-173): the one answer is split back into the same parts, in
/// the same order, as the ~20 separate requests gave.
void main() {
  test('the one answer becomes the same parts as the separate requests', () {
    final parts = SupabaseRealBackend.oneAnswerParts({
      'profiles': [
        {'id': 'me', 'display_name': 'אני'},
      ],
      'availability': [
        {'user_id': 'yoni', 'mode': 'free'},
      ],
      'offers': [],
      'talks': [],
      'intents': [],
      'circles': [
        {
          'id': 'c1',
          'name': 'משפחה',
          'circle_members': [
            {'member': 'yoni'},
          ],
        },
      ],
      'ratings': [
        {'friend': 'yoni', 'rating': 3},
      ],
      'activity': [],
      'hide': [
        {'hide_status': false},
      ],
      'others': [],
      'askable': ['yoni'],
      'status': {'asks_today': 1},
      'quick': [],
      'pauses': [],
      'mine': [],
      'auto_yes': {'on': true, 'min': 3},
      'usual': null,
    });
    expect(parts, hasLength(17));
    expect(parts[0].single['id'], 'me');
    expect(parts[1].single['user_id'], 'yoni');
    expect((parts[5].single['circle_members'] as List).single, {
      'member': 'yoni',
    });
    expect(parts[6].single['rating'], 3);
    expect(parts[8].single['hide_status'], false);
    expect(parts[10], [
      {'id': 'yoni'},
    ]);
    expect(parts[11].single['asks_today'], 1);
    expect(parts[15].single['on'], true);
    expect(parts[16], isEmpty, reason: 'a missing part is simply empty');
  });

  test('no status from the server: an empty part, as before', () {
    final parts = SupabaseRealBackend.oneAnswerParts({});
    expect(parts, hasLength(17));
    expect(parts.every((p) => p.isEmpty), isTrue);
  });
}
