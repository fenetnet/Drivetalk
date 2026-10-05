// Runs the real-mode controller against a REAL Supabase (local docker), to
// check the app's requests and parsing. Skipped unless SUPABASE_LIVE_URL and
// SUPABASE_LIVE_KEY are set, e.g.:
//   SUPABASE_LIVE_URL=http://127.0.0.1:54321 SUPABASE_LIVE_KEY=sb_publishable_… \
//     flutter test test/supabase_live_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/platform/contacts_reader.dart';
import 'package:drivetalk/platform/driving_detector.dart';
import 'package:drivetalk/platform/phone_dialer.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:drivetalk/real/real_models.dart';
import 'package:drivetalk/real/supabase_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final url = Platform.environment['SUPABASE_LIVE_URL'];
final key = Platform.environment['SUPABASE_LIVE_KEY'];

class _Dialer extends PhoneDialer {
  final dialed = <String>[];
  @override
  Future<DialResult> call(String number, {bool direct = true}) async {
    dialed.add(number);
    return DialResult.calling;
  }
}

ProviderContainer _phone(_Dialer dialer) => ProviderContainer(
  overrides: [
    realBackendProvider.overrideWithValue(
      SupabaseRealBackend(
        client: SupabaseClient(
          url!,
          key!,
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        ),
      ),
    ),
    localStoreProvider.overrideWithValue(MemoryLocalStore()),
    voiceServiceProvider.overrideWithValue(SilentVoiceService()),
    phoneDialerProvider.overrideWithValue(dialer),
    drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
    contactsReaderProvider.overrideWithValue(FakeContactsReader()),
    inviteBaseUrlProvider.overrideWithValue('https://invite.example'),
  ],
);

Future<void> settle([int ms = 300]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('two phones against a real server', () async {
    final meDialer = _Dialer();
    final me = _phone(meDialer);
    final yoni = _phone(_Dialer());
    final m = me.read(realProvider.notifier);
    final y = yoni.read(realProvider.notifier);
    await settle();

    await m.signIn('נתנאל', Gender.male);
    await y.signIn('יוני', Gender.male, phone: '050-765-4321');
    expect(me.read(realProvider).phase, RealPhase.ready);
    expect(yoni.read(realProvider).myPhone, '0507654321');

    final msg = await m.createInviteMessage();
    expect(y.openInviteText(msg!), isTrue);
    await settle();
    expect(yoni.read(realProvider).invite?.info?.inviterName, 'נתנאל');
    await y.acceptInvite();
    await m.refresh();
    expect(me.read(realProvider).snapshot!.friends.single.name, 'יוני');

    await m.startAvailability(AvailabilityMode.driving, 30);
    await y.startAvailability(AvailabilityMode.walking, 30);
    await m.refresh();
    final now = DateTime.now();
    final offer = currentOffer(me.read(realProvider), now)!;
    expect(offer.status, OfferStatus.pending);
    expect(
      freeFriends(me.read(realProvider), now).single.$2.mode,
      AvailabilityMode.walking,
    );

    await m.respond(offer, accept: true);
    expect(waitingOffer(me.read(realProvider), DateTime.now()), isNotNull);
    await y.refresh();
    await y.respond(
      currentOffer(yoni.read(realProvider), DateTime.now())!,
      accept: true,
    );
    // Realtime or the next refresh brings "accepted" to me.
    await m.refresh();
    await settle();
    // Only Yoni shared a number → I dial, at once (no countdown).
    expect(me.read(realProvider).call?.role, CallRole.iCall);
    expect(meDialer.dialed, ['0507654321']);
    m.finishCall();
    await m.sendOutcome(CallOutcome.good);
    expect(me.read(realProvider).lastError, isNull);

    expect(m.diagnostics(), isNot(contains('0507654321')));
    // Circles through the real server.
    final yoniId = me.read(realProvider).snapshot!.friends.single.id;
    expect(
      await m.saveCircle(
        RealCircle(id: '', name: 'קרובים', quick: true, memberIds: {yoniId}),
      ),
      isTrue,
    );
    final circle = me.read(realProvider).snapshot!.circles.single;
    expect(circle.memberIds, {yoniId});
    expect(circle.quick, isTrue);
    await m.saveCircle(circle.copyWith(name: 'משפחה', memberIds: {}));
    expect(me.read(realProvider).snapshot!.circles.single.name, 'משפחה');
    await m.deleteCircle(me.read(realProvider).snapshot!.circles.single);
    expect(me.read(realProvider).snapshot!.circles, isEmpty);

    // Automatic driving: the phone gets a background token.
    expect(await m.enableAutoDriving(), isTrue);
    expect(me.read(realProvider).driving.enabled, isTrue);
    await m.disableAutoDriving();

    await m.stopAvailability();
    final meProfile = yoni.read(realProvider).snapshot!.friends.single;
    await y.block(meProfile);
    await m.refresh();
    expect(me.read(realProvider).snapshot!.friends, isEmpty);
    expect((await y.blockedPeople()).single.name, 'נתנאל');
    await y.unblock(meProfile);
    await m.refresh();
    expect(me.read(realProvider).snapshot!.friends.single.name, 'יוני');

    // "I'd like to talk": mine only, through the real server.
    final yoniP = me.read(realProvider).snapshot!.friends.single;
    await m.setTalkIntent(yoniP, TalkIntentSpan.week);
    await settle();
    await m.refresh();
    expect(me.read(realProvider).snapshot!.intents.keys, [yoniP.id]);
    await y.refresh();
    expect(yoni.read(realProvider).snapshot!.intents, isEmpty);
    await m.clearTalkIntent(yoniP);
    await settle();
    await m.refresh();
    expect(me.read(realProvider).snapshot!.intents, isEmpty);

    // Profile photo: mine → Yoni downloads and shows it.
    final pic = Uint8List.fromList(List.generate(500, (i) => i % 256));
    expect(await m.setPhoto(pic), isNull);
    await y.refresh();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(
      yoni.read(realProvider).snapshot!.friends.single.toPerson().photo,
      pic,
    );
    expect(await m.setPhoto(null), isNull);

    // Delete my account through the real server.
    expect(await m.deleteAccount(), isNull);
    expect(me.read(realProvider).phase, RealPhase.signedOut);
    await y.refresh();
    expect(yoni.read(realProvider).snapshot!.friends, isEmpty);

    me.dispose();
    yoni.dispose();
  }, skip: url == null || key == null ? 'no live server configured' : false);
}
