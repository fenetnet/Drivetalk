// The new cards and screens (D-103…D-106) on a small phone with large
// text: shown, nothing cut off, nothing overflowing.
import 'package:drivetalk/app/app.dart';
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/features/real/real_home.dart';
import 'package:drivetalk/features/real/real_moments.dart';
import 'package:drivetalk/features/real/real_people.dart';
import 'package:drivetalk/features/real/real_permissions.dart';
import 'package:drivetalk/features/real/real_quick.dart';
import 'package:drivetalk/features/real/real_root.dart';
import 'package:drivetalk/features/real/real_about.dart';
import 'package:drivetalk/features/real/real_quiet.dart';
import 'package:drivetalk/real/real_models.dart';
import 'package:drivetalk/features/real/real_settings.dart';
import 'package:drivetalk/l10n/app_localizations.dart';
import 'package:drivetalk/platform/contacts_reader.dart';
import 'package:drivetalk/platform/driving_detector.dart';
import 'package:drivetalk/platform/phone_dialer.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/memory_backend.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:drivetalk/real/update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dials nothing (the call screens only need "it's ringing").
class _QuietDialer extends PhoneDialer {
  @override
  Future<bool> requestDirectCall() async => false;

  @override
  Future<DialResult> call(String number, {bool direct = true}) async =>
      DialResult.calling;
}

ProviderContainer _phone(
  MemoryServer server, {
  FakeDrivingDetector? driving,
  FakeContactsReader? contacts,
  int? latestBuild,
}) => ProviderContainer(
  overrides: [
    if (latestBuild != null) ...[
      appBuildProvider.overrideWithValue(10),
      updateCheckerProvider.overrideWithValue(FakeUpdateChecker(latestBuild)),
    ],
    realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
    realClockProvider.overrideWithValue(server.now),
    localStoreProvider.overrideWithValue(MemoryLocalStore()),
    voiceServiceProvider.overrideWithValue(SilentVoiceService()),
    contactsReaderProvider.overrideWithValue(contacts ?? FakeContactsReader()),
    drivingDetectorProvider.overrideWithValue(driving ?? FakeDrivingDetector()),
    phoneDialerProvider.overrideWithValue(_QuietDialer()),
  ],
);

final _open = <ProviderContainer>[];

/// Close the screen and both phones (no timers left behind).
Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  for (final c in _open) {
    c.dispose();
  }
  _open.clear();
  await t.pump(const Duration(seconds: 1));
}

Future<void> _show(WidgetTester t, ProviderContainer c, Widget body) async {
  // A small phone (320×568) with the text 30% larger.
  t.view.physicalSize = const Size(640, 1136);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: const Locale('he'),
        supportedLocales: const [Locale('he')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(body: body),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  late DateTime now;
  late MemoryServer server;
  setUp(() {
    now = DateTime(2026, 10, 12, 8);
    server = MemoryServer(now: () => now);
  });

  Future<(ProviderContainer, ProviderContainer)> twoFriends(
    WidgetTester t, {
    FakeDrivingDetector? driving,
    int? latestBuild,
  }) async {
    final me = _phone(server, driving: driving, latestBuild: latestBuild);
    final friend = _phone(server);
    _open.addAll([me, friend]);
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      final f = friend.read(realProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await f.signIn('יונתן־אלכסנדר', Gender.male, phone: '0532222222');
      final msg = await c.createInviteMessage();
      f.openInviteText(msg!);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await f.acceptInvite();
      await c.refresh();
    });
    return (me, friend);
  }

  testWidgets('"still free?" after a question I did not answer', (t) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      await friend
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.free, 60);
      await me
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.free, 60);
      now = now.add(const Duration(minutes: 2, seconds: 1));
      server.expireStale();
      await me.read(realProvider.notifier).refresh();
    });
    await _show(t, me, const RealHomeScreen());
    await t.scrollUntilVisible(
      find.text('כן, יש לי זמן'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('כן, יש לי זמן'));
    await t.pump();
    expect(find.text('לא ענית, אז הפסקנו להציע אותך.'), findsOneWidget);
    expect(find.text('כן, יש לי זמן'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a free friend can be tapped; anonymous ones are counted', (
    t,
  ) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      await friend
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.walking, 60);
      await me.read(realProvider.notifier).refresh();
    });
    await _show(t, me, const RealHomeScreen());
    await t.ensureVisible(find.text('יונתן־אלכסנדר'));
    await t.pump();
    expect(
      find.text(
        'רוצים לדבר עם מישהו פנוי? לוחצים עליו, ונשאל אם מתאים לו עכשיו.',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('יונתן־אלכסנדר'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('לדבר עם יונתן־אלכסנדר עכשיו?'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('ביטול'));
    await t.pump(const Duration(milliseconds: 300));

    await t.runAsync(() async {
      await friend.read(realProvider.notifier).setAnonymous(true);
      await me.read(realProvider.notifier).refresh();
    });
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('ועוד חבר אחד פנוי, בלי שם'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a trip starts with quiet minutes (driver screen)', (t) async {
    final driving = FakeDrivingDetector();
    final (me, _) = await twoFriends(t, driving: driving);
    await t.runAsync(() async {
      await me.read(realProvider.notifier).enableAutoDriving();
      server.autoStart(driving.token!);
      await me.read(realProvider.notifier).refresh();
    });
    await _show(t, me, const RealDriverHome());
    expect(find.text('כמה דקות להתארגן'), findsOneWidget);
    expect(find.text('אפשר כבר עכשיו'), findsOneWidget);
    expect(find.text('לא בנסיעה הזו'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('driving: free friends as big circles, one tap asks', (t) async {
    final driving = FakeDrivingDetector();
    final (me, friend) = await twoFriends(t, driving: driving);
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      // No automatic question between us (so the screen stays as is).
      await c.setRating(me.read(realProvider).snapshot!.friends.single, 0);
      await c.enableAutoDriving();
      server.autoStart(driving.token!);
      await c.readyNow();
      await friend
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.breakTime, 60);
      await c.refresh();
    });
    await _show(t, me, const RealDriverHome());
    expect(find.text('מי פנוי עכשיו'), findsOneWidget);
    expect(find.text('יונתן־אלכסנדר'), findsOneWidget);
    expect(find.text('לוחצים על חבר, ונשאל אותו.'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a free friend I can\'t ask now is shown faded', (t) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      final f = friend.read(realProvider.notifier);
      // Yoni doesn't want questions from me (his private choice).
      await f.setRating(friend.read(realProvider).snapshot!.friends.single, 0);
      await f.startAvailability(AvailabilityMode.driving, 60);
      await me.read(realProvider.notifier).refresh();
    });
    await _show(t, me, const RealHomeScreen());
    await t.ensureVisible(find.text('לא כרגע'));
    await t.pump();
    await t.ensureVisible(find.text('יונתן־אלכסנדר'));
    await t.pump();
    expect(find.text('לא כרגע'), findsOneWidget);
    await t.tap(find.text('יונתן־אלכסנדר'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('אי אפשר לפנות ליונתן־אלכסנדר כרגע'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('סגירה'));
    await t.pump(const Duration(milliseconds: 300));
    await _close(t);
  });

  testWidgets('first steps: the permissions, all at once', (t) async {
    final detector = FakeDrivingDetector()
      ..notifications = false
      ..background = false;
    final me = _phone(server, driving: detector);
    _open.add(me);
    await t.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await me
          .read(realProvider.notifier)
          .signIn('נתנאל', Gender.male, phone: '0521111111');
    });
    await _show(t, me, const PermissionsStep());
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('כדי שזה יעבוד גם בנסיעה'), findsOneWidget);
    expect(find.text('זמינות אוטומטית בנסיעה (רשות)'), findsOneWidget);
    expect(find.text('לאשר'), findsNWidgets(4));
    expect(t.takeException(), isNull);

    await t.tap(find.text('לאשר הכול'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 300));
    // Phone calls stay "allow" here (this test phone refuses them).
    expect(find.text('מאושר'), findsNWidgets(3));
    expect(detector.enabled, isFalse, reason: 'driving detection: a choice');
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('settings: clear groups, no "read names" switch', (t) async {
    final (me, _) = await twoFriends(t);
    await _show(t, me, const RealSettingsScreen());
    expect(find.text('להקריא שמות'), findsNothing);
    // Privacy things together; the policy row isn't titled like the group.
    await t.scrollUntilVisible(find.text('מה נשמר עליי'), 200);
    expect(find.text('פרטיות'), findsOneWidget);
    await t.scrollUntilVisible(find.text('הרשאות'), 200);
    expect(t.takeException(), isNull);

    // Permissions from Settings: the driving switch lives in "Driving".
    await t.tap(find.text('הרשאות'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('זמינות אוטומטית בנסיעה (רשות)'), findsNothing);
    await t.scrollUntilVisible(
      find.text('הגדרות ההתראות בטלפון'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('about DriveBond: what is special, every permission and why', (
    t,
  ) async {
    final (me, _) = await twoFriends(t);
    await _show(t, me, const AboutScreen());
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(find.text('שיחה רק כששניכם רוצים'), findsOneWidget);
    await t.scrollUntilVisible(find.text('אנשי קשר'), 200);
    expect(find.text('מאושר'), findsWidgets);
    await t.scrollUntilVisible(find.text('עזרו לנו לשפר'), 200);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('home: me among the free people, and "about" up top', (t) async {
    final (me, _) = await twoFriends(t);
    await _show(t, me, const RealHomeScreen());
    expect(find.byKey(const ValueKey('me-free')), findsNothing);
    await t.runAsync(
      () => me
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.free, 30),
    );
    await t.pump();
    expect(find.byKey(const ValueKey('me-free')), findsOneWidget);
    expect(find.text('אני'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('about')));
    await t.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a car picked: "short stops keep the trip" switch (D-128)', (
    t,
  ) async {
    final driving = FakeDrivingDetector(supported: true);
    final (me, _) = await twoFriends(t, driving: driving);
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      await c.enableAutoDriving();
      await c.setCar('AA:BB', 'Car Audio');
    });
    await _show(t, me, const RealSettingsScreen());
    final sw = find.text('עצירות קצרות לא מסיימות נסיעה');
    await t.scrollUntilVisible(sw, 200);
    await t.ensureVisible(sw);
    await t.pump();
    await t.runAsync(() async {
      await t.tap(sw, warnIfMissed: true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await t.pump();
    expect(driving.shortStops, isTrue);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('quiet hours: several schedules on their own screen (D-124)', (
    t,
  ) async {
    final (me, _) = await twoFriends(t);
    await t.runAsync(
      () => me.read(realProvider.notifier).setQuietRanges(const [
        QuietRange(23 * 60, 6 * 60, 31), // Sunday–Thursday nights
        QuietRange(1 * 60, 9 * 60, 96), // Friday, Saturday
      ]),
    );
    await _show(t, me, const QuietHoursScreen());
    expect(find.text('23:00–06:00'), findsOneWidget);
    expect(find.text('א–ה'), findsOneWidget);
    expect(find.text('01:00–09:00'), findsOneWidget);
    expect(find.text('ו, ש'), findsOneWidget);
    // Delete the weekend one.
    await t.ensureVisible(find.byKey(const ValueKey('quiet-range-1')));
    await t.pump();
    await t.runAsync(() async {
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('quiet-range-1')),
          matching: find.byIcon(Icons.delete_outline_rounded),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await t.pump();
    expect(find.text('01:00–09:00'), findsNothing);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('quiet hours show the chosen days (D-121)', (t) async {
    final (me, _) = await twoFriends(
      t,
      driving: FakeDrivingDetector(supported: true),
    );
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      await c.setQuietHours(22 * 60, 7 * 60, days: (1 << 5) | (1 << 6));
      await c.phonePermissions(); // the phone's driving support, loaded
    });
    await _show(t, me, const RealSettingsScreen());
    final line = find.textContaining('בימים ו, ש, בין השעה 22:00 לשעה 07:00');
    await t.scrollUntilVisible(line, 200);
    expect(line, findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('asking a friend after the card behind changed does not crash', (
    t,
  ) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      await friend
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.free, 30);
      await me.read(realProvider.notifier).refresh();
    });
    final yoni = me.read(realProvider).snapshot!.friends.single;
    expect(server.offers, isEmpty);
    final showCard = ValueNotifier(true);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: me,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          locale: const Locale('he'),
          supportedLocales: const [Locale('he')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: showCard,
              builder: (_, show, _) => show
                  ? Consumer(
                      builder: (context, ref, _) => TextButton(
                        onPressed: () => askFreeFriend(context, ref, yoni),
                        child: const Text('go'),
                      ),
                    )
                  : const Text('the card moved'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    // The network blinks / a card appears above: this card is rebuilt.
    showCard.value = false;
    await t.pump();
    await t.tap(find.text('כן, לשאול'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    // It went on all the same: I'm free now, and the two of us are asked.
    expect(server.availability[me.read(realProvider).myId], isNotNull);
    expect(server.offers, hasLength(1));
    await _close(t);
  });

  testWidgets('rating a friend twice fast keeps the app on screen', (t) async {
    final (me, _) = await twoFriends(t);
    await _show(t, me, const RealPeopleScreen());
    await t.scrollUntilVisible(
      find.text('יונתן־אלכסנדר'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await t.pumpAndSettle();
    await t.tap(find.text('יונתן־אלכסנדר'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.widgetWithText(ChoiceChip, '4'));
    await t.tap(find.widgetWithText(ChoiceChip, '4'));
    await t.tap(find.widgetWithText(ChoiceChip, '5'), warnIfMissed: false);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    // The card is still open (saved in place), and the list behind it too.
    expect(find.widgetWithText(ChoiceChip, '4'), findsOneWidget);
    expect(find.byType(RealPeopleScreen), findsOneWidget);
    await _close(t);
  });

  testWidgets('quick connect: the switch, the ask card and the intro', (
    t,
  ) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      final f = friend.read(realProvider.notifier);
      await f.setQuick(
        friend.read(realProvider).snapshot!.friends.single,
        true,
      );
      await me.read(realProvider.notifier).refresh();
    });
    final c = me.read(realProvider.notifier);
    final yoni = me.read(realProvider).snapshot!.friends.single;
    expect(c.quickAsk?.id, yoni.id);
    await _show(
      t,
      me,
      SingleChildScrollView(
        child: Column(
          children: [
            QuickAskCard(friend: yoni),
            const QuickIntroCard(),
            QuickSwitch(friend: yoni),
          ],
        ),
      ),
    );
    expect(find.text('יונתן־אלכסנדר רוצה חיבור מהיר איתך'), findsOneWidget);
    expect(find.text('חדש: חיבור מהיר'), findsOneWidget);
    expect(find.text('חיבור מהיר'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.byType(Switch));
    await t.tap(find.byType(Switch));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('חיבור מהיר עם יונתן־אלכסנדר?'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('להפעיל'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(me.read(realProvider).snapshot!.quickBoth(yoni.id), isTrue);
    await _close(t);
  });

  testWidgets(
    'picking minutes after the screen behind changed does not crash',
    (t) async {
      final me = _phone(server, driving: FakeDrivingDetector(supported: false));
      _open.add(me);
      await t.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
        await me
            .read(realProvider.notifier)
            .signIn('נתנאל', Gender.male, phone: '0521111111');
      });
      final showButton = ValueNotifier(true);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: me,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            locale: const Locale('he'),
            supportedLocales: const [Locale('he')],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: showButton,
                builder: (_, show, _) => show
                    ? Consumer(
                        builder: (context, ref, _) => TextButton(
                          onPressed: () => openRealDuration(
                            context,
                            ref,
                            AvailabilityMode.driving,
                          ),
                          child: const Text('go'),
                        ),
                      )
                    : const Text('another screen'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      // A trip starts / a question arrives: the screen behind changes.
      showButton.value = false;
      await t.pump();
      await t.ensureVisible(find.text('30 דק׳'));
      await t.tap(find.text('30 דק׳'));
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await me.read(realProvider.notifier).refresh();
      });
      await t.pump();
      expect(me.read(realProvider).snapshot?.mine, isNotNull);
      await _close(t);
    },
  );

  testWidgets('quick connect from the friend card: the switch stays on', (
    t,
  ) async {
    final (me, _) = await twoFriends(t);
    await _show(t, me, const RealPeopleScreen());
    await t.scrollUntilVisible(
      find.text('יונתן־אלכסנדר'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // A bit more, so the whole card is on screen (not under the edge).
    await t.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await t.pumpAndSettle();
    await t.tap(find.text('יונתן־אלכסנדר'));
    await t.pumpAndSettle();
    final sw = find.byType(Switch).first;
    expect(t.widget<Switch>(sw).value, isFalse);
    await t.tap(sw);
    await t.pumpAndSettle();
    await t.tap(find.text('להפעיל'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    expect(t.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(
      find.text('מופעל אצלך. יעבוד כשזה יופעל גם אצל יונתן־אלכסנדר.'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a quick-connect request shows even with "update available"', (
    t,
  ) async {
    final (me, friend) = await twoFriends(t, latestBuild: 999);
    await t.runAsync(() async {
      await friend
          .read(realProvider.notifier)
          .setQuick(friend.read(realProvider).snapshot!.friends.single, true);
      final c = me.read(realProvider.notifier);
      await c.checkForUpdate(force: true);
      await c.refresh();
    });
    expect(me.read(realProvider).newBuild, 999);
    await _show(t, me, const RealHomeScreen());
    await t.scrollUntilVisible(
      find.text('יונתן־אלכסנדר רוצה חיבור מהיר איתך'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('יונתן־אלכסנדר רוצה חיבור מהיר איתך'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a friend card shows my pause, and "cancel" removes it', (
    t,
  ) async {
    final (me, friend) = await twoFriends(t);
    final yoni = me.read(realProvider).snapshot!.friends.single;
    final myId = friend.read(realProvider).snapshot!.friends.single.id;
    server.snoozes['$myId|${yoni.id}'] = now.add(const Duration(days: 3));
    await t.runAsync(() => me.read(realProvider.notifier).refresh());
    await _show(t, me, PauseTile(friend: yoni));
    expect(find.text('הצעות מושהות עד יום ה׳'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('לבטל'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('לבטל'), findsNothing);
    expect(server.snoozes, isEmpty);
    await _close(t);
  });

  testWidgets('during a call: to the main screen and back', (t) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      final f = friend.read(realProvider.notifier);
      await c.startAvailability(AvailabilityMode.free, 60);
      await f.startAvailability(AvailabilityMode.free, 60);
      await f.refresh();
      await c.refresh();
      final now0 = server.now();
      await c.respond(currentOffer(me.read(realProvider), now0)!, accept: true);
      await f.respond(
        currentOffer(friend.read(realProvider), now0)!,
        accept: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await c.refresh();
      await f.refresh();
    });
    // Whoever waits for the other's call.
    final waiter =
        me.read(realProvider).callStage == CallStage.waitingForTheirCall
        ? me
        : friend;
    expect(waiter.read(realProvider).callStage, CallStage.waitingForTheirCall);
    await _show(t, waiter, const RealRoot());
    expect(find.text('לא הגיעה שיחה'), findsOneWidget);

    await t.tap(find.text('למסך הראשי'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('לא הגיעה שיחה'), findsNothing);
    expect(find.textContaining('חזרה למסך השיחה'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.tap(find.textContaining('חזרה למסך השיחה'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('לא הגיעה שיחה'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('a friend who tapped me: "X wants to talk with you"', (t) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      final f = friend.read(realProvider.notifier);
      // No automatic question between us: only the tap. (Yoni's own
      // rating stops the app's suggestions, never his own tap.)
      await f.setRating(friend.read(realProvider).snapshot!.friends.single, 0);
      await c.startAvailability(AvailabilityMode.free, 60);
      await f.startAvailability(AvailabilityMode.free, 60);
      await f.askFriend(friend.read(realProvider).snapshot!.friends.single);
      await c.refresh();
    });
    final offer = currentOffer(me.read(realProvider), now)!;
    await _show(t, me, RealOfferScreen(offer: offer, dark: false));
    expect(find.text('יונתן־אלכסנדר רוצה לדבר איתך'), findsOneWidget);
    expect(find.text('מתאים לך עכשיו?'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('the question says how long both are free', (t) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      await friend
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.free, 25);
      await me
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.free, 60);
    });
    final offer = currentOffer(me.read(realProvider), now)!;
    await _show(t, me, RealOfferScreen(offer: offer, dark: false));
    expect(
      find.text('שניכם פנויים עוד כ-25 דק׳ · זו תהיה השיחה הראשונה שלכם כאן'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('waiting for their answer shows the seconds left', (t) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      await friend
          .read(realProvider.notifier)
          .startAvailability(AvailabilityMode.free, 60);
      await c.startAvailability(AvailabilityMode.free, 60);
      await c.respond(currentOffer(me.read(realProvider), now)!, accept: true);
    });
    final offer = waitingOffer(me.read(realProvider), now)!;
    await _show(t, me, RealWaitingScreen(offer: offer, dark: false));
    expect(find.text('עוד 25 שניות'), findsOneWidget);
    now = now.add(const Duration(seconds: 10));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('עוד 15 שניות'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });

  testWidgets('after a call: a warm line and a way to write to us', (t) async {
    final (me, friend) = await twoFriends(t);
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      final f = friend.read(realProvider.notifier);
      await c.startAvailability(AvailabilityMode.free, 60);
      await f.startAvailability(AvailabilityMode.free, 60);
      await f.refresh();
      await c.refresh();
      final now0 = server.now();
      await c.respond(currentOffer(me.read(realProvider), now0)!, accept: true);
      await f.respond(
        currentOffer(friend.read(realProvider), now0)!,
        accept: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await c.refresh();
      c.finishCall();
    });
    expect(me.read(realProvider).callStage, CallStage.feedback);
    await _show(t, me, const RealFeedbackScreen());
    expect(find.text('מקווים שהשיחה הייתה טובה 🙂'), findsOneWidget);
    final write = find.text('יש משוב או תובנה? אפשר לכתוב לנו, ונשפר');
    await t.scrollUntilVisible(write, 200);
    await t.ensureVisible(write);
    await t.pump();
    await t.tap(write);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('שליחת משוב'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('ביטול'));
    await t.pump(const Duration(milliseconds: 300));
    await _close(t);
  });

  testWidgets('one "add a friend" button with all the ways', (t) async {
    final (me, _) = await twoFriends(t);
    await _show(t, me, const RealPeopleScreen());
    await t.tap(find.text('הוספת חבר'));
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('חיפוש באנשי הקשר'), findsOneWidget);
    expect(find.text('להזמין חבר'), findsOneWidget);
    expect(find.text('יש לי קוד הזמנה'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('יש לי קוד הזמנה'));
    await t.pump();
    await t.tap(find.text('יש לי קוד הזמנה'));
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    // The code sheet opened (its title), the menu closed.
    expect(find.text('חיפוש באנשי הקשר'), findsNothing);
    expect(find.text('יש לי קוד הזמנה'), findsOneWidget);
    expect(t.takeException(), isNull);
    await _close(t);
  });
}
