import 'package:drivetalk/app/app.dart';
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/services/fake/fake_world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_flow_test.dart' show config;

Future<void> pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('onboarding → home (RTL) → I am free → suggestion with reasons', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);

    final world = FakeWorld()..answerDelaySeconds = 1;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          matchingConfigProvider.overrideWithValue(config),
          fakeWorldProvider.overrideWithValue(world),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
        ],
        child: const DriveTalkApp(),
      ),
    );
    await t.pump();

    // Hebrew, right-to-left.
    final dir = Directionality.of(t.element(find.byType(Scaffold).first));
    expect(dir, TextDirection.rtl);

    // Onboarding: 3 info pages, then setup.
    for (var i = 0; i < 3; i++) {
      await t.tap(find.text('המשך'));
      await pumpFor(t, 500);
    }
    final start = find.widgetWithText(FilledButton, 'בואו נתחיל');
    await t.enterText(find.byType(TextField), 'נתנאל');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await t.tap(start);
    await pumpFor(t, 500);

    // Home.
    expect(find.text('שלום נתנאל'), findsOneWidget);
    await t.tap(find.textContaining('עכשיו').first);
    await pumpFor(t, 500);

    // Mode → duration.
    await t.tap(find.text('הליכה'));
    await pumpFor(t, 500);
    await t.tap(find.text('30 דק׳'));
    await pumpFor(t, 500);
    expect(find.text('מחפשים מישהו שמתאים לדבר איתך עכשיו'), findsOneWidget);

    // Three options appear, each with its own "talk now".
    await pumpFor(t, 2500);
    expect(find.text('3 אנשים פנויים לדבר עכשיו'), findsOneWidget);
    expect(find.text('לדבר עכשיו'), findsNWidgets(3));

    // Per-person menu: not today / don't suggest / block / report.
    await t.tap(find.byIcon(Icons.more_vert_rounded).first);
    await pumpFor(t, 400);
    expect(find.text('לא היום'), findsOneWidget);
    expect(find.text('לא להציע בתקופה הקרובה'), findsOneWidget);
    expect(find.text('חסימה'), findsOneWidget);
    expect(find.text('דיווח'), findsOneWidget);

    // Leave cleanly.
    world.reset();
    await t.pumpWidget(const SizedBox());
  });
}
