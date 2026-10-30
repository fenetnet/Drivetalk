// The real-mode screens end to end: this phone through the UI, the friend's
// phone through its controller, both against the in-memory server.
import 'package:drivetalk/app/app.dart';
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/platform/contacts_reader.dart';
import 'package:drivetalk/platform/driving_detector.dart';
import 'package:drivetalk/platform/google_auth.dart';
import 'package:drivetalk/platform/phone_dialer.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/deep_links.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/memory_backend.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'no_server.dart';

/// No phone here: calls become the in-app call; permission never given.
class _NoPhone extends PhoneDialer {
  @override
  Future<DialResult> call(String number, {bool direct = true}) async =>
      DialResult.unsupported;
}

Future<void> pumpFor(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'join → friend found from contacts → both free → talk → feedback',
    (t) async {
      t.view.physicalSize = const Size(1080, 2340);
      t.view.devicePixelRatio = 2.6;
      addTearDown(t.view.reset);

      final server = MemoryServer();
      final store = MemoryLocalStore();
      final detector = FakeDrivingDetector();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            phoneDialerProvider.overrideWithValue(_NoPhone()),
            voiceServiceProvider.overrideWithValue(SilentVoiceService()),
            realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
            localStoreProvider.overrideWithValue(store),
            incomingLinksProvider.overrideWithValue(const Stream.empty()),
            inviteBaseUrlProvider.overrideWithValue('https://invite.example'),
            contactsReaderProvider.overrideWithValue(
              FakeContactsReader(numbers: ['053-222-2222']),
            ),
            drivingDetectorProvider.overrideWithValue(detector),
          ],
          child: const DriveTalkApp(),
        ),
      );
      await pumpFor(t, 300);

      // Three short photo pages (owner), then a name, then the
      // number (required).
      expect(find.text('שוב תקוע בפקק?'), findsOneWidget);
      expect(
        Directionality.of(t.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
      await t.tap(find.text('הבא'));
      await pumpFor(t, 300);
      expect(find.text('חברה יוצאת לדרך'), findsOneWidget);
      expect(find.text('DriveBond זיהתה: שניכם פנויים עכשיו'), findsOneWidget);
      await t.tap(find.text('הבא'));
      await pumpFor(t, 300);
      expect(find.text('פתאום הפקק\nעובר בכיף.'), findsOneWidget);
      await t.tap(find.text('בואו נתחיל'));
      await pumpFor(t, 300);
      expect(find.text('הזמן בדרך –\nעם האנשים שלך.'), findsOneWidget);
      expect(find.text('מה זה DriveBond?'), findsOneWidget);
      // Android back: to the pictures, not out of the app (review D-164).
      await t.binding.handlePopRoute();
      await pumpFor(t, 300);
      expect(find.text('שוב תקוע בפקק?'), findsOneWidget);
      await t.tap(find.text('לדלג'));
      await pumpFor(t, 300);
      await t.enterText(find.byType(TextField).first, 'נתנאל');
      await t.pump();
      await t.tap(find.text('המשך'));
      await pumpFor(t, 300);
      expect(find.text('מה המספר שלך?'), findsOneWidget);
      // Back from the number: the name step, the name kept.
      await t.binding.handlePopRoute();
      await pumpFor(t, 300);
      expect(find.text('הזמן בדרך –\nעם האנשים שלך.'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'נתנאל'), findsOneWidget);
      await t.tap(find.text('המשך'));
      await pumpFor(t, 300);
      expect(find.text('מה המספר שלך?'), findsOneWidget);
      // No number → can't join yet.
      await t.tap(find.text('יאללה'));
      await pumpFor(t, 300);
      expect(find.text('מה המספר שלך?'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '0521234567');
      await t.pump();
      await t.tap(find.text('יאללה'));
      await pumpFor(t, 500);
      // First steps: a picture (optional, says where to add it later) →
      // look for my people → nobody yet → how it works.
      expect(find.text('תמונה, כדי שיזהו אותך'), findsOneWidget);
      expect(find.textContaining('הגדרות ← לחיצה על השם שלך'), findsOneWidget);
      await t.tap(find.text('אחר כך'));
      await pumpFor(t, 300);
      expect(find.text('נראה מי מהאנשים שלך כבר כאן'), findsOneWidget);
      await t.tap(find.text('לחפש באנשי הקשר'));
      await pumpFor(t, 500);
      expect(
        find.text('כדי לנסות את DriveBond צריך לפחות חבר אחד'),
        findsOneWidget,
      );
      await t.tap(find.text('אחר כך'));
      await pumpFor(t, 300);
      // When am I usually on the road? Morning → a routine Sun–Thu.
      expect(find.text('באילו שעות יש לך בדרך כלל נסיעה?'), findsOneWidget);
      await t.tap(find.text('בוקר · 07:30 · בדרך לעבודה'));
      await pumpFor(t, 100);
      await t.tap(find.text('הבא'));
      await pumpFor(t, 300);
      // All the permissions at once (here: later).
      expect(find.text('כדי שזה יעבוד גם בנסיעה'), findsOneWidget);
      await t.tap(find.text('אחר כך'));
      await pumpFor(t, 300);
      // Automatic availability: on unless I turn it off, then the car
      // (owner, D-161).
      expect(find.text('זמין אוטומטית בכל נסיעה'), findsOneWidget);
      await t.tap(find.text('Car Audio'));
      await pumpFor(t, 100);
      await t.tap(find.text('הבא'));
      await pumpFor(t, 500);
      expect(detector.enabled, isTrue);
      expect(detector.cars.single.$2, 'Car Audio');
      expect(find.text('ככה זה עובד'), findsOneWidget);
      await t.tap(find.text('יאללה'));
      await pumpFor(t, 300);
      expect(find.text('נתנאל, עם מי\nמדברים היום?'), findsOneWidget);
      expect(find.text('עוד אין פה חברים'), findsOneWidget);

      // The friend (another phone) joins; we have each other's numbers.
      final yoni = ProviderContainer(
        overrides: [
          realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          contactsReaderProvider.overrideWithValue(
            FakeContactsReader(numbers: ['0521234567']),
          ),
          drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
        ],
      );
      final y = yoni.read(realProvider.notifier);
      await t.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
        await y.signIn('יוני', Gender.male, phone: '0532222222');
        await y.firstRunFindPeople();
        // Yoni picks me from his contacts → connected at once.
        await y.addContacts(y.contactMatches);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await pumpFor(t, 800);
      // No code, no invitation: we're connected — told at the top (1.1.2).
      expect(find.textContaining('יוני'), findsWidgets);
      await t.scrollUntilVisible(
        find.text(
          'כרגע אף חבר לא פנוי. כשמישהו יסמן שיש לו זמן, הוא יופיע כאן.',
        ),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'כרגע אף חבר לא פנוי. כשמישהו יסמן שיש לו זמן, הוא יופיע כאן.',
        ),
        findsOneWidget,
      );

      // Yoni becomes free → I see him.
      await t.runAsync(() => y.startAvailability(AvailabilityMode.walking, 20));
      await pumpFor(t, 600);
      expect(find.text('יוני'), findsOneWidget);

      // I become free → both are asked.
      // One tap, 30 minutes (D-156): "I have time".
      await t.scrollUntilVisible(
        find.text('יש לי זמן'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await pumpFor(t, 300);
      await t.tap(find.text('יש לי זמן'));
      await pumpFor(t, 500);
      // The first time: one short note about the phone's questions.
      if (find.text('הבנתי, ממשיכים').evaluate().isNotEmpty) {
        await t.tap(find.text('הבנתי, ממשיכים'));
        await pumpFor(t, 500);
      }
      await pumpFor(t, 800);
      expect(find.text('ליוני יש זמן עכשיו'), findsOneWidget);
      expect(find.text('לא עכשיו'), findsOneWidget);

      await t.tap(find.text('לדבר עכשיו'));
      await pumpFor(t, 500);
      expect(find.text('מחכים ליוני…'), findsOneWidget);

      // Yoni says yes too.
      await t.runAsync(() async {
        await y.refresh();
        final offer = currentOffer(yoni.read(realProvider), DateTime.now())!;
        await y.respond(offer, accept: true);
      });
      // Both shared numbers → one side dials after a short countdown (here
      // there is no phone dialer, so it becomes the in-app call).
      await pumpFor(t, 4500);
      // "We're done" (I dialed) or "the call ended" (they called me).
      final done = find.text('סיימנו').evaluate().isNotEmpty
          ? find.text('סיימנו')
          : find.text('השיחה הסתיימה');
      expect(done, findsOneWidget);
      await t.tap(done);
      await pumpFor(t, 500);
      expect(find.text('מתי להציע לך שוב את יוני?'), findsOneWidget);
      await t.tap(find.text('בעוד 3 ימים'));
      await pumpFor(t, 500);
      expect(find.text('תודה!'), findsOneWidget);
      expect(server.feedback, hasLength(1));

      // Friends don't see the test tab; the owner's code opens it.
      expect(find.text('בדיקה'), findsNothing);
      await pumpFor(t, 4500); // the "thanks" message goes away
      // The first talk: a small party, and auto-yes offered (D-159).
      expect(find.text('השיחה הראשונה שלך\nב-DriveBond! 🎉'), findsOneWidget);
      await t.tap(find.text('אחר כך'));
      await pumpFor(t, 400);
      await t.tap(find.text('הגדרות'));
      await pumpFor(t, 400);
      // No visible "admin" button: a long press on the update row asks.
      expect(find.text('ניהול'), findsNothing);
      await t.scrollUntilVisible(
        find.text('בדיקת עדכון'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await pumpFor(t, 400);
      await t.longPress(find.text('בדיקת עדכון'));
      await pumpFor(t, 300);
      await t.enterText(find.byType(TextField).last, '1234');
      await t.tap(find.text('אישור'));
      await pumpFor(t, 300);
      expect(find.text('קוד שגוי'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'test-owner-code');
      await t.tap(find.text('אישור'));
      await pumpFor(t, 300);

      // The test tab shows everything is fine.
      await t.tap(find.text('בדיקה'));
      await pumpFor(t, 400);
      expect(find.text('בדיקה עם חבר'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('להעתיק מידע לבדיקה'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('להעתיק מידע לבדיקה'), findsOneWidget);

      yoni.dispose();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('with Google: the name comes from Google, only the number is '
      'asked', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    final server = MemoryServer();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          phoneDialerProvider.overrideWithValue(_NoPhone()),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          incomingLinksProvider.overrideWithValue(const Stream.empty()),
          contactsReaderProvider.overrideWithValue(FakeContactsReader()),
          drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
          googleAuthProvider.overrideWithValue(
            FakeGoogleAuth(
              token: const GoogleToken(
                'g-dana',
                email: 'd@gmail.com',
                name: 'דנה',
              ),
            ),
          ),
        ],
        child: const DriveTalkApp(),
      ),
    );
    await pumpFor(t, 300);
    await t.tap(find.text('לדלג'));
    await pumpFor(t, 300);
    await t.tap(find.text('המשך עם Google'));
    await pumpFor(t, 500);
    expect(find.text('מה המספר שלך?'), findsOneWidget);
    expect(find.text('השם שיופיע לחברים'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'דנה'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '0521234567');
    await t.pump();
    await t.tap(find.text('יאללה'));
    await pumpFor(t, 500);
    expect(find.text('תמונה, כדי שיזהו אותך'), findsOneWidget);
    final s = ProviderScope.containerOf(t.element(find.byType(Scaffold).first))
        .read(realProvider);
    expect(s.snapshot?.me.name, 'דנה');
    expect(s.myPhone, isNotNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('without a server: says so clearly', (t) async {
    final store = MemoryLocalStore();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          localStoreProvider.overrideWithValue(store),
          realBackendProvider.overrideWithValue(NoServerBackend()),
          incomingLinksProvider.overrideWithValue(const Stream.empty()),
        ],
        child: const DriveTalkApp(),
      ),
    );
    await t.pump();
    expect(find.text('DriveBond עוד לא מחוברת לשרת'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
