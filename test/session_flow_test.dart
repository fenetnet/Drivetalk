import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/app/session_controller.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/matching/matching_config.dart';
import 'package:drivetalk/platform/vehicle_signal_source.dart';
import 'package:drivetalk/platform/voice_service.dart';
import 'package:drivetalk/services/call_service.dart';
import 'package:drivetalk/services/fake/fake_services.dart';
import 'package:drivetalk/services/fake/fake_world.dart';
import 'package:drivetalk/services/invitation_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final config = MatchingConfig.fromJson(
  jsonDecode(File('assets/config/matching.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// A test harness around the real controller + fake services.
class Harness {
  Harness(this.async) {
    world = FakeWorld(random: Random(3))..answerDelaySeconds = 1;
    container = ProviderContainer(
      overrides: [
        matchingConfigProvider.overrideWithValue(config),
        fakeWorldProvider.overrideWithValue(world),
        voiceServiceProvider.overrideWithValue(voice),
      ],
    );
    container.listen(sessionProvider, (_, _) {});
    container.listen(driverModeProvider, (_, _) {});
  }

  final FakeAsync async;
  late final FakeWorld world;
  late final ProviderContainer container;
  final voice = SilentVoiceService();

  SessionController get ctrl => container.read(sessionProvider.notifier);
  SessionState get state => container.read(sessionProvider);
  Availability? get mine => container.read(availabilityServiceProvider).mine;
  bool get driverMode => container.read(driverModeProvider);
  FakeVehicleSignalSource get vehicle =>
      container.read(vehicleSignalProvider) as FakeVehicleSignalSource;
  FakeInvitationService get invitations =>
      container.read(invitationServiceProvider) as FakeInvitationService;

  void wait(int seconds) => async.elapse(Duration(seconds: seconds));
  void flush() => async.flushMicrotasks();

  /// Become available and wait for the options.
  void beFree({AvailabilityMode mode = AvailabilityMode.free, String? circle}) {
    ctrl.startAvailability(mode, minutes: 30, circleId: circle);
    wait(2);
  }

  void dispose() => container.dispose();
}

void run(void Function(Harness h) body) => fakeAsync((async) {
  final h = Harness(async);
  body(h);
  h.dispose();
});

void main() {
  test('free → 3 options → both agree → call → feedback', () {
    run((h) {
      h.ctrl.startAvailability(AvailabilityMode.walking, minutes: 30);
      h.flush();
      expect(h.state.phase, SessionPhase.searching);
      h.wait(2);
      expect(h.state.phase, SessionPhase.options);
      expect(h.state.options, hasLength(config.optionsShown));
      final ids = h.state.options.map((s) => s.person.id).toSet();
      expect(ids, hasLength(config.optionsShown), reason: 'no duplicates');

      // Choose the SECOND option, not the top one.
      final chosen = h.state.options[1];
      h.world.forcedAnswer = ForcedAnswer.accept;
      h.ctrl.talkNow(chosen);
      h.flush();
      // Never auto-connect: we wait for the other side.
      expect(h.state.phase, SessionPhase.waitingForAnswer);
      expect(h.state.selected!.person.id, chosen.person.id);
      h.wait(2);
      expect(h.state.phase, SessionPhase.inCall);
      expect(h.state.peer!.id, chosen.person.id);

      final callsBefore = h.world.connections[chosen.person.id]?.callCount ?? 0;
      h.ctrl.endCall();
      h.flush();
      expect(h.state.phase, SessionPhase.feedback);

      h.ctrl.submitFeedback(FeedbackRating.veryGood, wantAgain: true);
      h.flush();
      expect(h.state.phase, SessionPhase.idle);
      final conn = h.world.connections[chosen.person.id]!;
      expect(conn.callCount, callsBefore + 1);
      expect(conn.feedback.last.rating, FeedbackRating.veryGood);
      // Still available after the call ("resting").
      expect(h.mine, isNotNull);
    });
  });

  test('"we didn\'t talk" does not count as an interaction', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.accept;
      h.beFree();
      final p = h.state.options.first.person;
      final before = h.world.connections[p.id]?.callCount ?? 0;
      h.ctrl.talkNow();
      h.wait(2);
      h.ctrl.endCall();
      h.flush();
      h.ctrl.didNotTalk();
      h.flush();
      expect(h.world.connections[p.id]?.callCount ?? 0, before);
    });
  });

  test('declined → that person is removed, the other options stay', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.decline;
      h.beFree();
      final first = h.state.options.first.person.id;
      final others = h.state.options.skip(1).map((s) => s.person.id).toList();
      h.ctrl.talkNow();
      h.wait(2);
      expect(h.state.notice?.kind, NoticeKind.declinedByOther);
      expect(h.state.notice!.offersVoiceMessage, isTrue);
      expect(h.state.phase, SessionPhase.options);
      expect(h.state.options.map((s) => s.person.id), others);
      expect(h.state.skippedIds, contains(first));
    });
  });

  test('no answer within 30 seconds → move on', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.noAnswer;
      h.beFree();
      final first = h.state.options.first.person.id;
      h.ctrl.talkNow();
      h.wait(config.callAnswerTimeoutSeconds - 1);
      expect(h.state.phase, SessionPhase.waitingForAnswer);
      h.wait(2);
      expect(h.state.notice?.kind, NoticeKind.noAnswer);
      expect(h.state.options.map((s) => s.person.id), isNot(contains(first)));
    });
  });

  test('the other side stops being available while I wait', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.noAnswer;
      h.beFree();
      final p = h.state.options.first.person;
      h.ctrl.talkNow();
      h.flush();
      h.world.setAvailable(p.id, null);
      h.flush();
      expect(h.state.notice?.kind, NoticeKind.noLongerAvailable);
      expect(h.state.phase, isNot(SessionPhase.waitingForAnswer));
    });
  });

  test(
    'being blocked while waiting looks like "can\'t now" (block not revealed)',
    () {
      run((h) {
        h.world.forcedAnswer = ForcedAnswer.noAnswer;
        h.beFree();
        final p = h.state.options.first.person;
        h.ctrl.talkNow();
        h.flush();
        h.world.blockedMe.add(p.id);
        h.world.notify();
        h.flush();
        expect(h.state.notice?.kind, NoticeKind.declinedByOther);
      });
    },
  );

  test('"more options" skips everyone shown and searches again', () {
    run((h) {
      h.beFree();
      final shown = h.state.options.map((s) => s.person.id).toSet();
      h.ctrl.moreOptions();
      h.wait(2);
      expect(h.state.skippedIds, containsAll(shown));
      for (final s in h.state.options) {
        expect(shown, isNot(contains(s.person.id)));
      }
    });
  });

  test(
    'quick connect: mutual pre-approval → countdown → call, no approval wait',
    () {
      run((h) {
        expect(
          h.container
              .read(socialGraphServiceProvider)
              .isMutualQuickConnect('avi'),
          isTrue,
        );
        h.world.setAvailable('avi', 30);
        h.beFree();
        expect(h.state.phase, SessionPhase.quickConnecting);
        expect(h.state.peer!.id, 'avi');
        h.wait(config.quickConnect.countdownSeconds);
        expect(h.state.phase, SessionPhase.inCall);
        expect(h.state.peer!.id, 'avi');
        expect(h.state.callMethod, CallMethod.phone);
      });
    },
  );

  test('quick connect can be cancelled, and only once per window', () {
    run((h) {
      h.world.setAvailable('avi', 30);
      h.beFree();
      expect(h.state.phase, SessionPhase.quickConnecting);
      h.ctrl.cancelQuickConnect();
      h.wait(2);
      expect(h.state.notice?.kind, NoticeKind.quickConnectCancelled);
      expect(h.state.phase, SessionPhase.options);
      expect(h.state.options.map((s) => s.person.id), isNot(contains('avi')));
    });
  });

  test('quick connect needs BOTH sides', () {
    run((h) {
      // Michal pre-approved me, but I did not pre-approve her.
      expect(
        h.container
            .read(socialGraphServiceProvider)
            .isMutualQuickConnect('michal'),
        isFalse,
      );
      h.world.setAvailable('michal', 30);
      h.beFree(circle: 'family');
      expect(h.state.phase, SessionPhase.options);
      expect(h.state.options.single.person.id, 'michal');
    });
  });

  test('available to one circle only', () {
    run((h) {
      h.world.setAvailable('michal', 30);
      h.beFree(circle: 'family');
      // Dana, Yoni etc. are available but not in "family".
      expect(h.state.options.map((s) => s.person.id), ['michal']);
    });
  });

  test('call method: phone with connections; friends-of-friends only if both share', () {
    run((h) {
      final graph = h.container.read(socialGraphServiceProvider);
      expect(h.ctrl.callMethodFor(graph.personById('dana')!), CallMethod.phone);
      final tamar = graph.personById('tamar')!; // shares with FoF
      expect(
        h.ctrl.callMethodFor(tamar),
        CallMethod.inApp,
      ); // I don't share yet
      h.world.me = h.world.me.copyWith(sharesNumberWithFriendsOfFriends: true);
      expect(h.ctrl.callMethodFor(tamar), CallMethod.phone);
      final alon = graph.personById('alon')!; // does not share
      expect(h.ctrl.callMethodFor(alon), CallMethod.inApp);
    });
  });

  test(
    'driver mode: one option is read aloud and a spoken "yes" asks them',
    () {
      run((h) {
        h.world.forcedAnswer = ForcedAnswer.noAnswer;
        h.vehicle.simulate(VehicleTransition.enter);
        h.flush();
        h.ctrl.startAvailability(AvailabilityMode.driving, untilTripEnds: true);
        h.wait(2);
        expect(h.state.phase, SessionPhase.options);
        expect(h.voice.spoken, isNotEmpty);
        final top = h.state.options.first.person.id;
        h.voice.simulateAnswer(VoiceAnswer.yes);
        h.flush();
        expect(h.state.phase, SessionPhase.waitingForAnswer);
        expect(h.state.selected!.person.id, top);
      });
    },
  );

  test('driver mode: a spoken "no" moves to the next person', () {
    run((h) {
      h.vehicle.simulate(VehicleTransition.enter);
      h.flush();
      h.ctrl.startAvailability(AvailabilityMode.driving, untilTripEnds: true);
      h.wait(2);
      final top = h.state.options.first.person.id;
      h.voice.simulateAnswer(VoiceAnswer.no);
      h.flush();
      expect(h.state.skippedIds, contains(top));
      expect(h.state.suggestion?.person.id, isNot(top));
    });
  });

  test('automatic driving availability: opt-in, availability only', () {
    run((h) {
      // Off by default: entering a vehicle only switches to driver mode.
      expect(h.world.prefs.autoDrivingAvailability, isFalse);
      h.vehicle.simulate(VehicleTransition.enter);
      h.flush();
      expect(h.mine, isNull);
      expect(h.driverMode, isTrue);
      h.vehicle.simulate(VehicleTransition.exit);
      h.flush();
      expect(h.driverMode, isFalse);

      // Opt in.
      h.world.prefs = h.world.prefs.copyWith(autoDrivingAvailability: true);
      h.vehicle.simulate(VehicleTransition.enter);
      h.flush();
      expect(h.mine!.mode, AvailabilityMode.driving);
      expect(h.mine!.untilTripEnds, isTrue);
      expect(h.mine!.source, AvailabilitySource.automaticVehicle);
      // Even "until the trip ends" has a hard expiry.
      expect(
        h.mine!.expiresAt.difference(h.mine!.startedAt).inMinutes,
        config.snooze.drivingSafetyCapMinutes,
      );

      h.wait(20);
      expect(h.state.phase, isNot(SessionPhase.inCall));

      h.vehicle.simulate(VehicleTransition.exit);
      h.flush();
      expect(h.mine, isNull);
      expect(h.driverMode, isFalse);
    });
  });

  test(
    'feedback is never asked while driving — it waits until the drive ends',
    () {
      run((h) {
        h.world.forcedAnswer = ForcedAnswer.accept;
        h.vehicle.simulate(VehicleTransition.enter);
        h.flush();
        h.ctrl.startAvailability(AvailabilityMode.driving, untilTripEnds: true);
        h.wait(2);
        h.ctrl.talkNow();
        h.wait(2);
        expect(h.state.phase, SessionPhase.inCall);
        h.ctrl.endCall();
        h.flush();
        expect(h.state.phase, SessionPhase.idle);
        expect(h.state.pendingFeedbackPeer, isNotNull);

        h.vehicle.simulate(VehicleTransition.exit);
        h.flush();
        expect(h.mine, isNull);
        expect(h.state.phase, SessionPhase.feedback);
      });
    },
  );

  test('availability ending during a call does not cut the call', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.accept;
      h.beFree();
      h.ctrl.talkNow();
      h.wait(2);
      expect(h.state.phase, SessionPhase.inCall);
      h.world.expireMyAvailabilitySoon();
      h.world.advanceClock(const Duration(seconds: 5));
      h.wait(3);
      expect(h.state.phase, SessionPhase.inCall);
      h.ctrl.endCall();
      h.flush();
      expect(h.mine, isNull);
      expect(h.state.phase, SessionPhase.feedback);
    });
  });

  test('dropped in-app call → retry or end', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.accept;
      h.world.makeEveryoneUnavailable();
      h.world.setAvailable('tamar', 30);
      h.world.me = h.world.me.copyWith(
        openToFriendsOfFriends: true,
        openTiers: MatchTier.values.toSet(),
      );
      h.beFree();
      final tamar = h.state.options.firstWhere((s) => s.person.id == 'tamar');
      h.ctrl.talkNow(tamar);
      h.wait(2);
      expect(h.state.callMethod, CallMethod.inApp);
      h.ctrl.simulateCallDropped();
      expect(h.state.callDropped, isTrue);
      h.ctrl.retryDroppedCall();
      h.flush();
      expect(h.state.callDropped, isFalse);
      h.ctrl.simulateIncomingPhoneCall();
      expect(h.state.callOnHold, isTrue);
      h.ctrl.resumeFromHold();
      expect(h.state.callOnHold, isFalse);
    });
  });

  test('no internet: search waits and resumes when back online', () {
    run((h) {
      h.world.offline = true;
      h.ctrl.startAvailability(AvailabilityMode.free, minutes: 30);
      h.wait(10);
      expect(h.state.phase, SessionPhase.searching);
      expect(h.state.options, isEmpty);
      h.world.offline = false;
      h.world.notify();
      h.wait(4);
      expect(h.state.phase, SessionPhase.options);
    });
  });

  test('no one free → invitations go to a few people only (beacon)', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.decline;
      h.world.makeEveryoneUnavailable();
      h.beFree();
      expect(h.state.phase, SessionPhase.searching);
      h.wait(config.beacon.waitSecondsBeforeBeacon + 1);
      expect(h.state.beaconSent, isTrue);
      expect(
        h.state.beaconRecipients,
        inInclusiveRange(1, config.beacon.maxRecipientsPerWindow),
      );
      final total = h.world.invitationsSentTo.values.fold(
        0,
        (a, l) => a + l.length,
      );
      expect(total, h.state.beaconRecipients);
    });
  });

  test('a beacon "yes" becomes an option that is already accepted', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.accept;
      h.world.makeEveryoneUnavailable();
      h.beFree();
      h.wait(config.beacon.waitSecondsBeforeBeacon + 3);
      expect(h.state.phase, SessionPhase.options);
      expect(h.state.suggestion!.alreadyAccepted, isTrue);
      h.ctrl.talkNow();
      h.flush();
      expect(h.state.phase, SessionPhase.inCall);
    });
  });

  test(
    'availability expires automatically (also after the app was closed)',
    () {
      run((h) {
        h.ctrl.startAvailability(AvailabilityMode.breakTime, minutes: 15);
        h.wait(2);
        h.world.advanceClock(const Duration(minutes: 16));
        h.wait(2);
        expect(h.mine, isNull);
        expect(h.state.phase, SessionPhase.idle);
        expect(h.state.notice?.kind, NoticeKind.availabilityEnded);
      });
    },
  );

  test('incoming invitation while waiting can replace the wait', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.noAnswer;
      h.beFree();
      h.ctrl.talkNow();
      h.flush();
      expect(h.invitations.simulateIncoming('michal', 30), isTrue);
      h.flush();
      expect(h.state.invitation?.fromPersonId, 'michal');
      h.ctrl.respondToInvitation(InvitationResponse.talkNow);
      h.flush();
      expect(h.state.phase, SessionPhase.inCall);
      expect(h.state.peer!.id, 'michal');
    });
  });

  test('incoming invitation: mute stops further invitations for a while', () {
    run((h) {
      expect(h.invitations.simulateIncoming('dana', 30), isTrue);
      h.flush();
      expect(h.state.invitation?.fromPersonId, 'dana');
      h.ctrl.respondToInvitation(InvitationResponse.mute);
      h.flush();
      expect(h.state.invitation, isNull);
      expect(h.world.prefs.beaconMutedUntil, isNotNull);
      expect(h.invitations.simulateIncoming('yoni', 30), isFalse);
    });
  });

  test('voice message after "no answer" (simulated)', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.decline;
      h.beFree();
      final p = h.state.options.first.person;
      h.ctrl.talkNow();
      h.wait(2);
      h.ctrl.startVoiceMessage(p);
      expect(h.state.phase, SessionPhase.voiceMessage);
      h.ctrl.sendVoiceMessage(const Duration(seconds: 12));
      h.flush();
      expect(h.state.notice?.kind, NoticeKind.voiceMessageSent);
      expect(h.state.phase, SessionPhase.options);
      final sent = (h.container.read(
        voiceMessageServiceProvider,
      ) as FakeVoiceMessageService).sent;
      expect(sent.single.$1, p.id);
    });
  });

  test('block from an option removes the person', () {
    run((h) {
      h.beFree();
      final p = h.state.options[1].person;
      h.ctrl.blockPerson(p);
      h.flush();
      expect(h.world.blockedByMe, contains(p.id));
      expect(h.state.options.map((s) => s.person.id), isNot(contains(p.id)));
    });
  });

  test('"not today" pauses a person until tomorrow', () {
    run((h) {
      h.beFree();
      final s = h.state.options.first;
      h.ctrl.notToday(s);
      h.flush();
      final pause = h.world.pauses[s.person.id]!;
      expect(pause.kind, PauseKind.notToday);
      expect(pause.until.isAfter(h.world.now()), isTrue);
      expect(pause.until.difference(h.world.now()).inHours, lessThan(25));
    });
  });
}
