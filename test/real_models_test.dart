// Snapshot copies (photos, names from my contacts) keep every field.
import 'dart:typed_data';

import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/real/real_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names from my contacts and photos keep quick connect', () {
    const me = RealProfile(id: 'me', name: 'נתנאל', gender: Gender.male);
    const yoni = RealProfile(
      id: 'y',
      name: 'Yoni',
      gender: Gender.male,
      photoVersion: 1,
    );
    final snap = RealSnapshot(
      me: me,
      friends: const [yoni],
      availability: const {},
      offers: const [],
      fetchedAt: DateTime(2026),
      askable: const {'y'},
      quickMine: const {'y'},
      quickTheirs: const {'y'},
    );
    final copy = snap.withLocalNames({'y': 'יוני מהעבודה'}).withPhotos({
      'y': Uint8List(3),
    });
    expect(copy.friends.single.name, 'יוני מהעבודה');
    expect(copy.quickMine, {'y'});
    expect(copy.quickTheirs, {'y'});
    expect(copy.quickBoth('y'), isTrue);
    expect(copy.askable, {'y'});
  });
}
