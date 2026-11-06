// Accessibility minimum (owner, 2026-11-06; IS 5568 basics): every button
// has a name for the screen reader, tap targets are big enough, and the
// main screens survive the phone's largest text.
import 'package:drivetalk/app/app.dart';
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/features/real/real_root.dart';
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

Future<void> _app(WidgetTester t, {required int tab, double text = 1}) async {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.6;
  t.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  final server = MemoryServer();
  final me = MemoryRealBackend(server);
  await t.runAsync(() async {
    await me.signIn('נתנאל', Gender.male);
    await me.setMyPhone('0521111111');
    final f = MemoryRealBackend(server);
    await f.signIn('מיכל', Gender.female);
    await f.setMyPhone('0543333333');
    final inv = await me.createInvitation();
    await f.acceptInvitation(inv.token);
    await f.setAvailability(AvailabilityMode.driving, 25);
  });
  final store = MemoryLocalStore()
    ..values['real.contactsSyncedAt'] = DateTime.now().toIso8601String()
    ..values['real.genderAsked.v1'] = 'yes';
  RealShell.debugInitialTab = tab;
  addTearDown(() => RealShell.debugInitialTab = 0);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        realBackendProvider.overrideWithValue(me),
        localStoreProvider.overrideWithValue(store),
        voiceServiceProvider.overrideWithValue(SilentVoiceService()),
        incomingLinksProvider.overrideWithValue(const Stream.empty()),
        contactsReaderProvider.overrideWithValue(FakeContactsReader()),
        drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
      ],
      child: const DriveTalkApp(),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Down the whole screen, a check at each step.
Future<void> _scrollThrough(
  WidgetTester t,
  Future<void> Function() check,
) async {
  await check();
  for (var i = 0; i < 10; i++) {
    final list = find.byType(Scrollable).first;
    await t.drag(list, const Offset(0, -500));
    await t.pump(const Duration(milliseconds: 300));
    await check();
  }
}

void main() {
  for (final (tab, name, marker) in [
    (0, 'Home', 'נתנאל'),
    (1, 'My people', 'הוספת חבר'),
    (2, 'Settings', 'שפה · Language'),
  ]) {
    testWidgets('$name: every button has a name; targets big enough', (
      t,
    ) async {
      final h = t.ensureSemantics();
      await _app(t, tab: tab);
      expect(find.textContaining(marker), findsWidgets, reason: 'on $name');
      await _scrollThrough(t, () async {
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
      });
      h.dispose();
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('$name: the largest text still fits', (t) async {
      await _app(t, tab: tab, text: 2);
      expect(find.textContaining(marker), findsWidgets, reason: 'on $name');
      await _scrollThrough(t, () async => expect(t.takeException(), isNull));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('sign-up: names, targets, contrast, largest text', (t) async {
    final h = t.ensureSemantics();
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    for (final text in [1.0, 2.0]) {
      t.platformDispatcher.textScaleFactorTestValue = text;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            realBackendProvider.overrideWithValue(
              MemoryRealBackend(MemoryServer()),
            ),
            localStoreProvider.overrideWithValue(MemoryLocalStore()),
            voiceServiceProvider.overrideWithValue(SilentVoiceService()),
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
      expect(find.text('שוב תקוע בפקק?'), findsOneWidget);
      expect(t.takeException(), isNull);
      // The name step (with "how should we address you?").
      await t.tap(find.text('לדלג'));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(t.takeException(), isNull);
      if (text == 1.0) {
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(textContrastGuideline));
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }
    t.platformDispatcher.clearTextScaleFactorTestValue();
    h.dispose();
  });
}
