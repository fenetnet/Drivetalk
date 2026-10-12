// The new cards and screens (D-103…D-106) on a small phone with large
// text: shown, nothing cut off, nothing overflowing.
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/features/real/real_home.dart';
import 'package:drivetalk/features/real/real_moments.dart';
import 'package:drivetalk/l10n/app_localizations.dart';
import 'package:drivetalk/platform/contacts_reader.dart';
import 'package:drivetalk/platform/driving_detector.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/memory_backend.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _phone(
  MemoryServer server, {
  FakeDrivingDetector? driving,
  FakeContactsReader? contacts,
}) => ProviderContainer(
  overrides: [
    realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
    realClockProvider.overrideWithValue(server.now),
    localStoreProvider.overrideWithValue(MemoryLocalStore()),
    voiceServiceProvider.overrideWithValue(SilentVoiceService()),
    contactsReaderProvider.overrideWithValue(contacts ?? FakeContactsReader()),
    drivingDetectorProvider.overrideWithValue(driving ?? FakeDrivingDetector()),
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
  }) async {
    final me = _phone(server, driving: driving);
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
}
