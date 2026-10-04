// The real-mode screens end to end: this phone through the UI, the friend's
// phone through its controller, both against the in-memory server.
import 'package:drivetalk/app/app.dart';
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/deep_links.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/memory_backend.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'no_server.dart';
import 'session_flow_test.dart' show config;

Future<void> pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('join → invitation code → both free → talk → feedback', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);

    final server = MemoryServer();
    final store = MemoryLocalStore()..values['app.mode'] = 'real';
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          matchingConfigProvider.overrideWithValue(config),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
          localStoreProvider.overrideWithValue(store),
          incomingLinksProvider.overrideWithValue(const Stream.empty()),
          inviteBaseUrlProvider.overrideWithValue('https://invite.example'),
        ],
        child: const DriveTalkApp(),
      ),
    );
    await pumpFor(t, 300);

    // Join: just a name.
    expect(find.text('בדיקה עם חבר'), findsOneWidget);
    expect(
      Directionality.of(t.element(find.byType(Scaffold).first)),
      TextDirection.rtl,
    );
    await t.enterText(find.byType(TextField).first, 'נתנאל');
    await t.enterText(find.byType(TextField).at(1), '0521234567');
    await t.pump();
    await t.tap(find.text('יאללה'));
    await pumpFor(t, 500);
    expect(find.text('שלום נתנאל'), findsOneWidget);
    expect(find.text('עוד אין פה חברים'), findsOneWidget);

    // The friend (another phone) joins and sends an invitation.
    final yoni = ProviderContainer(
      overrides: [
        realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        voiceServiceProvider.overrideWithValue(SilentVoiceService()),
        inviteBaseUrlProvider.overrideWithValue('https://invite.example'),
      ],
    );
    final y = yoni.read(realProvider.notifier);
    await t.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await y.signIn('יוני', Gender.male);
    });
    final message = (await t.runAsync(y.createInviteMessage))!;

    // I paste the whole WhatsApp message.
    await t.tap(find.text('יש לי קוד הזמנה'));
    await pumpFor(t, 500);
    await t.enterText(find.byType(TextField).last, message);
    await t.tap(find.text('פתיחה'));
    await pumpFor(t, 500);
    expect(find.text('יוני הזמין אותך'), findsOneWidget);
    await t.tap(find.text('אישור'));
    await pumpFor(t, 600);
    expect(find.text('מעולה! יוני עכשיו ברשימת האנשים שלך.'), findsOneWidget);
    expect(find.text('אף חבר לא פנוי כרגע'), findsOneWidget);

    // Yoni becomes free → I see him.
    await t.runAsync(() => y.startAvailability(AvailabilityMode.walking, 20));
    await pumpFor(t, 600);
    expect(find.text('יוני'), findsOneWidget);

    // I become free → both are asked.
    await t.tap(find.text('אני פנוי עכשיו'));
    await pumpFor(t, 500);
    await t.tap(find.text('סתם פנוי'));
    await pumpFor(t, 500);
    await t.tap(find.text('30 דק׳'));
    await pumpFor(t, 800);
    expect(find.text('יוני פנוי עכשיו. רוצה לדבר?'), findsOneWidget);
    expect(find.text('לא עכשיו'), findsOneWidget);

    await t.tap(find.text('דבר עכשיו'));
    await pumpFor(t, 500);
    expect(find.text('מחכים ליוני…'), findsOneWidget);

    // Yoni says yes too.
    await t.runAsync(() async {
      await y.refresh();
      final offer = currentOffer(yoni.read(realProvider), DateTime.now())!;
      await y.respond(offer, accept: true);
    });
    await pumpFor(t, 800);
    // I shared my number, Yoni didn't → Yoni calls me.
    expect(find.text('יוני מתקשר אליך עכשיו'), findsOneWidget);
    await t.tap(find.text('סיימנו'));
    await pumpFor(t, 500);
    expect(find.text('מאוד'), findsOneWidget);
    await t.tap(find.text('מאוד'));
    await pumpFor(t, 500);
    expect(find.text('תודה!'), findsOneWidget);
    expect(server.feedback, hasLength(1));

    // The test tab shows everything is fine.
    await t.tap(find.text('בדיקה'));
    await pumpFor(t, 400);
    expect(find.text('בדיקה עם חבר'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('העתק מידע לבדיקה'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('העתק מידע לבדיקה'), findsOneWidget);

    yoni.dispose();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('real mode without a server says so and offers the demo', (
    t,
  ) async {
    final store = MemoryLocalStore()..values['app.mode'] = 'real';
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          matchingConfigProvider.overrideWithValue(config),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          localStoreProvider.overrideWithValue(store),
          realBackendProvider.overrideWithValue(NoServerBackend()),
          incomingLinksProvider.overrideWithValue(const Stream.empty()),
        ],
        child: const DriveTalkApp(),
      ),
    );
    await t.pump();
    expect(find.text('הבדיקה עם חבר עוד לא מחוברת'), findsOneWidget);
    await t.tap(find.text('למצב הדגמה'));
    await pumpFor(t, 300);
    expect(store.values['app.mode'], 'demo');
    await t.pumpWidget(const SizedBox());
  });
}
