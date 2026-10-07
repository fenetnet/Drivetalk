// The real-mode screens end to end: this phone through the UI, the friend's
// phone through its controller, both against the in-memory server.
import 'package:drivetalk/app/app.dart';
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/platform/contacts_reader.dart';
import 'package:drivetalk/platform/driving_detector.dart';
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
            drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
          ],
          child: const DriveTalkApp(),
        ),
      );
      await pumpFor(t, 300);

      // Join: just a name.
      expect(find.text('זמן מת?\nשיחה טובה.'), findsOneWidget);
      expect(
        Directionality.of(t.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
      await t.enterText(find.byType(TextField).first, 'נתנאל');
      await t.enterText(find.byType(TextField).at(1), '0521234567');
      await t.pump();
      await t.tap(find.text('יאללה'));
      await pumpFor(t, 500);
      // First steps: look for my people → nobody yet → how it works.
      expect(find.text('נראה מי מהאנשים שלך כבר כאן'), findsOneWidget);
      await t.tap(find.text('לחפש באנשי הקשר'));
      await pumpFor(t, 500);
      expect(
        find.text('כדי לנסות את DriveTalk צריך לפחות חבר אחד'),
        findsOneWidget,
      );
      await t.tap(find.text('אחר כך'));
      await pumpFor(t, 300);
      // When am I usually on the road? Morning → a routine Sun–Thu.
      expect(find.text('מתי בדרך כלל יש לך זמן בדרך?'), findsOneWidget);
      await t.tap(find.text('בוקר · 07:30 · בדרך לעבודה'));
      await pumpFor(t, 100);
      await t.tap(find.text('הבא'));
      await pumpFor(t, 300);
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
      // No code, no invitation: we're connected.
      expect(
        find.text('יש לך 20 דקות? לוחצים "יש לי זמן" ונחפש עם מי לדבר.'),
        findsOneWidget,
      );

      // Yoni becomes free → I see him.
      await t.runAsync(() => y.startAvailability(AvailabilityMode.walking, 20));
      await pumpFor(t, 600);
      expect(find.text('יוני'), findsOneWidget);

      // I become free → both are asked.
      await t.tap(find.text('יש לי זמן עכשיו'));
      await pumpFor(t, 500);
      await t.tap(find.text('סתם זמן פנוי'));
      await pumpFor(t, 500);
      await t.tap(find.text('30 דק׳'));
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
      expect(find.text('סיימנו'), findsOneWidget);
      await t.tap(find.text('סיימנו'));
      await pumpFor(t, 500);
      expect(find.text('היה טוב'), findsOneWidget);
      await t.tap(find.text('היה טוב'));
      await pumpFor(t, 500);
      expect(find.text('תודה!'), findsOneWidget);
      expect(server.feedback, hasLength(1));

      // Friends don't see the test tab; the owner's code opens it.
      expect(find.text('בדיקה'), findsNothing);
      await pumpFor(t, 4500); // the "thanks" message goes away
      await t.tap(find.text('הגדרות'));
      await pumpFor(t, 400);
      // "Admin" is at the very bottom.
      await t.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await pumpFor(t, 400);
      await t.tap(find.text('ניהול'));
      await pumpFor(t, 300);
      await t.enterText(find.byType(TextField).last, '1234');
      await t.tap(find.text('אישור'));
      await pumpFor(t, 300);
      expect(find.text('קוד שגוי'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, '97869786');
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
    expect(find.text('הבדיקה עם חבר עוד לא מחוברת'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
