// "Groups" in My people: the wording for each rule, on a small phone with
// large text — nothing cut off, nothing overflowing.
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/features/real/real_circles.dart';
import 'package:drivetalk/l10n/app_localizations.dart';
import 'package:drivetalk/platform/contacts_reader.dart';
import 'package:drivetalk/platform/driving_detector.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/memory_backend.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:drivetalk/real/real_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _phone(MemoryServer server) => ProviderContainer(
  overrides: [
    realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
    localStoreProvider.overrideWithValue(MemoryLocalStore()),
    voiceServiceProvider.overrideWithValue(SilentVoiceService()),
    contactsReaderProvider.overrideWithValue(FakeContactsReader()),
    drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
  ],
);

void main() {
  testWidgets('each group says clearly who sees me free', (t) async {
    // A small phone (320×568) with the text 30% larger.
    t.view.physicalSize = const Size(640, 1136);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);

    final server = MemoryServer();
    final me = _phone(server);
    final friend = _phone(server);
    addTearDown(me.dispose);
    addTearDown(friend.dispose);
    await t.runAsync(() async {
      final c = me.read(realProvider.notifier);
      final f = friend.read(realProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await f.signIn('יוני', Gender.male, phone: '0532222222');
      final msg = await c.createInviteMessage();
      f.openInviteText(msg!);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await f.acceptInvite();
      await c.refresh();
      RealCircle named(String n) => me
          .read(realProvider)
          .snapshot!
          .circles
          .firstWhere((x) => x.name == n);
      await c.setCircleRule(named('עבודה'), ShowRule.never);
      await c.setCircleRule(
        named('משפחה'),
        const ShowRule({AvailabilityMode.driving, AvailabilityMode.walking}),
      );
    });

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: me,
        child: MaterialApp(
          locale: const Locale('he'),
          supportedLocales: const [Locale('he')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: RealCirclesSection(),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));

    expect(
      find.text('בחרו מי מהחברים יראה שאתם פנויים, ובאילו מצבים.'),
      findsOneWidget,
    );
    expect(find.textContaining('רואים שאתם פנויים: בכל מצב'), findsOneWidget);
    expect(
      find.textContaining('רואים שאתם פנויים: בנסיעה, בהליכה'),
      findsOneWidget,
    );
    expect(find.textContaining('הזמינות שלכם מוסתרת מהקבוצה'), findsOneWidget);
    // Wraps instead of cutting: no overflow, no "…".
    expect(t.takeException(), isNull);
    for (final e in find.byType(Text).evaluate()) {
      final w = e.widget as Text;
      expect(w.overflow, isNot(TextOverflow.ellipsis));
    }

    // The group editor asks the question above the choices.
    await t.tap(find.text('משפחה'));
    await t.pump(const Duration(milliseconds: 500));
    expect(
      find.text('מתי חברי הקבוצה יוכלו לראות שאתם פנויים?'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
}
