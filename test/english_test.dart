// English (1.2.3): the phone's language, or the one chosen in settings.
import 'package:drivetalk/app/app.dart';
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/platform/contacts_reader.dart';
import 'package:drivetalk/platform/driving_detector.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/deep_links.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/memory_backend.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('which language: chosen, else the phone (English or Hebrew)', () {
    expect(appLocale(null, const Locale('en', 'US')), const Locale('en'));
    expect(appLocale(null, const Locale('he', 'IL')), const Locale('he'));
    // Other phone languages: Hebrew (the app's main language).
    expect(appLocale(null, const Locale('ru')), const Locale('he'));
    expect(appLocale('en', const Locale('he')), const Locale('en'));
    expect(appLocale('he', const Locale('en')), const Locale('he'));
  });

  test('the choice is kept with the phone settings', () {
    const p = RealPrefs(language: 'en');
    expect(RealPrefs.fromJson(p.toJson()).language, 'en');
    expect(p.copyWith(language: () => null).language, isNull);
    expect(RealPrefs.fromJson(const {'language': 'fr'}).language, isNull);
  });

  testWidgets('an English phone: English, left to right', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          phoneLocaleProvider.overrideWithValue(const Locale('en', 'US')),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          realBackendProvider.overrideWithValue(
            MemoryRealBackend(MemoryServer()),
          ),
          localStoreProvider.overrideWithValue(MemoryLocalStore()),
          incomingLinksProvider.overrideWithValue(const Stream.empty()),
          contactsReaderProvider.overrideWithValue(FakeContactsReader()),
          drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
        ],
        child: const DriveTalkApp(),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Stuck in traffic again?'), findsOneWidget);
    expect(
      Directionality.of(t.element(find.byType(Scaffold).first)),
      TextDirection.ltr,
    );
  });

  test('chosen in settings: the voice in the car speaks it', () async {
    final server = MemoryServer();
    final voice = SilentVoiceService();
    final c = ProviderContainer(
      overrides: [
        phoneLocaleProvider.overrideWithValue(const Locale('he', 'IL')),
        voiceServiceProvider.overrideWithValue(voice),
        realBackendProvider.overrideWithValue(MemoryRealBackend(server)),
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        contactsReaderProvider.overrideWithValue(FakeContactsReader()),
        drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
      ],
    );
    addTearDown(c.dispose);
    final ctl = c.read(realProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await ctl.signIn('Dana', Gender.female, phone: '0521111111');
    expect(voiceLanguage, 'he');
    ctl.setPrefs(c.read(realProvider).prefs.copyWith(language: () => 'en'));
    expect(voiceLanguage, 'en');
    ctl.setPrefs(c.read(realProvider).prefs.copyWith(language: () => null));
    expect(voiceLanguage, 'he', reason: 'like the (Hebrew) phone again');
  });
}
