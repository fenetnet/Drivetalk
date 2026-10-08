// Two "phones" (Netanel & Yoni) running the real-mode controller against an
// in-memory copy of the server rules.
import 'dart:typed_data';

import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/l10n/app_localizations.dart';
import 'package:drivetalk/platform/contacts_reader.dart';
import 'package:drivetalk/platform/driving_detector.dart';
import 'package:drivetalk/platform/phone_dialer.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/real/local_store.dart';
import 'package:drivetalk/real/memory_backend.dart';
import 'package:drivetalk/real/photo_cache.dart';
import 'package:drivetalk/real/update_checker.dart';
import 'package:drivetalk/real/real_controller.dart';
import 'package:drivetalk/real/real_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingDialer extends PhoneDialer {
  final dialed = <String>[];
  final directs = <bool>[];
  var asked = 0;
  DialResult result = DialResult.calling;
  @override
  Future<bool> requestDirectCall() async {
    asked++;
    return false;
  }

  @override
  Future<DialResult> call(String number, {bool direct = true}) async {
    dialed.add(number);
    directs.add(direct);
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
        contactsReaderProvider.overrideWithValue(contacts),
        photoCacheProvider.overrideWithValue(photos),
        appBuildProvider.overrideWithValue(10),
        updateCheckerProvider.overrideWithValue(updates),
      ],
    );
  }
  final photos = MemoryPhotoCache();
  final updates = FakeUpdateChecker();
  final driving = FakeDrivingDetector();
  final contacts = FakeContactsReader();
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

  test('joining without a phone number works', () async {
    await me.c.signIn('נתנאל', Gender.male, phone: '');
    expect(me.s.phase, RealPhase.ready);
    expect(me.s.myPhone, isNull);
  });

  test('no answer within 25 seconds → stop waiting, gently', () async {
    await connect(yoniPhone: '050-123-4567');
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await refreshBoth();
    final offer = currentOffer(me.s, now)!;
    await me.c.respond(offer, accept: true);
    expect(waitingOffer(me.s, now)?.id, offer.id);

    now = now.add(const Duration(seconds: 10));
    me.c.checkWaiting();
    await pump();
    expect(waitingOffer(me.s, now)?.id, offer.id, reason: 'still waiting');

    now = now.add(const Duration(seconds: 16));
    me.c.checkWaiting();
    await pump(20);
    expect(waitingOffer(me.s, now), isNull);
    expect(me.s.notice?.kind, RealNoticeKind.noAnswer);
    await yoni.c.refresh();
    expect(currentOffer(yoni.s, now), isNull, reason: 'his question is gone');
    expect(me.dialer.dialed, isEmpty);
  });

  test(
    'calls always start at once; "I\'m free" asks for the permission',
    () async {
      await connect(yoniPhone: '050-123-4567');
      await pump(10);
      await me.c.startAvailability(AvailabilityMode.free, 30);
      expect(me.dialer.asked, 1, reason: 'not given yet → asked');
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await refreshBoth();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await pump(20);
      expect(me.dialer.dialed, ['0501234567']);
      expect(me.dialer.directs, [true], reason: 'no setting to turn it off');
    },
  );

  test('"I\'ll get back to you" → the other side is told, gently', () async {
    await connect();
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await refreshBoth();
    await yoni.c.respondLater(currentOffer(yoni.s, now)!);
    await me.c.refresh();
    expect(me.s.notice?.kind, RealNoticeKind.later);
    expect(me.s.notice?.name, 'יוני');
    expect(currentOffer(me.s, now), isNull);
    // Numbers are for the owner only.
    expect(await me.c.appStats(7), isNull);
    expect(me.c.unlockAdmin('97869786'), isTrue);
    await pump();
    final stats = await me.c.appStats(7);
    expect(stats!['later'], 1);
    expect(stats['declined'], 1);
  });

  test('first steps: "mornings" → a Sun–Thu routine at 7:30', () async {
    await me.c.signIn('נתנאל', Gender.male);
    me.c.firstRunNext(); // contacts → result
    me.c.firstRunNext(); // result → routine
    expect(me.s.firstRun, FirstRunStep.routine);
    await me.c.firstRunRoutines(morning: 7 * 60 + 30);
    expect(me.s.firstRun, FirstRunStep.magic);
    final r = me.s.routines.single;
    expect(r.minuteOfDay, 7 * 60 + 30);
    expect(r.weekdays, {7, 1, 2, 3, 4});
    expect(me.driving.routinesJson, contains('"hour":7,"minute":30'));
  });

  test('battery saving: asked once, only after using "I\'m free"', () async {
    await connect();
    me.driving.background = false;
    await me.c.refresh();
    expect(me.c.showBackgroundTip, isFalse, reason: 'never used it');
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.disableAutoDriving(); // reloads the phone status
    expect(me.c.showBackgroundTip, isTrue);
    me.c.dismissBackgroundTip();
    expect(me.c.showBackgroundTip, isFalse);
  });

  test('a friend gone for a week → one gentle "remove?" card', () async {
    await connect();
    await yoni.backend.touchSeen();
    await me.c.refresh();
    expect(me.c.inactiveFriend, isNull, reason: 'seen today');
    now = now.add(const Duration(days: 8));
    await me.c.refresh();
    expect(me.s.snapshot!.inactiveDays.values.single, 8);
    final f = me.c.inactiveFriend!;
    expect(f.name, 'יוני');
    me.c.keepInactive(f);
    expect(me.c.inactiveFriend, isNull, reason: 'asked once');
  });

  test('send feedback → reaches the owner; thanks', () async {
    await me.c.signIn('נתנאל', Gender.male);
    expect(await me.c.sendFeedback('  הכפתור קטן מדי  '), isTrue);
    expect(server.feedbackNotes, ['הכפתור קטן מדי']);
    expect(me.s.notice?.kind, RealNoticeKind.feedbackThanks);
    expect(await me.c.sendFeedback('   '), isFalse);
  });

  test(
    'the owner reads feedback and reports in the app; others cannot',
    () async {
      await connect();
      await yoni.c.sendFeedback('אהבתי');
      await yoni.c.report(yoni.s.snapshot!.friends.single, ReportReason.spam);
      expect(await yoni.c.ownerNotes(reports: false), isNull, reason: 'no');
      expect(me.c.unlockAdmin('97869786'), isTrue);
      await pump(10);
      expect((await me.c.ownerNotes(reports: false))!.single.body, 'אהבתי');
      final r = (await me.c.ownerNotes(reports: true))!.single;
      expect(r.title, 'יוני → נתנאל');
    },
  );

  test('first steps: any hour for the routine', () async {
    await me.c.signIn('נתנאל', Gender.male);
    await me.c.firstRunRoutines(evening: 18 * 60 + 15);
    expect(me.s.routines.single.minuteOfDay, 18 * 60 + 15);
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

      // Yoni shared his number, I didn't → I call him, right away.
      expect(me.s.call?.role, CallRole.iCall);
      expect(me.dialer.dialed, ['0501234567']);
      expect(yoni.s.callStage, CallStage.waitingForTheirCall);
      expect(me.s.callStage, CallStage.dialed);
      expect(yoni.dialer.dialed, isEmpty);

      me.c.finishCall();
      expect(me.s.callStage, CallStage.feedback);
      await me.c.sendOutcome(CallOutcome.good);
      expect(me.s.callStage, CallStage.none);
      expect(server.feedback.single['outcome'], 'good');
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
    // The second "yes" (Yoni) dials immediately, in the same step.
    expect(yoni.s.call?.role, CallRole.iCall);
    expect(yoni.dialer.dialed, ['0521111111']);
    expect(me.dialer.dialed, isEmpty);
    // Measured: "both said yes" → dialing (name + ms only).
    final dial = server.events.where((e) => e.$1 == 'dial_started').single;
    expect(dial.$2, isNotNull);
    expect(dial.$2!, lessThan(1000));
    expect(server.events.map((e) => e.$1), contains('both_accepted'));
  });

  test('delete my account: gone everywhere, back to the start', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0532222222');
    final myId = me.backend.userId!;
    expect(await me.c.deleteAccount(), isNull);
    expect(me.s.phase, RealPhase.signedOut);
    await yoni.c.refresh();
    expect(yoni.s.snapshot!.friends, isEmpty);
    expect(server.phones.containsKey(myId), isFalse);
    expect(server.profiles.containsKey(myId), isFalse);
  });

  test('one offer at a time, and never two calls at once', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0532222222');
    final dana = Phone(server, clock);
    await dana.boot();
    await dana.c.signIn('דנה', Gender.female, phone: '0543333333');
    final msg = await me.c.createInviteMessage();
    dana.c.openInviteText(msg!);
    await pump();
    await dana.c.acceptInvite();
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await dana.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    final mine = me.s.snapshot!.offers
        .where((o) => o.status == OfferStatus.pending)
        .toList();
    expect(mine, hasLength(1), reason: 'two friends free → one question');
    final first = mine.single;
    final other = first.otherId(me.backend.userId!) == yoni.backend.userId
        ? yoni
        : dana;
    final third = identical(other, yoni) ? dana : yoni;
    await me.c.respond(first, accept: true);
    await other.c.refresh();
    await other.c.respond(currentOffer(other.s, now)!, accept: true);
    now = now.add(const Duration(seconds: 16)); // the app nudges every 15s
    await third.c.refresh();
    expect(
      currentOffer(third.s, now),
      isNull,
      reason: 'I am in a call → nobody else is offered to me',
    );
    // Friends see "in a call", not "free".
    expect(busyFriends(third.s, now).map((f) => f.$1.id), [me.backend.userId]);
    expect(
      freeFriends(third.s, now).map((f) => f.$1.id),
      isNot(contains(me.backend.userId)),
    );
    await me.c.refresh(); // Realtime tells me the call started
    await pump();
    expect(me.s.callStage, CallStage.waitingForTheirCall);
    me.c.finishCall();
    await me.c.sendOutcome(CallOutcome.good);
    now = now.add(const Duration(seconds: 16));
    await third.c.refresh();
    expect(currentOffer(third.s, now), isNotNull, reason: 'call over → next');
    expect(busyFriends(third.s, now), isEmpty);
    dana.dispose();
  });

  test('another phone call → "in a call", and nobody is offered', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0532222222');
    await yoni.c.startAvailability(AvailabilityMode.driving, 30);
    // Yoni's phone rings with someone else (the background service sees it).
    server.phoneCall(yoni.backend.userId!, true);
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    expect(currentOffer(me.s, now), isNull, reason: 'Yoni is on the phone');
    expect(busyFriends(me.s, now).single.$1.name, 'יוני');
    expect(freeFriends(me.s, now), isEmpty);
    // The call ends → Yoni is free again and the question comes.
    server.phoneCall(yoni.backend.userId!, false);
    now = now.add(const Duration(seconds: 16));
    await me.c.refresh();
    expect(busyFriends(me.s, now), isEmpty);
    expect(freeFriends(me.s, now).single.$1.name, 'יוני');
    expect(currentOffer(me.s, now), isNotNull);
  });

  test('"in a call" ends by itself if the phone stops reporting', () async {
    await connect();
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    server.phoneCall(yoni.backend.userId!, true);
    await me.c.refresh();
    expect(busyFriends(me.s, now), hasLength(1));
    now = now.add(const Duration(minutes: 4));
    await me.c.refresh();
    expect(busyFriends(me.s, now), isEmpty);
    expect(freeFriends(me.s, now), hasLength(1));
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
    expect(me.voice.spoken, contains('ליוני יש זמן. לדבר?'));
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

    test('renewing during a drive keeps the same trip', () async {
      await connect();
      await me.c.enableAutoDriving();
      final token = me.driving.token!;
      final id = me.backend.userId!;
      server.autoStart(token, minutes: 15);
      final start = server.availability[id]!.startedAt;
      now = now.add(const Duration(minutes: 4));
      server.autoStart(token, minutes: 15);
      expect(server.availability[id]!.startedAt, start);
      expect(
        server.availability[id]!.expiresAt,
        now.add(const Duration(minutes: 15)),
      );
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

    test(
      'turning it off stops detection; signing out revokes the token',
      () async {
        await connect();
        await me.c.enableAutoDriving();
        final token = me.driving.token!;
        await me.c.disableAutoDriving();
        expect(me.driving.enabled, isFalse);
        expect(server.autoStart(token), 'available', reason: 'kept for alerts');
        await me.c.signOut();
        expect(server.autoStart(token), 'bad_token');
        expect(me.driving.token, isNull);
      },
    );

    test('marking myself free keeps watching in the background', () async {
      await connect();
      await pump(10);
      await me.c.startAvailability(AvailabilityMode.walking, 30);
      await pump(10);
      expect(me.driving.availableUntil, now.add(const Duration(minutes: 30)));
      await me.c.stopAvailability();
      expect(me.driving.availableUntil, isNull);
    });

    test('test info shows the state, never the token', () async {
      await connect();
      await me.c.enableAutoDriving();
      final info = me.c.diagnostics();
      expect(info, contains('auto driving: on'));
      expect(info, isNot(contains(me.driving.token!)));
    });
  });

  group('owner feedback round', () {
    test('after "not now": 5 quiet minutes, then someone else; '
        'the same friend only in a new window', () async {
      await connect();
      final dana = Phone(server, clock);
      await dana.boot();
      await dana.c.signIn('דנה', Gender.female);
      final msg = await me.c.createInviteMessage();
      dana.c.openInviteText(msg!);
      await pump();
      await dana.c.acceptInvite();
      await me.c.startAvailability(AvailabilityMode.free, 60);
      await yoni.c.startAvailability(AvailabilityMode.free, 60);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: false);
      await dana.c.startAvailability(AvailabilityMode.free, 60);
      await me.c.refresh();
      expect(currentOffer(me.s, now), isNull, reason: 'quiet for a while');
      now = now.add(const Duration(minutes: 3));
      await me.c.refresh();
      expect(currentOffer(me.s, now), isNull, reason: 'still quiet');
      now = now.add(const Duration(minutes: 3));
      await me.c.refresh(); // nudges the server while free
      final next = currentOffer(me.s, now)!;
      expect(next.otherId(me.backend.userId!), dana.backend.userId);
      await me.c.respond(next, accept: false);
      now = now.add(const Duration(minutes: 6));
      await yoni.c.refresh();
      expect(currentOffer(yoni.s, now), isNull, reason: 'once per window');
      // A new window (e.g. the next trip): Yoni may come up again.
      await me.c.startAvailability(AvailabilityMode.free, 60);
      await yoni.c.refresh();
      expect(currentOffer(yoni.s, now), isNotNull);
      dana.dispose();
    });

    test('a question waits 2 minutes; after 3 unanswered, quiet', () async {
      await connect();
      final others = <Phone>[yoni];
      for (final name in ['דנה', 'אמא', 'אבי']) {
        final p = Phone(server, clock);
        await p.boot();
        await p.c.signIn(name, Gender.female);
        final msg = await me.c.createInviteMessage();
        p.c.openInviteText(msg!);
        await pump();
        await p.c.acceptInvite();
        others.add(p);
      }
      for (final p in others) {
        await p.c.startAvailability(AvailabilityMode.free, 120);
      }
      await me.c.startAvailability(AvailabilityMode.driving, 120);
      final asked = <String>{};
      for (var i = 0; i < 3; i++) {
        await me.c.refresh();
        final o = currentOffer(me.s, now);
        expect(o, isNotNull, reason: 'question ${i + 1}');
        asked.add(o!.otherId(me.backend.userId!));
        now = now.add(const Duration(minutes: 2, seconds: 1));
        await me.c.refresh();
        expect(currentOffer(me.s, now), isNull, reason: 'over after 2 min');
        now = now.add(const Duration(minutes: 5, seconds: 1));
      }
      expect(asked, hasLength(3), reason: 'each friend once');
      await me.c.refresh();
      now = now.add(const Duration(minutes: 10));
      await me.c.refresh();
      expect(currentOffer(me.s, now), isNull, reason: '3 unanswered → quiet');
      for (final p in others.skip(1)) {
        p.dispose();
      }
    });

    test(
      'quick-connect circles on both sides → connected without asking',
      () async {
        await connect(myPhone: '0521111111', yoniPhone: '0532222222');
        final yoniId = yoni.backend.userId!;
        final meId = me.backend.userId!;
        await me.c.saveCircle(
          RealCircle(id: '', name: 'קרובים', quick: true, memberIds: {yoniId}),
        );
        await yoni.c.saveCircle(
          RealCircle(id: '', name: 'משפחה', quick: true, memberIds: {meId}),
        );
        await me.c.startAvailability(AvailabilityMode.driving, 30);
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.refresh();
        await yoni.c.refresh();
        await pump(50);
        expect(currentOffer(me.s, now), isNull, reason: 'no question');
        expect(me.s.callStage, CallStage.connecting);
        expect(me.s.call?.quick, isTrue);
        expect(me.voice.spoken.last, contains('יוני'));
        // Nobody dials during the 5 seconds (server rule).
        await pump(700);
        expect(me.s.callStage, CallStage.connecting);
        expect([...me.dialer.dialed, ...yoni.dialer.dialed], isEmpty);
        now = now.add(const Duration(seconds: 6));
        await pump(700);
        // Exactly one side dials.
        expect(
          {me.s.call?.role, yoni.s.call?.role},
          {CallRole.iCall, CallRole.theyCall},
        );
        expect(me.dialer.dialed.length + yoni.dialer.dialed.length, 1);
      },
    );

    test('quick connect: either side can cancel in the 5 seconds', () async {
      await connect(myPhone: '0521111111', yoniPhone: '0532222222');
      await me.c.saveCircle(
        RealCircle(
          id: '',
          name: 'קרובים',
          quick: true,
          memberIds: {yoni.backend.userId!},
        ),
      );
      await yoni.c.saveCircle(
        RealCircle(
          id: '',
          name: 'משפחה',
          quick: true,
          memberIds: {me.backend.userId!},
        ),
      );
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await yoni.c.refresh();
      await pump(50);
      expect(yoni.s.callStage, CallStage.connecting);
      await yoni.c.cancelCall();
      expect(yoni.s.callStage, CallStage.none);
      await me.c.refresh();
      await pump(600);
      expect(me.s.callStage, CallStage.none);
      expect(me.s.notice?.kind, RealNoticeKind.quickCancelled);
      now = now.add(const Duration(seconds: 10));
      await pump(600);
      expect([...me.dialer.dialed, ...yoni.dialer.dialed], isEmpty);
    });

    test('one-sided quick circle is just a normal question', () async {
      await connect();
      await me.c.saveCircle(
        RealCircle(
          id: '',
          name: 'קרובים',
          quick: true,
          memberIds: {yoni.backend.userId!},
        ),
      );
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      expect(currentOffer(me.s, now), isNotNull);
    });

    test(
      'free only for a circle → others neither see me nor get asked',
      () async {
        await connect();
        final circle = RealCircle(id: '', name: 'משפחה', memberIds: const {});
        await me.c.saveCircle(circle);
        final saved = me.s.snapshot!.circles.single;
        await me.c.startAvailability(
          AvailabilityMode.walking,
          30,
          circleId: saved.id,
        );
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await yoni.c.refresh();
        expect(freeFriends(yoni.s, now), isEmpty);
        expect(currentOffer(yoni.s, now), isNull);
      },
    );

    test('unblock brings the friend back', () async {
      await connect();
      final y = me.s.snapshot!.friends.single;
      await me.c.block(y);
      expect((await me.c.blockedPeople()).single.name, 'יוני');
      await me.c.unblock(y);
      expect(me.s.snapshot!.friends.single.name, 'יוני');
      expect(me.s.notice?.kind, RealNoticeKind.unblockedReconnected);
      await yoni.c.refresh();
      expect(yoni.s.snapshot!.friends.single.name, 'נתנאל');
    });

    test('stopping availability also ends the trip service', () async {
      await connect();
      await me.c.enableAutoDriving();
      await me.driving.simulate(enter: true);
      await pump(10);
      expect(me.s.driving.inVehicle, isTrue);
      await me.c.stopAvailability();
      expect(me.driving.inVehicle, isFalse);
    });
  });

  group('friends from contacts', () {
    test('nobody is added automatically; I pick who → connected', () async {
      await yoni.c.signIn('יוני', Gender.male, phone: '0532222222');
      yoni.contacts.numbers = ['0521111111'];
      me.contacts.numbers = ['053-222-2222', '+972 54 000 0000'];
      await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await me.c.firstRunFindPeople();
      await pump(10);
      expect(me.s.snapshot!.friends, isEmpty, reason: 'nothing automatic');
      expect(me.c.contactMatches.single.name, 'יוני');
      // Yoni has me saved too — still nothing automatic for him.
      await yoni.c.syncContacts();
      expect(yoni.s.snapshot!.friends, isEmpty);
      // I pick Yoni → connected at once, no approval.
      await me.c.addContacts([me.c.contactMatches.single]);
      expect(me.s.snapshot!.friends.single.name, 'יוני');
      expect(me.s.notice?.kind, RealNoticeKind.contactsFound);
      await yoni.c.refresh();
      expect(yoni.s.snapshot!.friends.single.name, 'נתנאל');
    });

    test('removed → not suggested again from contacts (both sides)', () async {
      await yoni.c.signIn('יוני', Gender.male, phone: '0532222222');
      yoni.contacts.numbers = ['0521111111'];
      me.contacts.numbers = ['0532222222'];
      await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await me.c.syncContacts();
      await me.c.addContacts(me.c.contactMatches);
      await yoni.c.refresh();
      await yoni.c.unmatch(yoni.s.snapshot!.friends.single);
      await me.c.syncContacts();
      expect(me.c.contactMatches, isEmpty, reason: 'he removed me');
      await yoni.c.syncContacts();
      expect(yoni.c.contactMatches, isEmpty, reason: 'nor back to him');
      // An invitation still works (explicit).
      final msg = await me.c.createInviteMessage();
      yoni.c.openInviteText(msg!);
      await pump();
      await yoni.c.acceptInvite();
      await me.c.refresh();
      expect(me.s.snapshot!.friends.single.name, 'יוני');
    });

    test('someone joins later → one quiet card; "no" hides it', () async {
      me.contacts.numbers = ['0532222222'];
      await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await me.c.firstRunFindPeople();
      expect(me.c.newContactMatch, isNull);
      await yoni.c.signIn('יוני', Gender.male, phone: '0532222222');
      await me.c.syncContacts(ask: false); // the automatic search
      expect(me.c.newContactMatch?.name, 'יוני');
      me.c.dismissMatch(me.c.newContactMatch!);
      expect(me.c.newContactMatch, isNull);
      expect(me.s.snapshot!.friends, isEmpty);
    });

    test('rating: 0 = never offered; higher = offered first', () async {
      await connect();
      final dana = Phone(server, clock);
      await dana.boot();
      await dana.c.signIn('דנה', Gender.female);
      final msg = await me.c.createInviteMessage();
      dana.c.openInviteText(msg!);
      await pump();
      await dana.c.acceptInvite();
      await me.c.refresh();
      final y = me.s.snapshot!.friends.firstWhere((f) => f.name == 'יוני');
      final d = me.s.snapshot!.friends.firstWhere((f) => f.name == 'דנה');
      await me.c.setRating(d, 5);
      expect(me.s.snapshot!.ratingOf(d.id), 5);
      await yoni.c.startAvailability(AvailabilityMode.free, 60);
      await dana.c.startAvailability(AvailabilityMode.free, 60);
      await me.c.startAvailability(AvailabilityMode.free, 60);
      await me.c.refresh();
      expect(currentOffer(me.s, now)!.otherId(me.backend.userId!), d.id);
      // 0 for Yoni: never offered, even when nobody else is free.
      await me.c.respond(currentOffer(me.s, now)!, accept: false);
      await me.c.setRating(y, 0);
      now = now.add(const Duration(minutes: 6));
      await me.c.refresh();
      expect(currentOffer(me.s, now), isNull);
      dana.dispose();
    });

    test(
      'hidden status: nobody sees me free, I see nobody; offers go on',
      () async {
        await connect();
        await me.c.setHideStatus(true);
        expect(me.s.snapshot!.hidden, isTrue);
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.refresh();
        await yoni.c.refresh();
        expect(freeFriends(me.s, now), isEmpty, reason: 'I see nobody');
        expect(freeFriends(yoni.s, now), isEmpty, reason: 'nobody sees me');
        expect(currentOffer(me.s, now), isNotNull, reason: 'offers go on');
        expect(currentOffer(yoni.s, now), isNotNull);
      },
    );

    test('shown by the name saved in MY phone; names never leave it', () async {
      await yoni.c.signIn('יוני', Gender.male, phone: '0532222222');
      me.contacts.numbers = ['0532222222'];
      me.contacts.names = {'0532222222': 'אחי הגדול'};
      await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await me.c.syncContacts();
      expect(me.c.contactMatches.single.name, 'אחי הגדול');
      await me.c.addContacts(me.c.contactMatches);
      expect(me.s.snapshot!.friends.single.name, 'אחי הגדול');
      expect(me.driving.names.values, contains('אחי הגדול'));
      // The server only ever saw a hash.
      final sent = server.contactHashes[me.backend.userId]!;
      expect(sent.single, hasLength(64));
      expect(server.profiles[yoni.backend.userId]!.name, 'יוני');
    });

    test('reinstalled (two accounts, one number) → listed once', () async {
      final old = Phone(server, clock);
      await old.boot();
      await old.c.signIn('מעיין', Gender.female, phone: '0547777777');
      final again = Phone(server, clock);
      await again.boot();
      await again.c.signIn('מעיין', Gender.female, phone: '0547777777');
      me.contacts.numbers = ['0547777777'];
      await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await me.c.syncContacts();
      expect(me.c.contactMatches, hasLength(1));
      expect(me.c.contactMatches.single.id, again.backend.userId);
      old.dispose();
      again.dispose();
    });

    test('notifications can be changed later (phone settings)', () async {
      await me.c.signIn('נתנאל', Gender.male);
      await me.c.openNotificationSettings();
      expect(me.driving.notificationsOpened, 1);
    });

    test('no permission → explained, nothing sent', () async {
      me.contacts.granted = false;
      await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await me.c.firstRunFindPeople();
      await pump(10);
      expect(server.contactHashes, isEmpty);
      expect(me.s.firstRun, FirstRunStep.result);
      // Later, from "My people": explained.
      await me.c.syncContacts();
      expect(me.s.notice?.kind, RealNoticeKind.contactsNoPermission);
    });

    test('only hashes leave the phone; non-users are not kept', () async {
      await yoni.c.signIn('יוני', Gender.male, phone: '0532222222');
      me.contacts.numbers = ['0532222222', '0549999999'];
      await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await me.c.firstRunFindPeople();
      await pump(10);
      final sent = server.contactHashes[me.backend.userId]!;
      expect(sent.single, hasLength(64));
      expect(sent.single, isNot(contains('532222222')));
    });

    test('phone formats all match', () {
      expect(e164Phone('052-111-1111'), '+972521111111');
      expect(e164Phone('+972 52 111 1111'), '+972521111111');
      expect(e164Phone('00972521111111'), '+972521111111');
      expect(e164Phone('972521111111'), '+972521111111');
      expect(e164Phone('12'), isNull);
    });
  });

  group('talk history and the car', () {
    test('talk history (for "longest without talking" first)', () async {
      await connect();
      final yoniId = me.s.snapshot!.friends.single.id;
      expect(me.s.snapshot!.lastTalk[yoniId], isNull);
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await me.c.refresh();
      expect(me.s.snapshot!.lastTalk[yoniId], isNull, reason: 'yes ≠ talked');
      me.c.finishCall();
      await me.c.sendOutcome(CallOutcome.good);
      await me.c.refresh();
      expect(me.s.snapshot!.lastTalk[yoniId], isNotNull);
    });

    test('picking the car turns automatic driving on', () async {
      await connect();
      expect(me.s.driving.enabled, isFalse);
      final cars = await me.c.carCandidates();
      await me.c.setCar(cars.single.$2, cars.single.$1);
      expect(me.s.driving.enabled, isTrue);
      expect(me.s.driving.carName, 'Car Audio');
    });
  });

  group('routines and the week', () {
    test('a routine is handed to the phone and offered at its time', () async {
      await connect();
      final r = Routine(
        id: 'r1',
        weekdays: {now.weekday},
        minuteOfDay: now.hour * 60 + now.minute,
        durationMinutes: 45,
        mode: AvailabilityMode.driving,
      );
      await me.c.saveRoutines([r]);
      expect(me.s.routines.single.id, 'r1');
      expect(me.driving.routinesJson, contains('"minutes":45'));
      expect(me.c.dueRoutine(now.add(const Duration(minutes: 5)))?.id, 'r1');
      expect(me.c.dueRoutine(now.add(const Duration(minutes: 40))), isNull);
      await me.c.startAvailability(AvailabilityMode.driving, 45);
      expect(me.c.dueRoutine(now), isNull, reason: 'already free');
    });

    test('routines survive a restart', () async {
      await connect();
      await me.c.saveRoutines([
        Routine(
          id: 'r2',
          weekdays: {1, 2},
          minuteOfDay: 8 * 60,
          durationMinutes: 30,
          mode: AvailabilityMode.free,
        ),
      ]);
      final again = ProviderContainer(
        overrides: [
          realBackendProvider.overrideWithValue(me.backend),
          localStoreProvider.overrideWithValue(me.store),
          realClockProvider.overrideWithValue(clock),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
          contactsReaderProvider.overrideWithValue(FakeContactsReader()),
        ],
      );
      expect(again.read(realProvider).routines.single.id, 'r2');
      await pump();
      again.dispose();
    });

    test('this week: talks and different friends', () async {
      await connect();
      expect(me.s.snapshot!.weekAt(now), (0, 0));
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await me.c.refresh();
      me.c.finishCall();
      await me.c.sendOutcome(CallOutcome.good);
      await me.c.refresh();
      expect(me.s.snapshot!.weekAt(now), (1, 1));
      expect(me.s.snapshot!.weekAt(now.add(const Duration(days: 8))), (0, 0));
    });
  });

  test('"I\'d like to talk" → that friend is offered first, quietly', () async {
    await connect();
    final dad = Phone(server, clock);
    await dad.boot();
    await dad.c.signIn('אבא', Gender.male, phone: '0549999999');
    final msg = await me.c.createInviteMessage();
    dad.c.openInviteText(msg!);
    await pump();
    await dad.c.acceptInvite();
    await me.c.refresh();
    final dadProfile = me.s.snapshot!.friends.firstWhere(
      (f) => f.name == 'אבא',
    );
    // Yoni sorts first by id; the wish must win over that.
    await me.c.setTalkIntent(dadProfile, TalkIntentSpan.today);
    expect(me.s.snapshot!.intents[dadProfile.id]?.until, DateTime(2026, 10, 3));
    await dad.c.refresh();
    expect(dad.s.snapshot!.intents, isEmpty, reason: 'never told');
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await dad.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.startAvailability(AvailabilityMode.free, 30);
    expect(currentOffer(me.s, now)!.otherId(me.backend.userId!), dadProfile.id);
    // After midnight the wish is gone by itself.
    now = DateTime(2026, 10, 3, 9);
    await me.c.refresh();
    expect(me.s.snapshot!.intents, isEmpty);
    dad.dispose();
  });

  test('only real talks count; "not soon" pauses the pair quietly', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0532222222');
    Future<void> talk(CallOutcome outcome) async {
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await yoni.c.refresh();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await me.c.refresh();
      await pump();
      me.c.finishCall();
      await me.c.sendOutcome(outcome);
      yoni.c.finishCall();
      await yoni.c.sendOutcome(outcome);
      await me.c.refresh();
    }

    await talk(CallOutcome.noTalk);
    expect(me.s.snapshot!.weekAt(now), (0, 0), reason: 'two yeses ≠ a talk');
    now = now.add(const Duration(minutes: 31));
    await talk(CallOutcome.notSoon);
    expect(me.s.snapshot!.weekAt(now), (1, 1));
    // An hour later both are free again: not offered (paused for a while).
    now = now.add(const Duration(hours: 1));
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    expect(currentOffer(me.s, now), isNull);
    // After a week, again.
    now = now.add(const Duration(days: 8));
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    expect(currentOffer(me.s, now), isNotNull);
  });

  test('a newer version is announced (and only a newer one)', () async {
    await connect();
    me.updates.build = 10;
    await me.c.checkForUpdate(force: true);
    expect(me.s.newBuild, isNull, reason: 'same version');
    me.updates.build = 11;
    await me.c.checkForUpdate(force: true);
    expect(me.s.newBuild, 11);
  });

  group('stage 5', () {
    test('an older server is said clearly', () async {
      me.backend.schema = 12;
      await connect();
      await pump(10);
      expect(me.s.serverOutdated, isTrue);
      expect(me.c.diagnostics(), contains('server schema: 12 (app needs 23)'));
    });

    test(
      'delete what was synced from contacts; again if permission gone',
      () async {
        await yoni.c.signIn('יוני', Gender.male, phone: '0532222222');
        me.contacts.numbers = ['0532222222'];
        await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
        await me.c.firstRunFindPeople();
        expect(server.contactHashes[me.backend.userId], isNotEmpty);
        await me.c.clearContacts();
        expect(server.contactHashes[me.backend.userId], isNull);
        // Synced again, then the permission is taken away → removed quietly.
        await me.c.syncContacts();
        expect(server.contactHashes[me.backend.userId], isNotEmpty);
        me.contacts.granted = false;
        now = now.add(const Duration(hours: 13));
        final again = ProviderContainer(
          overrides: [
            realBackendProvider.overrideWithValue(me.backend),
            localStoreProvider.overrideWithValue(me.store),
            realClockProvider.overrideWithValue(clock),
            voiceServiceProvider.overrideWithValue(SilentVoiceService()),
            drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
            contactsReaderProvider.overrideWithValue(me.contacts),
            photoCacheProvider.overrideWithValue(me.photos),
          ],
        );
        again.read(realProvider);
        await pump(50);
        expect(server.contactHashes[me.backend.userId], isNull);
        again.dispose();
      },
    );

    test('names are not read aloud when turned off', () async {
      await connect();
      me.c.setPrefs(me.s.prefs.copyWith(speakNames: false));
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await pump(10);
      expect(me.voice.spoken.last, 'חבר פנוי עכשיו. לדבר?');
      expect(me.voice.spoken.join(), isNot(contains('יוני')));
    });

    test('free at the same time 3 Sundays → a routine is suggested', () async {
      await connect();
      // Three Sundays at ~17:30 (2026-10-04 is a Sunday).
      for (final d in [4, 11, 18]) {
        now = DateTime(2026, 10, d, 17, 35);
        await me.c.startAvailability(AvailabilityMode.driving, 20);
        await me.c.stopAvailability();
      }
      now = DateTime(2026, 10, 20, 9);
      final hint = me.c.routineSuggestion(now)!;
      expect(hint.weekday, DateTime.sunday);
      expect(hint.minuteOfDay, 17 * 60 + 30);
      expect(hint.mode, AvailabilityMode.driving);
      // Never by itself: only after "yes".
      expect(me.s.routines, isEmpty);
      await me.c.acceptRoutineSuggestion(hint);
      expect(me.s.routines.single.weekdays, {DateTime.sunday});
      expect(me.c.routineSuggestion(now), isNull, reason: 'covered now');
    });

    test('"no thanks" hides that suggestion for good', () async {
      await connect();
      for (final d in [5, 12, 19]) {
        now = DateTime(2026, 10, d, 8, 0);
        await me.c.startAvailability(AvailabilityMode.free, 20);
        await me.c.stopAvailability();
      }
      now = DateTime(2026, 10, 21, 9);
      me.c.dismissRoutineSuggestion(me.c.routineSuggestion(now)!);
      expect(me.c.routineSuggestion(now), isNull);
    });
  });

  group('profile photos', () {
    final jpeg = Uint8List.fromList(List.generate(64, (i) => i));
    final jpeg2 = Uint8List.fromList(List.generate(64, (i) => 200 - i));

    test('a friend sees my photo; a change and a removal reach them', () async {
      await connect();
      expect(await me.c.setPhoto(jpeg), isNull);
      expect(me.s.snapshot!.me.toPerson().photo, jpeg);
      await yoni.c.refresh();
      await pump(10);
      expect(yoni.s.snapshot!.friends.single.toPerson().photo, jpeg);

      await me.c.setPhoto(jpeg2);
      await yoni.c.refresh();
      await pump(10);
      expect(yoni.s.snapshot!.friends.single.toPerson().photo, jpeg2);

      await me.c.setPhoto(null);
      expect(me.s.snapshot!.me.toPerson().photo, isNull);
      await yoni.c.refresh();
      await pump(10);
      expect(yoni.s.snapshot!.friends.single.toPerson().photo, isNull);
    });

    test('kept on the phone: no new download after a restart', () async {
      await connect();
      await me.c.setPhoto(jpeg);
      await yoni.c.refresh();
      await pump(10);
      server.photos.clear(); // A new download would now find nothing.
      // Same phone storage, new app start.
      final again = ProviderContainer(
        overrides: [
          realBackendProvider.overrideWithValue(yoni.backend),
          localStoreProvider.overrideWithValue(yoni.store),
          realClockProvider.overrideWithValue(clock),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          drivingDetectorProvider.overrideWithValue(FakeDrivingDetector()),
          contactsReaderProvider.overrideWithValue(FakeContactsReader()),
          photoCacheProvider.overrideWithValue(yoni.photos),
        ],
      );
      again.read(realProvider);
      await pump();
      await again.read(realProvider.notifier).refresh();
      expect(
        again.read(realProvider).snapshot!.friends.single.toPerson().photo,
        jpeg,
      );
      again.dispose();
    });

    test('a stranger or a blocked friend cannot download it', () async {
      await connect();
      await me.c.setPhoto(jpeg);
      final stranger = Phone(server, clock);
      await stranger.boot();
      await stranger.c.signIn('זר', Gender.male);
      expect(await stranger.backend.downloadPhoto(me.backend.userId!), isNull);
      expect(await yoni.backend.downloadPhoto(me.backend.userId!), jpeg);
      await me.c.block(me.s.snapshot!.friends.single);
      expect(await yoni.backend.downloadPhoto(me.backend.userId!), isNull);
      stranger.dispose();
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
