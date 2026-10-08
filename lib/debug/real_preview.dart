// Design preview of the real mode with made-up friends — for screenshots
// only (never shipped as the app's entry point):
//   flutter build web -t lib/debug/real_preview.dart
//   open …/#home | #offer | #waiting | #connected | #driving | #drivingOffer
//        | #people | #settings | #test | #onboarding | #feedback

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/providers.dart';
import '../domain/models.dart';
import '../features/real/real_root.dart';
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
  final server = MemoryServer();
  final me = MemoryRealBackend(server);
  final store = MemoryLocalStore()
    ..values['real.contactsSyncedAt'] = DateTime.now().toIso8601String()
    ..values['real.widgetTip.v1'] = 'seen';

  final friends = <String, MemoryRealBackend>{};
  Future<MemoryRealBackend> friend(String name, Gender g, String phone) async {
    final b = MemoryRealBackend(server);
    await b.signIn(name, g);
    await b.setMyPhone(phone);
    friends[b.userId!] = b;
    return b;
  }

  if (screen != 'onboarding') {
    await me.signIn('נתנאל', Gender.male);
    await me.setMyPhone('0521111111');
    final yoni = await friend('יוני', Gender.male, '0532222222');
    final mom = await friend('אמא', Gender.female, '0543333333');
    final dana = await friend('דנה', Gender.female, '0504444444');
    // Friends who aren't free right now (made-up names).
    final omer = await friend('עומר', Gender.male, '0525555555');
    final shira = await friend('שירה', Gender.female, '0536666666');
    for (final f in [yoni, mom, dana, omer, shira]) {
      final inv = await me.createInvitation();
      await f.acceptInvitation(inv.token);
    }
    await me.setRating(mom.userId!, 5);
    await me.setRating(yoni.userId!, 4);
    await me.setRating(dana.userId!, 4);
    await me.setRating(omer.userId!, 3);
    await me.setRating(shira.userId!, 2);
    await me.saveCircle(
      RealCircle(id: '', name: 'משפחה', quick: true, memberIds: {mom.userId!}),
    );
    await me.saveCircle(
      RealCircle(id: '', name: 'חברים מהצבא', memberIds: {yoni.userId!}),
    );
    if (screen != 'driving') {
      // Home: three faces fit the card (driving, break, in a call).
      if (screen != 'home') {
        await mom.setAvailability(AvailabilityMode.walking, 40);
      }
      await dana.setAvailability(AvailabilityMode.breakTime, 15);
      // Free, but on the phone right now.
      await shira.setAvailability(AvailabilityMode.free, 30);
      server.phoneCall(shira.userId!, true);
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
      realBackendProvider.overrideWithValue(me),
      localStoreProvider.overrideWithValue(store),
      voiceServiceProvider.overrideWithValue(SilentVoiceService()),
      drivingDetectorProvider.overrideWithValue(
        FakeDrivingDetector()..enabled = true,
      ),
      contactsReaderProvider.overrideWithValue(
        FakeContactsReader()..asked = true,
      ),
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
    final otherId = offer.userA == me.userId ? offer.userB : offer.userA;
    await friends[otherId]!.answerOffer(offer.id, accept: true);
    await c.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (screen == 'feedback') c.finishCall();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DriveTalkApp(),
    ),
  );
}
