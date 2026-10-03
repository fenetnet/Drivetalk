// Two "phones" (Netanel & Yoni) running the real-mode controller against an
// in-memory copy of the server rules.
import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/l10n/app_localizations.dart';
import 'package:drivetalk/platform/driving_detector.dart';
import 'package:drivetalk/platform/phone_dialer.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/memory_backend.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:drivetalk/real/real_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingDialer implements PhoneDialer {
  final dialed = <String>[];
  DialResult result = DialResult.calling;
  @override
  Future<DialResult> call(String number) async {
    dialed.add(number);
    return result;
  }
}

class Phone {
  Phone(this.server, DateTime Function() clock) {
    backend = MemoryRealBackend(server);
    container = ProviderContainer(
      overrides: [
        realBackendProvider.overrideWithValue(backend),
        localStoreProvider.overrideWithValue(store),
        realClockProvider.overrideWithValue(clock),
        voiceServiceProvider.overrideWithValue(voice),
        phoneDialerProvider.overrideWithValue(dialer),
        inviteBaseUrlProvider.overrideWithValue('https://invite.example'),
        drivingDetectorProvider.overrideWithValue(driving),
      ],
    );
  }
  final driving = FakeDrivingDetector();
  final MemoryServer server;
  late final MemoryRealBackend backend;
  late final ProviderContainer container;
  final store = MemoryLocalStore();
  final voice = SilentVoiceService();
  final dialer = RecordingDialer();

  RealController get c => container.read(realProvider.notifier);
  RealState get s => container.read(realProvider);

  Future<void> boot() async {
    container.read(realProvider);
    await pump();
  }

  void dispose() => container.dispose();
}

Future<void> pump([int ms = 0]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late MemoryServer server;
  late Phone me;
  late Phone yoni;

  DateTime clock() => now;

  setUp(() async {
    now = DateTime(2026, 10, 2, 8);
    server = MemoryServer(now: clock);
    me = Phone(server, clock);
    yoni = Phone(server, clock);
    await me.boot();
    await yoni.boot();
  });

  tearDown(() {
    me.dispose();
    yoni.dispose();
  });

  Future<void> refreshBoth() async {
    await me.c.refresh();
    await yoni.c.refresh();
  }

  /// Sign both in and connect them through an invitation link.
  Future<void> connect({String? myPhone, String? yoniPhone}) async {
    await me.c.signIn('נתנאל', Gender.male, phone: myPhone);
    await yoni.c.signIn('יוני', Gender.male, phone: yoniPhone);
    final message = await me.c.createInviteMessage();
    expect(message, contains('https://invite.example/i/'));
    expect(yoni.c.openInviteText(message!), isTrue);
    await pump();
    expect(yoni.s.invite?.info?.status, InviteStatus.valid);
    expect(yoni.s.invite?.info?.inviterName, 'נתנאל');
    await yoni.c.acceptInvite();
    await refreshBoth();
  }

  test('starts signed out; joining needs only a name', () async {
    expect(me.s.phase, RealPhase.signedOut);
    await me.c.signIn('נתנאל', Gender.male);
    expect(me.s.phase, RealPhase.ready);
    expect(me.s.snapshot?.me.name, 'נתנאל');
    expect(me.s.snapshot?.friends, isEmpty);
  });

  test('invitation link → both become friends', () async {
    await connect();
    expect(me.s.snapshot!.friends.single.name, 'יוני');
    expect(yoni.s.snapshot!.friends.single.name, 'נתנאל');
    expect(yoni.s.notice?.kind, RealNoticeKind.connected);
    expect(yoni.s.invite, isNull);
  });

  test('a link opened before joining waits until after joining', () async {
    await me.c.signIn('נתנאל', Gender.male);
    final message = await me.c.createInviteMessage();
    yoni.c.openInviteText(message!);
    expect(yoni.s.invite, isNotNull);
    await yoni.c.signIn('יוני', Gender.male);
    await pump();
    expect(yoni.s.invite?.info?.status, InviteStatus.valid);
  });

  test('my own link and a used link are explained gently', () async {
    await connect();
    final message = await me.c.createInviteMessage();
    me.c.openInviteText(message!);
    await pump();
    expect(me.s.invite?.info?.status, InviteStatus.own);
    me.c.dismissInvite();

    // A third person tries Yoni's already-used invitation.
    final eve = Phone(server, clock);
    await eve.boot();
    await eve.c.signIn('איב', Gender.female);
    final token = server.invitations.keys.first;
    eve.c.openInvite(token);
    await pump();
    expect(eve.s.invite?.info?.status, InviteStatus.used);
    eve.dispose();
  });

  test(
    'both free → both asked → both yes → I call Yoni on the phone',
    () async {
      await connect(yoniPhone: '050-123-4567');
      await me.c.startAvailability(AvailabilityMode.walking, 30);
      await yoni.c.refresh();
      expect(currentOffer(me.s, now), isNull, reason: 'only I am free');

      await yoni.c.startAvailability(AvailabilityMode.free, 20);
      await me.c.refresh();
      final mine = currentOffer(me.s, now)!;
      final his = currentOffer(yoni.s, now)!;
      expect(mine.id, his.id);

      await me.c.respond(mine, accept: true);
      expect(currentOffer(me.s, now), isNull);
      expect(waitingOffer(me.s, now)?.id, mine.id);
      expect(
        me.s.callStage,
        CallStage.none,
        reason: 'not before Yoni says yes',
      );

      await yoni.c.respond(his, accept: true);
      await pump();
      await me.c.refresh();
      await pump();

      // Yoni shared his number, I didn't → I call him.
      expect(me.s.callStage, CallStage.connecting);
      expect(me.s.call?.role, CallRole.iCall);
      expect(yoni.s.callStage, CallStage.waitingForTheirCall);
      await me.c.dialNow();
      expect(me.dialer.dialed, ['0501234567']);
      expect(me.s.callStage, CallStage.dialed);
      expect(yoni.dialer.dialed, isEmpty);

      me.c.finishCall();
      expect(me.s.callStage, CallStage.feedback);
      await me.c.sendFeedback(talked: true, rating: FeedbackRating.veryGood);
      expect(me.s.callStage, CallStage.none);
      expect(server.feedback.single['rating'], 'veryGood');
    },
  );

  test('when both share numbers only one side calls', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0532222222');
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    await me.c.respond(currentOffer(me.s, now)!, accept: true);
    await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
    await pump();
    await me.c.refresh();
    await pump();
    final roles = {me.s.call?.role, yoni.s.call?.role};
    expect(roles, {CallRole.iCall, CallRole.theyCall});
  });

  test('no numbers shared → simulated in-app call', () async {
    await connect();
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    await me.c.respond(currentOffer(me.s, now)!, accept: true);
    await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
    await pump();
    await me.c.refresh();
    await pump();
    expect(me.s.callStage, CallStage.inApp);
    expect(yoni.s.callStage, CallStage.inApp);
  });

  test('"not now" → the other side hears only "didn\'t work out"', () async {
    await connect();
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    await me.c.respond(currentOffer(me.s, now)!, accept: true);
    await yoni.c.respond(currentOffer(yoni.s, now)!, accept: false);
    expect(currentOffer(yoni.s, now), isNull);
    expect(yoni.s.notice?.kind, isNot(RealNoticeKind.didNotWorkOut));
    await me.c.refresh();
    expect(me.s.notice?.kind, RealNoticeKind.didNotWorkOut);
    expect(waitingOffer(me.s, now), isNull);
    expect(me.s.callStage, CallStage.none);

    // No new offer right away (cooldown), even if I restart.
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.refresh();
    expect(currentOffer(yoni.s, now), isNull);
  });

  test('when the other stops being free, my question disappears', () async {
    await connect();
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    expect(currentOffer(me.s, now), isNotNull);
    await yoni.c.stopAvailability();
    await me.c.refresh();
    expect(currentOffer(me.s, now), isNull);
    expect(freeFriends(me.s, now), isEmpty);
  });

  test('availability expires by itself', () async {
    await connect();
    await me.c.startAvailability(AvailabilityMode.free, 15);
    await yoni.c.refresh();
    expect(freeFriends(yoni.s, now).single.$1.name, 'נתנאל');
    now = now.add(const Duration(minutes: 16));
    expect(freeFriends(yoni.s, now), isEmpty, reason: 'hidden at once');
    expect(myActiveAvailability(me.s, now), isNull);
    server.expireStale();
    await yoni.c.refresh();
    expect(yoni.s.snapshot!.availability, isEmpty);
  });

  test('driving: the question is read aloud and "yes" answers it', () async {
    await connect();
    await me.c.startAvailability(AvailabilityMode.driving, 30);
    me.voice.simulateAnswer(VoiceAnswer.yes);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    await pump(50);
    expect(me.voice.spoken, contains('יוני פנוי. לדבר?'));
    expect(waitingOffer(me.s, now), isNotNull);
  });

  test('block removes the friend and hides me from them', () async {
    await connect();
    await me.c.block(me.s.snapshot!.friends.single);
    await yoni.c.refresh();
    expect(me.s.snapshot!.friends, isEmpty);
    expect(yoni.s.snapshot!.friends, isEmpty);
    expect(me.s.notice?.kind, RealNoticeKind.blocked);
  });

  test('unmatch and report', () async {
    await connect();
    final y = me.s.snapshot!.friends.single;
    await me.c.report(y, ReportReason.spam);
    expect(server.reports.single['reason'], 'spam');
    await me.c.unmatch(y);
    expect(me.s.snapshot!.friends, isEmpty);
  });

  test('offline: a clear message, no crash, recovers', () async {
    await connect();
    me.backend.offline = true;
    await me.c.startAvailability(AvailabilityMode.free, 30);
    expect(me.s.notice?.kind, RealNoticeKind.error);
    expect(me.s.notice?.code, 'offline');
    me.backend.offline = false;
    await me.c.refresh();
    expect(me.s.lastError, isNull);
  });

  test('invalid phone number is refused before sending', () async {
    await me.c.signIn('נתנאל', Gender.male);
    expect(await me.c.setMyPhone('abc'), isFalse);
    expect(me.s.myPhone, isNull);
    expect(await me.c.setMyPhone('+972 50-123-4567'), isTrue);
    expect(me.s.myPhone, '+972501234567');
  });

  test('test info has no tokens, numbers or full ids', () async {
    await connect(myPhone: '0521111111');
    final message = await me.c.createInviteMessage();
    final token = parseInviteToken(message!)!;
    final info = me.c.diagnostics();
    expect(info, contains('friends: 1'));
    expect(info, contains('phone shared: yes'));
    expect(info, isNot(contains(token)));
    expect(info, isNot(contains('0521111111')));
    expect(info, isNot(contains(me.backend.userId!)));
  });

  test('an outcome is shown once, not again after a restart', () async {
    await connect();
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    await me.c.respond(currentOffer(me.s, now)!, accept: true);
    await yoni.c.respond(currentOffer(yoni.s, now)!, accept: false);
    await me.c.refresh();
    final noticeId = me.s.notice!.id;
    await me.c.refresh();
    expect(me.s.notice!.id, noticeId);

    // Same phone storage, new app start.
    final again = ProviderContainer(
      overrides: [
        realBackendProvider.overrideWithValue(me.backend),
        localStoreProvider.overrideWithValue(me.store),
        realClockProvider.overrideWithValue(clock),
        voiceServiceProvider.overrideWithValue(SilentVoiceService()),
      ],
    );
    again.read(realProvider);
    await pump();
    await again.read(realProvider.notifier).refresh();
    expect(again.read(realProvider).notice, isNull);
    again.dispose();
  });

  group('automatic driving availability', () {
    test('turning it on gives the phone a background token', () async {
      await connect();
      expect(await me.c.enableAutoDriving(), isTrue);
      expect(me.driving.enabled, isTrue);
      expect(me.s.driving.enabled, isTrue);
      expect(server.deviceTokens[me.driving.token], me.backend.userId);
      expect(me.s.notice?.kind, RealNoticeKind.autoDrivingOn);
    });

    test('no permission → stays off, with an explanation', () async {
      await connect();
      me.driving.grantPermission = false;
      expect(await me.c.enableAutoDriving(), isFalse);
      expect(me.s.driving.enabled, isFalse);
      expect(server.deviceTokens, isEmpty);
      expect(me.s.notice?.kind, RealNoticeKind.autoDrivingNoPermission);
    });

    test('trip → available while the app is closed → offer → "talk now" '
        'from the notification', () async {
      await connect();
      await me.c.enableAutoDriving();
      // The Android service calls the server with the device token.
      expect(server.autoStart(me.driving.token!), 'available');
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now).single.$2.mode, AvailabilityMode.driving);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      final offer = currentOffer(me.s, now)!;
      expect(isRealDriving(me.s, now), isTrue, reason: 'driver screen');

      // "Talk now" on the notification opens the app and answers yes.
      me.driving.tapNotification(LaunchAction(offer.id, accept: true));
      await pump(20);
      expect(waitingOffer(me.s, now)?.id, offer.id);
    });

    test('trip ended stops only what the car started', () async {
      await connect();
      await me.c.enableAutoDriving();
      final token = me.driving.token!;
      server.autoStart(token);
      expect(server.autoStop(token), 'stopped');
      await me.c.startAvailability(AvailabilityMode.walking, 30);
      expect(server.autoStart(token), 'already_available');
      expect(server.autoStop(token), 'nothing');
      await me.c.refresh();
      expect(myActiveAvailability(me.s, now)?.mode, AvailabilityMode.walking);
    });

    test('turning it off revokes the token', () async {
      await connect();
      await me.c.enableAutoDriving();
      final token = me.driving.token!;
      await me.c.disableAutoDriving();
      expect(me.driving.enabled, isFalse);
      expect(server.autoStart(token), 'bad_token');
    });

    test('test info shows the state, never the token', () async {
      await connect();
      await me.c.enableAutoDriving();
      final info = me.c.diagnostics();
      expect(info, contains('auto driving: on'));
      expect(info, isNot(contains(me.driving.token!)));
    });
  });

  group('invitation codes', () {
    const t = 'AbCdEfGhIjKlMnOpQrStUv';
    test('from all kinds of links and messages', () {
      expect(parseInviteToken('https://x.pages.dev/i/$t'), t);
      expect(parseInviteToken('https://u.github.io/Drivetalk/i/$t'), t);
      expect(parseInviteToken('https://x.dev/invite.html?t=$t'), t);
      expect(parseInviteToken('drivetalk://invite/$t'), t);
      expect(parseInviteToken(t), t);
      expect(parseInviteToken('  $t  '), t);
      expect(
        parseInviteToken('אני בודק אפליקציה… \nhttps://x.pages.dev/i/$t'),
        t,
      );
      expect(
        parseInviteToken(
          'להורדה: https://github.com/a/b/releases/download/prototype/'
          'drivetalk-prototype.apk\nואז: יש לי קוד הזמנה ← $t',
        ),
        t,
      );
    });
    test('nonsense gives nothing', () {
      expect(parseInviteToken(''), isNull);
      expect(parseInviteToken('שלום'), isNull);
      expect(parseInviteToken('https://example.com/'), isNull);
    });
  });

  test('without an invite site: download link + code', () {
    final msg = inviteMessageFor(
      lookupAppLocalizations(const Locale('he')),
      token: 'AbCdEfGhIjKlMnOpQrStUv',
      baseUrl: '',
      apkUrl: 'https://example.com/app.apk',
    );
    expect(msg, contains('https://example.com/app.apk'));
    expect(msg, contains('AbCdEfGhIjKlMnOpQrStUv'));
    expect(parseInviteToken(msg), 'AbCdEfGhIjKlMnOpQrStUv');
  });
}
