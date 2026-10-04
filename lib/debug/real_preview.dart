// Design preview of the real mode with made-up friends — for screenshots
// only (never shipped as the app's entry point):
//   flutter build web -t lib/debug/real_preview.dart
//   open …/#home | #offer | #waiting | #connected | #driving | #drivingOffer
//        | #people | #settings | #test | #onboarding | #feedback
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/providers.dart';
import '../domain/models.dart';
import '../features/real/real_root.dart';
import '../matching/matching_config.dart';
import '../platform/contacts_reader.dart';
import '../platform/driving_detector.dart';
import '../platform/voice_service.dart';
import '../real/deep_links.dart';
import '../real/local_store.dart';
import '../real/memory_backend.dart';
import '../real/real_controller.dart';
import '../real/real_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final screen = Uri.base.fragment.isEmpty ? 'home' : Uri.base.fragment;
  final config = MatchingConfig.fromJson(
    jsonDecode(await rootBundle.loadString('assets/config/matching.json'))
        as Map<String, dynamic>,
  );
  final server = MemoryServer();
  final me = MemoryRealBackend(server);
  final store = MemoryLocalStore()..values['app.mode'] = 'real';

  Future<MemoryRealBackend> friend(String name, Gender g, String phone) async {
    final b = MemoryRealBackend(server);
    await b.signIn(name, g);
    await b.setMyPhone(phone);
    return b;
  }

  if (screen != 'onboarding') {
    await me.signIn('נתנאל', Gender.male);
    await me.setMyPhone('0521111111');
    final yoni = await friend('יוני', Gender.male, '0532222222');
    final mom = await friend('אמא', Gender.female, '0543333333');
    final dana = await friend('דנה', Gender.female, '0504444444');
    for (final f in [yoni, mom, dana]) {
      final inv = await me.createInvitation();
      await f.acceptInvitation(inv.token);
    }
    await me.saveCircle(
      RealCircle(id: '', name: 'משפחה', quick: true, memberIds: {mom.userId!}),
    );
    await me.saveCircle(
      RealCircle(id: '', name: 'חברים מהצבא', memberIds: {yoni.userId!}),
    );
    if (screen != 'driving') {
      await mom.setAvailability(AvailabilityMode.walking, 40);
      await dana.setAvailability(AvailabilityMode.breakTime, 15);
    }
    switch (screen) {
      case 'offer' || 'waiting' || 'connected' || 'feedback':
        await yoni.setAvailability(AvailabilityMode.driving, 25);
        await me.setAvailability(AvailabilityMode.free, 30);
      case 'drivingOffer':
        await yoni.setAvailability(AvailabilityMode.walking, 25);
        await me.setAvailability(AvailabilityMode.driving, 60);
      case 'driving':
        await me.setAvailability(AvailabilityMode.driving, 60);
      default:
        await yoni.setAvailability(AvailabilityMode.driving, 25);
    }
    RealShell.debugInitialTab = switch (screen) {
      'people' => 1,
      'test' => 2,
      'settings' => 3,
      _ => 0,
    };
  }

  final container = ProviderContainer(
    overrides: [
      matchingConfigProvider.overrideWithValue(config),
      realBackendProvider.overrideWithValue(me),
      localStoreProvider.overrideWithValue(store),
      voiceServiceProvider.overrideWithValue(SilentVoiceService()),
      drivingDetectorProvider.overrideWithValue(
        FakeDrivingDetector()..enabled = true,
      ),
      contactsReaderProvider.overrideWithValue(FakeContactsReader()),
      incomingLinksProvider.overrideWithValue(const Stream.empty()),
      appVersionProvider.overrideWithValue('preview'),
    ],
  );
  container.read(realProvider);
  await Future<void>.delayed(const Duration(milliseconds: 50));
  final c = container.read(realProvider.notifier);
  await c.refresh();
  final now = DateTime.now();
  final offer = currentOffer(container.read(realProvider), now);
  if (screen == 'waiting' && offer != null) {
    await c.respond(offer, accept: true);
  }
  if ((screen == 'connected' || screen == 'feedback') && offer != null) {
    await c.respond(offer, accept: true);
    final other = server.offers.values.first;
    other
      ..status = OfferStatus.accepted
      ..aAccepted = true
      ..bAccepted = true;
    await c.refresh();
    if (screen == 'feedback') c.finishCall();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DriveTalkApp(),
    ),
  );
}
