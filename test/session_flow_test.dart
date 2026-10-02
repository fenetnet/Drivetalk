import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drivetalk/app/providers.dart';
import 'package:drivetalk/app/session_controller.dart';
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/matching/matching_config.dart';
import 'package:drivetalk/platform/vehicle_signal_source.dart';
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
      ],
    );
    container.listen(sessionProvider, (_, _) {});
    container.listen(driverModeProvider, (_, _) {});
  }

  final FakeAsync async;
  late final FakeWorld world;
  late final ProviderContainer container;

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

  void dispose() => container.dispose();
}

void run(void Function(Harness h) body) => fakeAsync((async) {
  final h = Harness(async);
  body(h);
  h.dispose();
});

void main() {
  test('free → suggestion → both agree → call → feedback', () {
    run((h) {
      h.ctrl.startAvailability(AvailabilityMode.walking, minutes: 30);
      h.flush();
      expect(h.state.phase, SessionPhase.searching);
      h.wait(2);
      expect(h.state.phase, SessionPhase.suggestion);
      final person = h.state.suggestion!.person;
      expect(
        h.world.availability[person.id]!.isActiveAt(h.world.now()),
        isTrue,
      );
      expect(h.state.suggestion!.candidate.reasons, isNotEmpty);

      h.world.forcedAnswer = ForcedAnswer.accept;
      h.ctrl.talkNow();
      h.flush();
      // Never auto-connect: we wait for the other side.
      expect(h.state.phase, SessionPhase.waitingForAnswer);
      h.wait(2);
      expect(h.state.phase, SessionPhase.inCall);
      expect(h.state.peer!.id, person.id);

      final callsBefore = h.world.connections[person.id]?.callCount ?? 0;
      h.ctrl.endCall();
      h.flush();
      expect(h.state.phase, SessionPhase.feedback);
      expect(h.world.connections[person.id]!.callCount, callsBefore + 1);

      h.ctrl.submitFeedback(FeedbackRating.veryGood, wantAgain: true);
      h.flush();
      expect(h.state.phase, SessionPhase.idle);
      expect(
        h.world.connections[person.id]!.feedback.last.rating,
        FeedbackRating.veryGood,
      );
      // Still available after the call ("resting").
      expect(h.mine, isNotNull);
    });
  });

  test('if the other side declines, we move on to someone else', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.decline;
      h.ctrl.startAvailability(AvailabilityMode.free, minutes: 30);
      h.wait(2);
      final first = h.state.suggestion!.person.id;
      h.ctrl.talkNow();
      h.wait(2);
      expect(h.state.notice?.kind, NoticeKind.declinedByOther);
      expect(h.state.skippedIds, contains(first));
      h.wait(2);
      expect(h.state.phase, SessionPhase.suggestion);
      expect(h.state.suggestion!.person.id, isNot(first));
    });
  });

  test(
    'automatic driving availability: opt-in, availability only, never a call',
    () {
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
        expect(h.driverMode, isTrue);

        h.wait(20);
        expect(h.state.phase, isNot(SessionPhase.inCall));

        h.vehicle.simulate(VehicleTransition.exit);
        h.flush();
        expect(h.mine, isNull);
        expect(h.driverMode, isFalse);
      });
    },
  );

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

  test('no one free → invitations go to a few people only (beacon)', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.decline;
      h.world.makeEveryoneUnavailable();
      h.ctrl.startAvailability(AvailabilityMode.free, minutes: 30);
      h.wait(2);
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

  test('a beacon "yes" becomes a suggestion that is already accepted', () {
    run((h) {
      h.world.forcedAnswer = ForcedAnswer.accept;
      h.world.makeEveryoneUnavailable();
      h.ctrl.startAvailability(AvailabilityMode.free, minutes: 30);
      h.wait(2 + config.beacon.waitSecondsBeforeBeacon + 3);
      expect(h.state.phase, SessionPhase.suggestion);
      expect(h.state.suggestion!.alreadyAccepted, isTrue);
      h.ctrl.talkNow();
      h.flush();
      expect(h.state.phase, SessionPhase.inCall);
    });
  });

  test('availability expires automatically', () {
    run((h) {
      h.ctrl.startAvailability(AvailabilityMode.breakTime, minutes: 15);
      h.wait(2);
      h.world.advanceClock(const Duration(minutes: 16));
      h.wait(2);
      expect(h.mine, isNull);
      expect(h.state.phase, SessionPhase.idle);
      expect(h.state.notice?.kind, NoticeKind.availabilityEnded);
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

  test('block from a suggestion removes the person and searches again', () {
    run((h) {
      h.ctrl.startAvailability(AvailabilityMode.free, minutes: 30);
      h.wait(2);
      final p = h.state.suggestion!.person;
      h.ctrl.blockPerson(p);
      h.flush();
      expect(h.world.blockedByMe, contains(p.id));
      h.wait(2);
      expect(h.state.suggestion?.person.id, isNot(p.id));
    });
  });

  test('"not today" pauses a person until tomorrow', () {
    run((h) {
      h.ctrl.startAvailability(AvailabilityMode.free, minutes: 30);
      h.wait(2);
      final p = h.state.suggestion!.person;
      h.ctrl.notToday();
      h.flush();
      final pause = h.world.pauses[p.id]!;
      expect(pause.kind, PauseKind.notToday);
      expect(pause.until.isAfter(h.world.now()), isTrue);
      expect(pause.until.difference(h.world.now()).inHours, lessThan(25));
    });
  });
}
