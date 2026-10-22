import 'dart:convert';

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
  // A call needs at least one number (no offer otherwise), so I have one
  // unless a test says otherwise ('' = none).
  Future<void> connect({
    String? myPhone = '0521111111',
    String? yoniPhone,
  }) async {
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

  test(
    'no number → "add your number" (again a week after "not now")',
    () async {
      await me.c.signIn('נתנאל', Gender.male, phone: '');
      expect(me.c.showAddNumber, isTrue);
      me.c.addNumberLater();
      expect(me.c.showAddNumber, isFalse);
      now = now.add(const Duration(days: 8));
      expect(me.c.showAddNumber, isTrue);
      await me.c.setMyPhone('0521111111');
      expect(me.c.showAddNumber, isFalse);
    },
  );

  test(
    'my invitation used → "new in your list" once; not for the one who joined',
    () async {
      await connect();
      expect(me.c.newFriend?.name, 'יוני');
      expect(yoni.c.newFriend, isNull);
      me.c.dismissNewFriend(me.c.newFriend!);
      expect(me.c.newFriend, isNull);
    },
  );

  test('joining without a phone number works', () async {
    await me.c.signIn('נתנאל', Gender.male, phone: '');
    expect(me.s.phase, RealPhase.ready);
    expect(me.s.myPhone, isNull);
  });

  test('no answer within 30 seconds → stop waiting, gently', () async {
    await connect(yoniPhone: '050-123-4567');
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await refreshBoth();
    final offer = currentOffer(me.s, now)!;
    await me.c.respond(offer, accept: true);
    expect(waitingOffer(me.s, now)?.id, offer.id);

    now = now.add(const Duration(seconds: 26));
    me.c.checkWaiting();
    await pump();
    expect(waitingOffer(me.s, now)?.id, offer.id, reason: 'still waiting');

    now = now.add(const Duration(seconds: 5));
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
    expect(await me.c.unlockAdmin('test-owner-code'), isTrue);
    await pump();
    final stats = await me.c.appStats(7);
    expect(stats!['later'], 1);
    expect(stats['declined'], 1);
  });

  test('first steps: "mornings" → a Sun–Thu routine at 7:30', () async {
    await me.c.signIn('נתנאל', Gender.male);
    expect(me.s.firstRun, FirstRunStep.photo, reason: 'a picture first');
    me.c.firstRunNext(); // photo → contacts
    me.c.firstRunNext(); // contacts → result
    me.c.firstRunNext(); // result → routine
    expect(me.s.firstRun, FirstRunStep.routine);
    await me.c.firstRunRoutines(morning: 7 * 60 + 30);
    expect(me.s.firstRun, FirstRunStep.permissions, reason: 'then permissions');
    me.c.firstRunNext();
    expect(me.s.firstRun, FirstRunStep.magic);
    final r = me.s.routines.single;
    expect(r.minuteOfDay, 7 * 60 + 30);
    expect(r.weekdays, {7, 1, 2, 3, 4});
    expect(me.driving.routinesJson, contains('"hour":7,"minute":30'));
  });

  test('a NEW permission missing after an update: Home asks once', () async {
    await connect();
    while (me.s.firstRun != null) {
      me.c.firstRunNext();
    }
    me.driving.fullScreen = false;
    me.driving.background = false;
    expect(
      await me.c.shouldAskMissingPermissions(),
      isFalse,
      reason: 'all were just asked in the first steps',
    );
    // A phone from before "full screen" existed (asked about four).
    me.store.setString('real.permAsk.v2', null);
    expect(await me.c.shouldAskMissingPermissions(), isTrue);
    expect(
      await me.c.shouldAskMissingPermissions(),
      isFalse,
      reason: 'once, not on every update',
    );
  });

  test('"what\'s new" once for people who had the app; a broken setting '
      'shows one line until fixed or hidden', () async {
    await connect();
    while (me.s.firstRun != null) {
      me.c.firstRunNext();
    }
    expect(me.c.showWhatsNew, isFalse, reason: 'new here: nothing is new');
    me.store.setString('real.whatsNew.v1', null); // had an older version
    expect(me.c.showWhatsNew, isTrue);
    me.c.dismissWhatsNew();
    expect(me.c.showWhatsNew, isFalse);

    me.driving.notifications = false;
    expect(await me.c.healthIssue(), PhonePermission.notifications);
    me.c.hideHealthIssue(PhonePermission.notifications);
    expect(await me.c.healthIssue(), isNot(PhonePermission.notifications));
  });

  test('an update with no new permission: nothing pops up', () async {
    await connect();
    me.store.setString('real.permAsk.v2', null);
    me.driving.background = false; // missing, but asked about before
    expect(await me.c.shouldAskMissingPermissions(), isFalse);
  });

  test('two calls in one drive: "when again?" is asked for each', () async {
    await connect();
    final dana = Phone(server, clock);
    await dana.boot();
    await dana.c.signIn('דנה', Gender.female, phone: '0543333333');
    final msg = await me.c.createInviteMessage();
    dana.c.openInviteText(msg!);
    await pump();
    await dana.c.acceptInvite();
    await yoni.c.startAvailability(AvailabilityMode.free, 60);
    await dana.c.startAvailability(AvailabilityMode.free, 60);
    await me.c.startAvailability(AvailabilityMode.free, 60);
    final names = <String>[];
    for (var i = 0; i < 2; i++) {
      await me.c.refresh();
      await pump();
      final o = currentOffer(me.s, now)!;
      final other = o.otherId(me.backend.userId!) == yoni.backend.userId
          ? yoni
          : dana;
      await me.c.respond(o, accept: true);
      await other.c.refresh();
      await other.c.respond(currentOffer(other.s, now)!, accept: true);
      now = now.add(const Duration(seconds: 16));
      await me.c.refresh();
      await pump();
      expect(me.s.callStage, CallStage.waitingForTheirCall);
      names.add(me.s.call!.other.name);
      // The call ends; "when again?" left unanswered while driving on.
      me.c.finishCall();
      await pump();
      now = now.add(const Duration(minutes: 7));
    }
    expect(names.toSet(), {'יוני', 'דנה'});
    expect(me.s.callStage, CallStage.feedback);
    expect(me.s.call!.other.name, names[1]);
    await me.c.afterCall(3);
    expect(me.s.callStage, CallStage.feedback, reason: 'the first one too');
    expect(me.s.call!.other.name, names[0]);
    me.c.skipFeedback();
    expect(me.s.callStage, CallStage.none);
    dana.dispose();
  });

  test('first steps: all the permissions at once ("allow all")', () async {
    await connect();
    me.driving.notifications = false;
    me.driving.background = false;
    var p = await me.c.phonePermissions();
    expect(
      [p.notifications, p.calls, p.mic, p.background, p.autoDriving],
      [false, false, false, false, false],
    );
    await me.c.askAllPermissions();
    p = await me.c.phonePermissions();
    expect(p.notifications && p.mic && p.background, isTrue);
    expect(me.dialer.asked, 1, reason: 'phone calls asked too');
    expect(p.autoDriving, isFalse, reason: 'driving detection stays a choice');
    expect(me.driving.enabled, isFalse);
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
      expect(await me.c.unlockAdmin('test-owner-code'), isTrue);
      await pump(10);
      expect((await me.c.ownerNotes(reports: false))!.single.body, 'אהבתי');
      final r = (await me.c.ownerNotes(reports: true))!.single;
      expect(r.title, 'יוני → נתנאל');
    },
  );

  test('bring back someone I removed (only I can)', () async {
    await connect();
    final yoniProfile = me.s.snapshot!.friends.single;
    await me.c.unmatch(yoniProfile);
    await refreshBoth();
    expect(me.s.snapshot!.friends, isEmpty);
    // Yoni didn't remove anyone: nothing to bring back on his side.
    expect(await yoni.c.removedFriends(), isEmpty);
    expect(
      await yoni.backend.restoreFriend(me.backend.userId!),
      isFalse,
      reason: 'I removed Yoni — he cannot force his way back',
    );
    final mine = (await me.c.removedFriends())!;
    expect(mine.single.name, 'יוני');
    expect(await me.c.restoreFriend(mine.single), isTrue);
    await yoni.c.refresh();
    expect(me.s.snapshot!.friends.single.name, 'יוני');
    expect(yoni.s.snapshot!.friends.single.name, 'נתנאל');
    expect(await me.c.removedFriends(), isEmpty);
  });

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
    'a call I missed in the app still asks "when to suggest X again?"',
    () async {
      await connect(myPhone: '', yoniPhone: '050-123-4567');
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      // My app is closed; Yoni says yes and we talk (e.g. from the
      // notification). I open the app half an hour later.
      me.dispose();
      await yoni.c.refresh();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      now = now.add(const Duration(minutes: 30));
      ProviderContainer open() => ProviderContainer(
        overrides: [
          realBackendProvider.overrideWithValue(me.backend),
          localStoreProvider.overrideWithValue(me.store),
          realClockProvider.overrideWithValue(clock),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          phoneDialerProvider.overrideWithValue(me.dialer),
        ],
      );
      var again = open();
      again.read(realProvider);
      await pump();
      await again.read(realProvider.notifier).refresh();
      expect(me.dialer.dialed, isEmpty, reason: 'too late to dial now');
      expect(again.read(realProvider).callStage, CallStage.feedback);
      expect(again.read(realProvider).call?.other.name, 'יוני');
      await again.read(realProvider.notifier).afterCall(7);
      again.dispose();
      // Asked once: not again after another start.
      again = open();
      again.read(realProvider);
      await pump();
      await again.read(realProvider.notifier).refresh();
      expect(again.read(realProvider).callStage, CallStage.none);
      again.dispose();
    },
  );

  test(
    'a call that already ended is not started again when I open the app',
    () async {
      await connect(myPhone: '', yoniPhone: '050-123-4567');
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      me.dispose();
      await yoni.c.refresh();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      // A short talk; Yoni answers "when again?" (that touches the offer).
      now = now.add(const Duration(minutes: 3));
      yoni.c.finishCall();
      await yoni.c.afterCall(0);
      now = now.add(const Duration(minutes: 1));
      final again = ProviderContainer(
        overrides: [
          realBackendProvider.overrideWithValue(me.backend),
          localStoreProvider.overrideWithValue(me.store),
          realClockProvider.overrideWithValue(clock),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          phoneDialerProvider.overrideWithValue(me.dialer),
        ],
      );
      again.read(realProvider);
      await pump();
      await again.read(realProvider.notifier).refresh();
      expect(me.dialer.dialed, isEmpty);
      expect(
        again.read(realProvider).callStage,
        CallStage.feedback,
        reason: 'not "waiting for Yoni\'s call" for a call that is over',
      );
      again.dispose();
    },
  );

  test(
    'both free → both asked → both yes → I call Yoni on the phone',
    () async {
      await connect(myPhone: '', yoniPhone: '050-123-4567');
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
      await me.c.afterCall(0);
      expect(me.s.callStage, CallStage.none);
      expect(server.feedback.single['talked'], isTrue);
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
    await me.c.afterCall(0);
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

  test('a phone call closes my open questions (D-121)', () async {
    await connect();
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    expect(currentOffer(me.s, now), isNotNull);
    server.phoneCall(me.backend.userId!, true);
    await me.c.refresh();
    await yoni.c.refresh();
    expect(currentOffer(me.s, now), isNull);
    expect(currentOffer(yoni.s, now), isNull);
  });

  test(
    'free as "driving": the phone knows (full-screen question, D-130)',
    () async {
      await connect();
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await pump(20);
      expect(me.driving.driving, isTrue);
      await me.c.stopAvailability();
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await pump(20);
      expect(me.driving.driving, isFalse);
    },
  );

  test('the "who\'s free" widget gets what home shows (D-133)', () async {
    await connect();
    me.driving.friendsWidget = true;
    await me.c.reloadDriving();
    await yoni.c.startAvailability(AvailabilityMode.driving, 30);
    await me.c.refresh();
    final list = jsonDecode(me.driving.widgetJson!) as List;
    expect(list, hasLength(1));
    expect(list.single['name'], 'יוני');
    expect(list.single['mode'], 'driving');
    expect(list.single['busy'], isFalse);
    await yoni.c.stopAvailability();
    await me.c.refresh();
    expect(jsonDecode(me.driving.widgetJson!), isEmpty);
  });

  test('instant updates stopped: the app opens them again', () async {
    await connect();
    me.backend.dropLive();
    await Future<void>.delayed(Duration.zero);
    expect(me.s.live, LiveStatus.error);
    me.c.debugTick();
    me.c.debugTick(); // at most once a minute
    await Future<void>.delayed(Duration.zero);
    expect(me.backend.reconnects, 1);
    expect(me.s.live, LiveStatus.connected);
  });

  test(
    'a call through the app ends when the phone call ends (D-131)',
    () async {
      await connect();
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await yoni.c.refresh();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await me.c.refresh();
      expect(
        busyFriends(me.s, now),
        hasLength(1),
        reason: 'Yoni is in our call',
      );
      server.phoneCall(yoni.backend.userId!, true);
      server.phoneCall(yoni.backend.userId!, false);
      await me.c.refresh();
      expect(busyFriends(me.s, now), isEmpty, reason: 'he hung up');
    },
  );

  test('test info says why a friend looks "in a call"', () async {
    await connect();
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    server.phoneCall(yoni.backend.userId!, true);
    await me.c.refresh();
    expect(
      me.c.diagnostics(),
      contains('friends in a call: יוני (phone until'),
    );
    server.phoneCall(yoni.backend.userId!, false);
    await me.c.refresh();
    expect(me.c.diagnostics(), contains('friends in a call: —'));
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

  test(
    'nobody has a number → no question (the call couldn\'t happen)',
    () async {
      await connect(myPhone: '');
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await yoni.c.refresh();
      expect(currentOffer(me.s, now), isNull);
      expect(currentOffer(yoni.s, now), isNull);
      // Both still see each other free.
      expect(freeFriends(me.s, now), hasLength(1));
    },
  );

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

  test(
    'opened on the screen by a question: asked aloud at once (D-138)',
    () async {
      await connect();
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      // The phone is locked, the app behind: the question arrives.
      me.c.debugLifecycle(AppLifecycleState.paused);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      final id = server.offers.values
          .firstWhere((o) => o.status == OfferStatus.pending)
          .id;
      // It opens the app on the screen with the name from the notification.
      me.voice.simulateAnswer(VoiceAnswer.yes);
      me.driving.pendingAction = LaunchAction(
        id,
        accept: false,
        wake: true,
        name: 'יוני',
        kind: 'ask',
      );
      me.c.debugLifecycle(AppLifecycleState.resumed);
      await pump(50);
      expect(me.voice.spoken.first, 'ליוני יש זמן. לדבר?');
      expect(
        me.voice.spoken.where((x) => x == 'ליוני יש זמן. לדבר?'),
        hasLength(1),
        reason: 'asked once, not again after loading',
      );
      expect(waitingOffer(me.s, now)?.id, id, reason: '"yes" answered it');
      expect(
        me.voice.spoken,
        contains('קיבלתי. מחברים אותך עם יוני.'),
        reason: 'the "yes" is said back',
      );
    },
  );

  test('driving: no answer → asked once more, twice in all', () async {
    await connect();
    await me.c.startAvailability(AvailabilityMode.driving, 30);
    me.voice
      ..simulateAnswer(VoiceAnswer.none)
      ..simulateAnswer(VoiceAnswer.yes);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    await pump(50);
    expect(me.voice.spoken.where((x) => x == 'ליוני יש זמן. לדבר?').length, 2);
    expect(waitingOffer(me.s, now), isNotNull, reason: 'the second "yes"');
  });

  test('after a call: quick connect still works; my pause shows and can be '
      'cancelled', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0501234567');
    // A regular call → 3 automatic quiet days for the pair.
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    await me.c.respond(currentOffer(me.s, now)!, accept: true);
    await yoni.c.refresh();
    await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
    await pump();
    await me.c.refresh();
    me.c.finishCall();
    me.c.skipFeedback();
    yoni.c.finishCall();
    yoni.c.skipFeedback();
    final yoniP = me.s.snapshot!.friends.single;
    var p = me.s.snapshot!.pauses[yoniP.id];
    expect(p?.chosen, isFalse, reason: 'the automatic 3 days');
    // Quick connect on both sides: the automatic pause doesn't stop it.
    await me.c.setQuick(yoniP, true);
    await yoni.c.setQuick(yoni.s.snapshot!.friends.single, true);
    now = now.add(const Duration(hours: 2));
    await me.c.startAvailability(AvailabilityMode.driving, 30);
    await yoni.c.startAvailability(AvailabilityMode.driving, 30);
    await me.c.refresh();
    await pump(20);
    expect(me.s.call?.quick, isTrue, reason: 'quick connect despite the pause');
    me.c.finishCall();
    me.c.skipFeedback();
    yoni.c.finishCall();
    yoni.c.skipFeedback();
    // Later that day (quick connect: once a day): no regular question
    // either — the automatic pause still holds for those.
    now = now.add(const Duration(hours: 1));
    await me.c.startAvailability(AvailabilityMode.free, 30);
    await yoni.c.startAvailability(AvailabilityMode.free, 30);
    await me.c.refresh();
    await pump(20);
    expect(currentOffer(me.s, now), isNull);
    expect(me.s.call, isNull);
    // "Cancel" on the card removes my pause (and the automatic one there).
    await me.c.refresh();
    expect(me.s.snapshot!.pauses, contains(yoniP.id));
    await me.c.clearPause(yoniP);
    expect(me.s.snapshot!.pauses, isEmpty);
    expect(server.snoozes, isEmpty);
  });

  test(
    '"any time" after a call: no hidden pause left on either side',
    () async {
      await connect(myPhone: '0521111111', yoniPhone: '0501234567');
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await yoni.c.refresh();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await pump();
      await me.c.refresh();
      me.c.finishCall();
      await me.c.afterCall(0);
      expect(server.snoozes, isEmpty, reason: 'mine and their automatic one');
      // A pause Yoni chose stays (it's Yoni's).
      yoni.c.finishCall();
      await yoni.c.afterCall(7);
      expect(server.snoozes.length, 1);
    },
  );

  test('a pause I chose ("in a week") stops quick connect too', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0501234567');
    final yoniP = me.s.snapshot!.friends.single;
    await me.c.setQuick(yoniP, true);
    await yoni.c.setQuick(yoni.s.snapshot!.friends.single, true);
    server.snoozes['${me.backend.userId}|${yoniP.id}'] = now.add(
      const Duration(days: 7),
    );
    server.chosenSnoozes.add('${me.backend.userId}|${yoniP.id}');
    await me.c.startAvailability(AvailabilityMode.driving, 30);
    await yoni.c.startAvailability(AvailabilityMode.driving, 30);
    await me.c.refresh();
    await pump(20);
    expect(me.s.call, isNull);
    expect(currentOffer(me.s, now), isNull);
    expect(me.s.snapshot!.pauses[yoniP.id]?.chosen, isTrue);
  });

  test('quick connect per friend: both turn it on → no question', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0501234567');
    final yoniP = me.s.snapshot!.friends.single;
    await me.c.setQuick(yoniP, true);
    expect(me.s.snapshot!.quickMine, {yoniP.id});
    expect(me.s.snapshot!.quickBoth(yoniP.id), isFalse);
    // Yoni sees, once, "Netanel wants quick connect with you".
    await yoni.c.refresh();
    final ask = yoni.c.quickAsk;
    expect(ask?.id, me.backend.userId);
    await yoni.c.setQuick(ask!, true);
    expect(yoni.c.quickAsk, isNull);
    expect(yoni.s.snapshot!.quickBoth(me.backend.userId!), isTrue);
    // Both free: no question — the call starts (5 seconds to cancel).
    await me.c.startAvailability(AvailabilityMode.driving, 30);
    await yoni.c.startAvailability(AvailabilityMode.driving, 30);
    await me.c.refresh();
    await pump(20);
    expect(currentOffer(me.s, now), isNull);
    expect(me.s.call?.quick, isTrue);
    // Removing the friend removes the switch too.
    await me.c.unmatch(yoniP);
    expect(server.quickPicks, isEmpty);
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
      // The first minutes of a trip: no question (D-106) — until "ready now".
      expect(currentOffer(me.s, now), isNull);
      expect(myActiveAvailability(me.s, now)!.quietAt(now), isTrue);
      await me.c.readyNow();
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
        // No answer → no more questions until I say "still free" (D-104).
        expect(myActiveAvailability(me.s, now)!.missed, isTrue);
        now = now.add(const Duration(minutes: 5, seconds: 1));
        await me.c.refresh();
        expect(currentOffer(me.s, now), isNull, reason: 'not asked again');
        await me.c.stillFree();
        expect(myActiveAvailability(me.s, now)!.missed, isFalse);
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

    test('quick connect on both sides → connected without asking', () async {
      await connect(myPhone: '0521111111', yoniPhone: '0532222222');
      await me.c.setQuick(me.s.snapshot!.friends.single, true);
      await yoni.c.setQuick(yoni.s.snapshot!.friends.single, true);
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
    });

    test('quick connect: either side can cancel in the 5 seconds', () async {
      await connect(myPhone: '0521111111', yoniPhone: '0532222222');
      await me.c.setQuick(me.s.snapshot!.friends.single, true);
      await yoni.c.setQuick(yoni.s.snapshot!.friends.single, true);
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

    test('quick connect: a cancel after the 5 seconds says so', () async {
      await connect(myPhone: '0521111111', yoniPhone: '0532222222');
      await me.c.setQuick(me.s.snapshot!.friends.single, true);
      await yoni.c.setQuick(yoni.s.snapshot!.friends.single, true);
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await yoni.c.refresh();
      await pump(50);
      expect(yoni.s.callStage, CallStage.connecting);
      now = now.add(const Duration(seconds: 6));
      await yoni.c.cancelCall();
      // Not pretended: the call goes on, and Yoni is told why.
      await pump(700);
      expect(yoni.s.notice?.kind, RealNoticeKind.quickTooLate);
      expect(yoni.s.callStage, isNot(CallStage.none));
      expect(me.dialer.dialed.length + yoni.dialer.dialed.length, 1);
    });

    test('ending a call frees me on the server at once', () async {
      await connect(myPhone: '0521111111', yoniPhone: '0532222222');
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await yoni.c.refresh();
      final offer = currentOffer(me.s, now)!;
      await me.c.respond(offer, accept: true);
      await yoni.c.refresh();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await pump(50);
      expect(yoni.s.call, isNotNull);
      yoni.c.finishCall();
      await pump(20);
      expect(yoni.s.callStage, CallStage.feedback);
      final o = server.offers[offer.id]!;
      expect(o.a == yoni.backend.userId ? o.endedA : o.endedB, isTrue);
    });

    test('one-sided quick connect is just a normal question', () async {
      await connect();
      await me.c.setQuick(me.s.snapshot!.friends.single, true);
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
        final saved = me.s.snapshot!.circles.firstWhere(
          (c) => c.name == 'משפחה' && c.memberIds.isEmpty,
        );
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
      // Yoni is told once that I added him; I'm not (I did it myself).
      expect(yoni.c.newFriend?.name, 'נתנאל');
      expect(me.c.newFriend, isNull);
      yoni.c.dismissNewFriend(yoni.c.newFriend!);
      expect(yoni.c.newFriend, isNull);
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

    test('"why isn\'t X here?" goes step by step (D-132)', () async {
      await connect(myPhone: '0521111111', yoniPhone: '0532222222');
      me.contacts
        ..numbers = ['53-222-2222']
        ..names = {'53-222-2222': 'יוני'}
        ..asked = true;
      final lines = await me.c.whyNotShown('+972 053 222 2222');
      expect(lines, [
        'המספר בצורה אחידה: +972532222222',
        'נמצא באנשי הקשר: יוני, שמור כ-53-222-2222.',
        'הוא כבר חבר שלך.',
      ]);
      final nobody = await me.c.whyNotShown('054-999-9999');
      expect(nobody.last, contains('אין ב-DriveBond משתמש'));
      expect(await me.c.whyNotShown('abc'), ['זה לא נראה כמו מספר טלפון.']);
    });

    test('phone formats all match', () {
      expect(e164Phone('052-111-1111'), '+972521111111');
      expect(e164Phone('+972 52 111 1111'), '+972521111111');
      expect(e164Phone('00972521111111'), '+972521111111');
      expect(e164Phone('972521111111'), '+972521111111');
      expect(e164Phone('12'), isNull);
      // Saved differently on another phone (D-132).
      expect(e164Phone('+972-050-680-2360'), '+972506802360');
      expect(e164Phone('50-680-2360'), '+972506802360');
      expect(e164Phone('+1 212 555 0100'), '+12125550100');
      // Copied from the dialer, wrapped in direction marks.
      expect(e164Phone('\u202a+972 50-680-2360\u202c'), '+972506802360');
      expect(normalizePhone('\u202a050-680-2360\u202c'), '0506802360');
      // Numbers nobody could ever find are refused.
      expect(normalizePhone('+0501234567'), isNull);
      expect(normalizePhone('123456'), isNull);
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
      expect(
        me.s.snapshot!.lastTalk[yoniId],
        isNotNull,
        reason: 'a call counts as a talk right away (D-108)',
      );
      me.c.finishCall();
      await me.c.afterCall(0);
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
      await me.c.afterCall(0);
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

  test('after a call: once I closed it, I can ask her again (D-142)', () async {
    await connect(myPhone: '0521111111', yoniPhone: '0532222222');
    await me.c.startAvailability(AvailabilityMode.free, 60);
    await yoni.c.startAvailability(AvailabilityMode.free, 60);
    await me.c.refresh();
    await me.c.respond(currentOffer(me.s, now)!, accept: true);
    await yoni.c.refresh();
    await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
    await me.c.refresh();
    await pump();
    final y = me.s.snapshot!.friends.single;
    expect(await me.c.askWhy(y), 'busy', reason: 'mid-call: in a call');
    // I answer "how was it? — any time"; Yoni never does.
    me.c.finishCall();
    await me.c.afterCall(0);
    now = now.add(const Duration(minutes: 3));
    await me.c.refresh();
    expect(await me.c.askWhy(y), 'ok');
    expect(await me.c.askFriend(y), isTrue);
  });

  test(
    '"we didn\'t talk" takes it back; "in a week" pauses the pair',
    () async {
      await connect(myPhone: '0521111111', yoniPhone: '0532222222');
      Future<void> talk(int days, {bool talked = true}) async {
        await me.c.startAvailability(AvailabilityMode.free, 30);
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.refresh();
        await me.c.respond(currentOffer(me.s, now)!, accept: true);
        await yoni.c.refresh();
        await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
        await me.c.refresh();
        await pump();
        me.c.finishCall();
        await me.c.afterCall(days, talked: talked);
        yoni.c.finishCall();
        await yoni.c.afterCall(days, talked: talked);
        await me.c.refresh();
      }

      await talk(0, talked: false);
      expect(me.s.snapshot!.weekAt(now), (0, 0), reason: 'two yeses ≠ a talk');
      now = now.add(const Duration(minutes: 61));
      await talk(7);
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
    },
  );

  test(
    'owner code: too many tries says so, then the right one waits',
    () async {
      await connect();
      for (var i = 0; i < 5; i++) {
        expect(await me.c.unlockAdmin('wrong'), isFalse);
      }
      expect(me.s.lastError, isNull, reason: 'a wrong code is just "no"');
      expect(await me.c.unlockAdmin('test-owner-code'), isFalse);
      expect(me.s.lastError, 'rate_limited', reason: '"too many tries"');
      expect(me.s.admin, isFalse);
      now = now.add(const Duration(minutes: 61));
      expect(await me.c.unlockAdmin('test-owner-code'), isTrue);
    },
  );

  test('a newer version is announced (and only a newer one)', () async {
    await connect();
    me.updates.build = 10;
    await me.c.checkForUpdate(force: true);
    expect(me.s.newBuild, isNull, reason: 'same version');
    me.updates.build = 11;
    await me.c.checkForUpdate(force: true);
    expect(me.s.newBuild, 11);
  });

  test('a version published later is found without tapping', () async {
    await connect();
    me.updates.build = 10;
    await me.c.checkForUpdate();
    expect(me.s.newBuild, isNull);
    // Google Play learns about it later.
    me.updates.build = 11;
    now = now.add(const Duration(minutes: 5));
    await me.c.checkForUpdate();
    expect(me.s.newBuild, isNull, reason: 'not every few seconds');
    now = now.add(const Duration(minutes: 30));
    await me.c.checkForUpdate();
    expect(me.s.newBuild, 11, reason: 'checked again within half an hour');
  });

  group('stage 5', () {
    test('an older server is said clearly', () async {
      me.backend.schema = 12;
      await connect();
      await pump(10);
      expect(me.s.serverOutdated, isTrue);
      expect(me.c.diagnostics(), contains('server schema: 12 (app needs 50)'));
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
        // Not uploaded again by itself, even after a day.
        now = now.add(const Duration(hours: 13));
        final later = ProviderContainer(
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
        later.read(realProvider);
        await pump(50);
        expect(server.contactHashes[me.backend.userId], isNull);
        later.dispose();
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

    test('the friend\'s name is always read aloud (no setting)', () async {
      await connect();
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await pump(10);
      expect(me.voice.spoken.last, contains('יוני'));
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

  group('who sees that I\'m free', () {
    RealCircle circleNamed(Phone p, String name) =>
        p.s.snapshot!.circles.firstWhere((c) => c.name == name);

    test('family, friends and work are ready (empty) after joining', () async {
      await connect();
      expect(me.s.snapshot!.circles.map((c) => c.name).toSet(), {
        'משפחה',
        'חברים',
        'עבודה',
      });
      expect(me.s.snapshot!.circles.every((c) => c.memberIds.isEmpty), isTrue);
      expect(
        me.s.snapshot!.circles.every((c) => c.showModes == null),
        isTrue,
        reason: 'always, until I change it',
      );
    });

    test(
      'work: never → the boss neither sees me free nor gets asked',
      () async {
        await connect();
        final boss = me.s.snapshot!.friends.single;
        await me.c.setFriendCircles(boss, {circleNamed(me, 'עבודה').id});
        await me.c.setCircleRule(circleNamed(me, 'עבודה'), ShowRule.never);
        await me.c.startAvailability(AvailabilityMode.breakTime, 30);
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.refresh();
        await yoni.c.refresh();
        // He sees nothing (not even that I hid: I'm simply not free).
        expect(freeFriends(yoni.s, now), isEmpty);
        expect(currentOffer(yoni.s, now), isNull);
        // I still see him free, but no question comes either.
        expect(freeFriends(me.s, now), hasLength(1));
        expect(currentOffer(me.s, now), isNull);
        // Back to "always": he sees me, and we're asked.
        await me.c.setCircleRule(circleNamed(me, 'עבודה'), ShowRule.always);
        await me.c.refresh();
        await yoni.c.refresh();
        expect(freeFriends(yoni.s, now), hasLength(1));
        expect(currentOffer(me.s, now), isNotNull);
      },
    );

    test('family: only while driving', () async {
      await connect();
      final dad = me.s.snapshot!.friends.single;
      await me.c.setFriendCircles(dad, {circleNamed(me, 'משפחה').id});
      await me.c.setCircleRule(
        circleNamed(me, 'משפחה'),
        const ShowRule({AvailabilityMode.driving}),
      );
      await me.c.startAvailability(AvailabilityMode.breakTime, 30);
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), isEmpty, reason: 'a break: hidden');
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), hasLength(1), reason: 'driving: seen');
    });

    test('in two groups: seen only if both allow', () async {
      await connect();
      final f = me.s.snapshot!.friends.single;
      await me.c.setFriendCircles(f, {
        circleNamed(me, 'חברים').id,
        circleNamed(me, 'עבודה').id,
      });
      await me.c.setCircleRule(circleNamed(me, 'עבודה'), ShowRule.never);
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), isEmpty);
      // Out of "work" → "friends" (always) decides.
      await me.c.setFriendCircles(f, {circleNamed(me, 'חברים').id});
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), hasLength(1));
    });

    test('"everyone else" covers friends in no group', () async {
      await connect();
      await me.c.setOthersRule(ShowRule.never);
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), isEmpty);
      expect(currentOffer(yoni.s, now), isNull);
      expect(me.s.snapshot!.othersModes, isEmpty);
      // In "friends" (always): seen again.
      await me.c.setFriendCircles(me.s.snapshot!.friends.single, {
        circleNamed(me, 'חברים').id,
      });
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), hasLength(1));
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

  test('from the Google Play app the link asks the page for the store', () {
    final msg = inviteMessageFor(
      lookupAppLocalizations(const Locale('he')),
      token: 'AbCdEfGhIjKlMnOpQrStUv',
      baseUrl: 'https://invite.example/',
      apkUrl: 'https://example.com/app.apk',
      store: true,
    );
    expect(
      msg,
      contains('https://invite.example/i/AbCdEfGhIjKlMnOpQrStUv?p=1'),
    );
    expect(parseInviteToken(msg), 'AbCdEfGhIjKlMnOpQrStUv');
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

  group('calm and private (D-103…D-106)', () {
    test('tap a free friend → they are asked; my tap is my yes', () async {
      await connect();
      await yoni.c.startAvailability(AvailabilityMode.walking, 30);
      await me.c.startAvailability(AvailabilityMode.free, 30);
      // (The matching may have asked us already: say no to start clean.)
      await yoni.c.refresh();
      if (currentOffer(yoni.s, now) case final o?) {
        await yoni.c.respond(o, accept: false);
      }
      now = now.add(const Duration(hours: 1));
      await me.c.startAvailability(AvailabilityMode.free, 60);
      await yoni.c.startAvailability(AvailabilityMode.walking, 60);
      await refreshBoth();
      if (currentOffer(me.s, now) case final o?) {
        await me.c.cancelWaiting(o);
      }
      await refreshBoth();
      final friend = me.s.snapshot!.friend(yoni.backend.userId!)!;
      expect(await me.c.askFriend(friend), isTrue);
      expect(waitingOffer(me.s, now), isNotNull, reason: 'I wait for Yoni');
      await yoni.c.refresh();
      final o = currentOffer(yoni.s, now)!;
      expect(o.direct, isTrue);
      expect(
        o.askedBy(me.backend.userId!),
        isTrue,
        reason: '"Netanel wants to talk with you"',
      );
      expect(o.sharedUntil, isNotNull, reason: 'until when both are free');
      await yoni.c.respond(o, accept: true);
      await pump(20);
      expect(yoni.s.callStage, isNot(CallStage.none));
    });

    test('only friends I can really ask are listed (D-107)', () async {
      await connect();
      await yoni.c.startAvailability(AvailabilityMode.walking, 30);
      await me.c.refresh();
      expect(askableFriends(me.s, now), hasLength(1));
      // Yoni doesn't want questions from me: not listed (not even free).
      await yoni.c.setRating(yoni.s.snapshot!.friend(me.backend.userId!)!, 0);
      await me.c.refresh();
      expect(freeFriends(me.s, now), hasLength(1));
      expect(askableFriends(me.s, now), isEmpty);
    });

    test('while driving: a look at the regular screen, then back', () async {
      await connect();
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      expect(showDriverScreen(me.s, now), isTrue);
      me.c.showNormalView(true);
      expect(showDriverScreen(me.s, now), isFalse);
      me.c.showNormalView(false);
      expect(showDriverScreen(me.s, now), isTrue);
      // The choice lasts one trip only.
      me.c.showNormalView(true);
      now = now.add(const Duration(minutes: 1));
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      expect(showDriverScreen(me.s, now), isTrue);
    });

    test('what I pressed never stops me from tapping a friend', () async {
      await connect();
      await yoni.c.startAvailability(AvailabilityMode.walking, 60);
      await me.c.startAvailability(AvailabilityMode.free, 60);
      await me.c.refresh();
      // I said "not now" to the app's suggestion…
      final o = currentOffer(me.s, now)!;
      await me.c.respond(o, accept: false);
      // …and I don't want him suggested automatically.
      await me.c.setRating(me.s.snapshot!.friend(yoni.backend.userId!)!, 0);
      await me.c.refresh();
      expect(askableFriends(me.s, now).map((f) => f.$1.id), [
        yoni.backend.userId,
      ], reason: 'my own choices only stop the automatic suggestions');
      expect(
        await me.c.askFriend(me.s.snapshot!.friend(yoni.backend.userId!)!),
        isTrue,
      );
    });

    test(
      'after a call: 3 quiet days unless I choose otherwise (D-108)',
      () async {
        await connect(myPhone: '0521111111', yoniPhone: '0532222222');
        Future<void> callAndSkip() async {
          await me.c.startAvailability(AvailabilityMode.free, 30);
          await yoni.c.startAvailability(AvailabilityMode.free, 30);
          await me.c.refresh();
          await me.c.respond(currentOffer(me.s, now)!, accept: true);
          await yoni.c.refresh();
          await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
          await me.c.refresh();
          await pump();
          me.c.finishCall();
          me.c.skipFeedback();
          yoni.c.finishCall();
          yoni.c.skipFeedback();
        }

        await callAndSkip();
        await me.c.refresh();
        expect(me.s.snapshot!.weekAt(now), (1, 1), reason: 'a call is a talk');
        now = now.add(const Duration(days: 2));
        await me.c.startAvailability(AvailabilityMode.free, 30);
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.refresh();
        expect(currentOffer(me.s, now), isNull, reason: 'paused 3 days');
        // Tapping still asks.
        final yoniP = me.s.snapshot!.friend(yoni.backend.userId!)!;
        expect(await me.c.askFriend(yoniP), isTrue);
        await me.c.cancelWaiting(waitingOffer(me.s, now)!);
        now = now.add(const Duration(days: 1, minutes: 1));
        await me.c.startAvailability(AvailabilityMode.free, 30);
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.refresh();
        expect(currentOffer(me.s, now), isNotNull, reason: 'after 3 days');
      },
    );

    test('asking when not free is refused clearly', () async {
      await connect();
      await yoni.c.startAvailability(AvailabilityMode.walking, 30);
      await me.c.refresh();
      final friend = me.s.snapshot!.friend(yoni.backend.userId!)!;
      expect(await me.c.askFriend(friend), isFalse);
      expect(me.s.notice?.kind, RealNoticeKind.askFailed);
      expect(me.s.notice?.code, 'me_not_free');
    });

    test(
      'no answer → not asked, not seen; "still free" brings me back',
      () async {
        await connect();
        await yoni.c.startAvailability(AvailabilityMode.walking, 30);
        await me.c.startAvailability(AvailabilityMode.free, 30);
        await refreshBoth();
        expect(currentOffer(me.s, now), isNotNull);
        now = now.add(const Duration(minutes: 2, seconds: 1));
        server.expireStale();
        await refreshBoth();
        expect(myActiveAvailability(me.s, now)!.missed, isTrue);
        expect(
          freeFriends(yoni.s, now),
          isEmpty,
          reason: 'friends see me as not free',
        );
        await me.c.stillFree();
        await yoni.c.refresh();
        expect(freeFriends(yoni.s, now), hasLength(1));
      },
    );

    test('free without my name: friends see only a number', () async {
      await connect();
      await me.c.setAnonymous(true);
      expect(me.s.snapshot!.status.anonymous, isTrue);
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), isEmpty);
      expect(yoni.s.snapshot!.status.hiddenFree, 1);
      // Fair: I see only a number too.
      await yoni.c.startAvailability(AvailabilityMode.walking, 30);
      await me.c.refresh();
      expect(freeFriends(me.s, now), isEmpty);
      expect(me.s.snapshot!.status.hiddenFree, 1);
    });

    test('hide "in a call": in a call I look simply not free', () async {
      await connect();
      await me.c.setHideInCall(true);
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), hasLength(1));
      server.phoneCall(me.backend.userId!, true);
      await yoni.c.refresh();
      expect(freeFriends(yoni.s, now), isEmpty);
      expect(busyFriends(yoni.s, now), isEmpty, reason: 'not "in a call"');
    });

    test(
      'hide "in a call" is mutual: I don\'t see friends in a call',
      () async {
        await connect();
        await yoni.c.setHideInCall(true);
        await me.c.startAvailability(AvailabilityMode.free, 30);
        server.phoneCall(me.backend.userId!, true);
        await yoni.c.refresh();
        expect(
          busyFriends(yoni.s, now),
          isEmpty,
          reason: 'I hide → I see none',
        );
        await yoni.c.setHideInCall(false);
        await yoni.c.refresh();
        expect(busyFriends(yoni.s, now), hasLength(1));
      },
    );

    test(
      'added from contacts by someone I have not saved → I decide',
      () async {
        await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
        yoni.contacts.numbers = ['0521111111'];
        await yoni.c.signIn('יוני', Gender.male, phone: '0532222222');
        await yoni.c.syncContacts();
        await yoni.c.addContacts(yoni.c.contactMatches);
        await me.c.refresh();
        await pump(20);
        final yoniId = yoni.backend.userId!;
        expect(me.s.snapshot!.status.pending, {yoniId});
        expect(me.c.pendingFriend?.id, yoniId);
        await me.c.startAvailability(AvailabilityMode.free, 30);
        await yoni.c.refresh();
        expect(freeFriends(yoni.s, now), isEmpty, reason: 'until I decide');
        await me.c.approveFriend(me.c.pendingFriend!);
        expect(me.c.pendingFriend, isNull);
        await yoni.c.refresh();
        expect(freeFriends(yoni.s, now), hasLength(1));
      },
    );

    test('someone I do have saved is kept without asking', () async {
      me.contacts.numbers = ['0532222222'];
      await me.c.signIn('נתנאל', Gender.male, phone: '0521111111');
      await me.c.syncContacts();
      yoni.contacts.numbers = ['0521111111'];
      await yoni.c.signIn('יוני', Gender.male, phone: '0532222222');
      await yoni.c.syncContacts();
      await yoni.c.addContacts(yoni.c.contactMatches);
      await me.c.refresh();
      await pump(20);
      // My contacts were searched before Yoni joined: looked at again.
      expect(me.s.snapshot!.status.pending, isEmpty);
      expect(me.c.pendingFriend, isNull);
    });

    test('extend my free time', () async {
      await connect();
      await me.c.startAvailability(AvailabilityMode.free, 10);
      await me.c.extendAvailability(20);
      expect(myActiveAvailability(me.s, now)!.minutesLeftAt(now), 30);
    });

    test('quiet hours: a trip does not make me free', () async {
      await connect();
      await me.c.enableAutoDriving();
      await me.c.setQuietHours(7 * 60, 9 * 60); // now is 08:00
      expect(server.autoStart(me.driving.token!), 'quiet_hours');
      await me.c.setQuietHours(null, null);
      expect(server.autoStart(me.driving.token!), 'available');
    });

    test('quiet hours only on the days I chose (D-121)', () async {
      await connect();
      await me.c.enableAutoDriving();
      final today = now.weekday % 7; // Sunday = 0
      await me.c.setQuietHours(7 * 60, 9 * 60, days: 127 ^ (1 << today));
      expect(me.s.snapshot!.status.quietDays, 127 ^ (1 << today));
      expect(server.autoStart(me.driving.token!), 'available');
      await me.c.stopAvailability();
      await me.c.setQuietHours(7 * 60, 9 * 60, days: 1 << today);
      expect(server.autoStart(me.driving.token!), 'quiet_hours');
      // Changing only the hours keeps the days.
      await me.c.setQuietHours(7 * 60, 10 * 60);
      expect(me.s.snapshot!.status.quietDays, 1 << today);
      await me.c.setQuietHours(7 * 60, 9 * 60, days: 127);
      expect(me.s.snapshot!.status.quietDays, isNull, reason: 'every day');
    });

    test('several quiet schedules (D-124)', () async {
      await connect();
      await me.c.enableAutoDriving();
      final today = now.weekday % 7; // now is 08:00
      final others = 127 ^ (1 << today);
      await me.c.setQuietRanges([
        QuietRange(7 * 60, 9 * 60, others),
        QuietRange(22 * 60, 6 * 60),
      ]);
      expect(server.autoStart(me.driving.token!), 'available');
      await me.c.stopAvailability();
      await me.c.setQuietRanges([
        QuietRange(7 * 60, 9 * 60, others),
        QuietRange(7 * 60 + 30, 8 * 60 + 30, 1 << today),
      ]);
      expect(server.autoStart(me.driving.token!), 'quiet_hours');
      expect(me.s.snapshot!.status.quietRanges, hasLength(2));
      await me.c.setQuietRanges(const []);
      expect(server.autoStart(me.driving.token!), 'available');
    });

    test(
      'one unanswered question per trip; two trips → asked to keep',
      () async {
        await connect();
        await me.c.enableAutoDriving();
        final token = me.driving.token!;
        for (var trip = 1; trip <= 2; trip++) {
          expect(server.autoStart(token), 'available');
          await me.c.readyNow();
          await yoni.c.startAvailability(AvailabilityMode.free, 60);
          await me.c.refresh();
          expect(currentOffer(me.s, now), isNotNull, reason: 'trip $trip');
          now = now.add(const Duration(minutes: 2, seconds: 1));
          server.expireStale();
          server.autoStop(token);
          await yoni.c.stopAvailability();
          now = now.add(const Duration(hours: 1));
        }
        await me.c.refresh();
        expect(me.s.snapshot!.status.autoMissed, 2);
        await me.c.keepAuto(keep: true);
        expect(me.s.snapshot!.status.autoMissed, 0);
      },
    );

    test(
      'a crash note waits on the phone until it reaches the server',
      () async {
        await connect();
        me.backend.offline = true;
        await me.c.reportCrash('flutter', StateError('boom'), StackTrace.empty);
        expect(server.crashes, isEmpty);
        me.backend.offline = false;
        await me.c.flushCrashes();
        expect(server.crashes.single['message'], contains('boom'));
        expect(server.crashes.single['build'], '10');
      },
    );
  });

  group('full review fixes (D-115)', () {
    ProviderContainer reopen(Phone p) {
      final c = ProviderContainer(
        overrides: [
          realBackendProvider.overrideWithValue(p.backend),
          localStoreProvider.overrideWithValue(p.store),
          realClockProvider.overrideWithValue(clock),
          voiceServiceProvider.overrideWithValue(SilentVoiceService()),
          phoneDialerProvider.overrideWithValue(p.dialer),
          drivingDetectorProvider.overrideWithValue(p.driving),
        ],
      );
      c.read(realProvider);
      return c;
    }

    test('a call start that fails once is tried again (not lost)', () async {
      // I have no number, Yoni has: I'm the one who dials.
      await connect(myPhone: '', yoniPhone: '050-123-4567');
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await yoni.c.refresh();
      me.backend.failStartCalls = 1;
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await me.c.refresh();
      await pump(20);
      expect(me.dialer.dialed, isEmpty, reason: 'the network blinked');
      await me.c.refresh();
      await pump(20);
      expect(me.dialer.dialed, ['0501234567'], reason: 'tried again');
      expect(
        me.driving.handledCalls,
        isNotEmpty,
        reason: 'dialing worked → no "tap to call" from the background',
      );
    });

    test(
      'opening the app while the friend is calling: "X is calling you"',
      () async {
        await connect(myPhone: '0521111111', yoniPhone: '0501234567');
        await me.c.startAvailability(AvailabilityMode.free, 30);
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.refresh();
        await me.c.respond(currentOffer(me.s, now)!, accept: true);
        me.dispose();
        await yoni.c.refresh();
        await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
        now = now.add(const Duration(minutes: 1));
        final again = reopen(me);
        await pump(20);
        await again.read(realProvider.notifier).refresh();
        await pump(20);
        expect(
          again.read(realProvider).callStage,
          CallStage.waitingForTheirCall,
          reason: 'not "neither of you has a number"',
        );
        again.dispose();
      },
    );

    test('a dial Android blocked: the background may still say so', () async {
      await connect(myPhone: '', yoniPhone: '050-123-4567');
      me.dialer.result = DialResult.failed;
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await yoni.c.refresh();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await me.c.refresh();
      await pump(20);
      expect(me.dialer.dialed, isNotEmpty);
      expect(me.driving.handledCalls, isEmpty);
      expect(me.s.callStage, CallStage.inApp);
    });

    test('a quick connect nobody started in time never dials later', () async {
      await connect(myPhone: '0521111111', yoniPhone: '0501234567');
      await me.c.setQuick(me.s.snapshot!.friends.single, true);
      await yoni.c.setQuick(yoni.s.snapshot!.friends.single, true);
      final meId = me.backend.userId!;
      final yoniId = yoni.backend.userId!;
      // Both phones in the background: nobody opens the app in time.
      me.dispose();
      yoni.dispose();
      await yoni.backend.setAvailability(AvailabilityMode.driving, 30);
      await me.backend.setAvailability(AvailabilityMode.driving, 30);
      final o = server.offers.values.single;
      expect(o.quick, isTrue);
      server
        ..markSeen(o.id, meId)
        ..markSeen(o.id, yoniId);
      now = now.add(const Duration(minutes: 3));
      final again = reopen(me);
      await pump(20);
      await again.read(realProvider.notifier).refresh();
      await pump(20);
      expect(me.dialer.dialed, isEmpty);
      expect(again.read(realProvider).callStage, CallStage.none);
      expect(server.offers[o.id]!.status, OfferStatus.cancelled);
      expect(server.offers[o.id]!.talked, isNull, reason: 'not a talk');
      again.dispose();
    });

    test('the voice question waits while the app is behind another', () async {
      await connect();
      me.c.debugLifecycle(AppLifecycleState.paused);
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await pump(20);
      expect(me.voice.spoken, isNot(contains('ליוני יש זמן. לדבר?')));
      expect(me.s.listening, isFalse, reason: 'no hidden microphone');
    });

    test(
      'back in the app: a stopped background watcher starts again',
      () async {
        await connect();
        await me.c.startAvailability(AvailabilityMode.free, 30);
        await pump(20);
        expect(me.driving.startAvailableCalls, 1);
        // Android stopped the watcher while I'm still free.
        me.driving.watching = false;
        me.c.debugLifecycle(AppLifecycleState.resumed);
        await pump(50);
        expect(me.driving.startAvailableCalls, 2);
        // Running: nothing to do.
        me.c.debugLifecycle(AppLifecycleState.resumed);
        await pump(50);
        expect(me.driving.startAvailableCalls, 2);
      },
    );

    test('"for the whole trip" tells the phone to end with the trip', () async {
      await connect();
      await me.c.startAvailability(
        AvailabilityMode.driving,
        180,
        untilTripEnds: true,
      );
      await pump(20);
      expect(me.driving.endWithTrip, isTrue);
      await me.c.stopAvailability();
      await me.c.startAvailability(AvailabilityMode.driving, 60);
      await pump(20);
      expect(me.driving.endWithTrip, isFalse);
    });

    test(
      'deleting a group: its routines go to everyone, free time ends',
      () async {
        await connect();
        final yoniId = yoni.backend.userId!;
        await me.c.saveCircle(
          RealCircle(id: '', name: 'מילואים', memberIds: {yoniId}),
        );
        final circle = me.s.snapshot!.circles.firstWhere(
          (c) => c.name == 'מילואים',
        );
        await me.c.saveRoutines([
          Routine(
            id: 'r1',
            weekdays: {1, 2, 3},
            minuteOfDay: 8 * 60,
            durationMinutes: 30,
            mode: AvailabilityMode.driving,
            circleId: circle.id,
          ),
        ]);
        await me.c.startAvailability(
          AvailabilityMode.free,
          30,
          circleId: circle.id,
        );
        await pump(20);
        expect(me.driving.availableUntil, isNotNull);
        await me.c.deleteCircle(circle);
        expect(me.s.routines.single.circleId, isNull);
        expect(me.driving.routinesJson, contains('"circle":""'));
        expect(me.driving.availableUntil, isNull, reason: 'watcher stopped');
        expect(myActiveAvailability(me.s, now), isNull);
      },
    );

    test('signing out leaves nothing of the account on the phone', () async {
      await connect();
      for (final k in [
        'real.quickAsksSeen.v1',
        'real.quickIntro.v1',
        'real.presetCircles.v1',
        'real.routines.v1',
        'real.knownFriends.v1',
      ]) {
        await me.store.setString(k, 'x');
      }
      await me.c.signOut();
      for (final k in me.store.values.keys) {
        expect(k, 'real.prefs.v1', reason: 'only the phone settings stay');
      }
      expect(me.driving.token, isNull);
    });

    test('removing a friend ends our open question', () async {
      await connect();
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      final offer = currentOffer(me.s, now)!;
      await me.c.unmatch(me.s.snapshot!.friends.single);
      expect(server.offers[offer.id]!.status, OfferStatus.cancelled);
    });

    test("an old link doesn't bring back a friend who removed me", () async {
      await connect();
      final old = await me.backend.createInvitation();
      now = now.add(const Duration(minutes: 1));
      await me.c.unmatch(me.s.snapshot!.friends.single);
      expect(
        await yoni.backend.acceptInvitation(old.token),
        AcceptResult.expired,
      );
      now = now.add(const Duration(minutes: 1));
      final fresh = await me.backend.createInvitation();
      expect(
        await yoni.backend.acceptInvitation(fresh.token),
        AcceptResult.accepted,
        reason: 'a new invitation does',
      );
    });

    test('a crash note never carries ids, numbers or emails', () {
      final text = RealController.scrubCrashText(
        'Bad offer 3f2b8c1e-1a2b-4c3d-9e8f-001122334455 for +972 52-111-2233 '
        'mail a.b@example.com at real_controller.dart:1598:7',
      );
      expect(text, isNot(contains('3f2b8c1e')));
      expect(text, isNot(contains('111')));
      expect(text, isNot(contains('example.com')));
      expect(text, contains('real_controller.dart:1598:7'));
    });

    test('a call screen left open moves on after 20 minutes', () async {
      await connect(myPhone: '0521111111', yoniPhone: '0501234567');
      await me.c.startAvailability(AvailabilityMode.free, 30);
      await yoni.c.startAvailability(AvailabilityMode.free, 30);
      await me.c.refresh();
      await me.c.respond(currentOffer(me.s, now)!, accept: true);
      await yoni.c.refresh();
      await yoni.c.respond(currentOffer(yoni.s, now)!, accept: true);
      await me.c.refresh();
      await pump(20);
      expect(me.s.callStage, CallStage.waitingForTheirCall);
      now = now.add(const Duration(minutes: 21));
      // Still on the phone call (the app behind it): nothing changes.
      me.c.debugLifecycle(AppLifecycleState.paused);
      me.c.debugTick();
      expect(me.s.callStage, CallStage.waitingForTheirCall);
      // Back in the app: on to "when again?".
      me.c.debugLifecycle(AppLifecycleState.resumed);
      me.c.debugTick();
      expect(me.s.callStage, CallStage.feedback);
    });

    test(
      "a friend who can't see I'm free can still be tapped (D-117)",
      () async {
        await connect();
        await me.c.setOthersRule(ShowRule.never);
        await yoni.c.startAvailability(AvailabilityMode.free, 30);
        await me.c.refresh();
        expect(askableFriends(me.s, now).map((f) => f.$1.id), [
          yoni.backend.userId,
        ]);
        // Not free myself: tapping marks me free and asks them.
        await me.c.startAvailability(AvailabilityMode.free, 30);
        expect(
          await me.c.askFriend(askableFriends(me.s, now).single.$1),
          isTrue,
        );
      },
    );
  });

  group('"X is on the way" (D-119)', () {
    test('a quick-connect friend is told once; tapping Talk asks', () async {
      await connect();
      yoni.driving.push = 'yoni-push-token-0123456789';
      // The app saves the phone's push address when it comes back.
      yoni.c.debugLifecycle(AppLifecycleState.resumed);
      await pump();
      expect(
        server.pushTokens['yoni-push-token-0123456789'],
        yoni.backend.userId,
      );
      await me.c.setQuick(me.s.snapshot!.friends.single, true);
      await yoni.c.setQuick(yoni.s.snapshot!.friends.single, true);
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await pump();
      expect(me.backend.lastTripTold, [yoni.backend.userId]);
      // Once a day.
      await me.c.stopAvailability();
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await pump();
      expect(me.backend.lastTripTold, isEmpty);
      // Yoni taps "Talk" on the notification.
      yoni.driving.pendingAction = LaunchAction(
        '',
        accept: false,
        askFriend: me.backend.userId,
      );
      yoni.c.debugLifecycle(AppLifecycleState.resumed);
      await pump(20);
      await me.c.refresh();
      // Both free and quick both ways: quick connect connects us (no
      // extra question, no "busy" note).
      expect(
        me.s.snapshot!.offers.where(
          (o) => o.quick && o.status == OfferStatus.accepted,
        ),
        hasLength(1),
      );
      expect(yoni.s.notice?.kind, isNot(RealNoticeKind.askFailed));
    });

    test('the switch off, or not quick both ways: nobody is told', () async {
      await connect();
      yoni.driving.push = 'yoni-push-token-0123456789';
      yoni.c.debugLifecycle(AppLifecycleState.resumed);
      await pump();
      await me.c.setQuick(me.s.snapshot!.friends.single, true);
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await pump();
      expect(me.backend.lastTripTold, isEmpty);
      await me.c.stopAvailability();
      await yoni.c.setQuick(yoni.s.snapshot!.friends.single, true);
      await me.c.setTripNotify(false);
      expect(me.s.snapshot!.status.tripNotify, isFalse);
      await me.c.startAvailability(AvailabilityMode.driving, 30);
      await pump();
      expect(me.backend.lastTripTold, isEmpty);
    });

    test('signing out forgets this phone\'s push address', () async {
      await connect();
      yoni.driving.push = 'yoni-push-token-0123456789';
      yoni.c.debugLifecycle(AppLifecycleState.resumed);
      await pump();
      expect(server.pushTokens, isNotEmpty);
      await yoni.c.signOut();
      expect(server.pushTokens, isEmpty);
    });
  });
}
