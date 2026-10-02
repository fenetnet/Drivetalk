import 'dart:async';
import 'dart:math';

import '../../domain/models.dart';
import '../match_service.dart';
import 'fake_seed.dart';

/// Debug: how the other side answers a call request.
/// [noAnswer] = they never answer (the app gives up after the timeout).
enum ForcedAnswer { auto, accept, decline, noAnswer }

/// In-memory "backend" shared by all Phase 1 fake services.
/// Also exposes the knobs used by the developer/debug screen.
class FakeWorld {
  FakeWorld({Random? random, this.onProfileChanged})
    : random = random ?? Random() {
    reset();
  }

  /// Called when my profile or preferences change, so they can be kept on
  /// this phone between launches (everything else is regenerated fake data).
  final void Function(Person me, MyPreferences prefs)? onProfileChanged;

  final Random random;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  // ----- clock -----
  Duration clockOffset = Duration.zero;
  DateTime now() => DateTime.now().add(clockOffset);

  // ----- state -----
  late Person me;
  late MyPreferences prefs;
  final others = <String, Person>{};
  final connections = <String, Connection>{};
  final blockedByMe = <String>{};

  /// People who blocked me. Never revealed — it just looks like "can't now".
  final blockedMe = <String>{};
  final availability = <String, Availability>{};
  Availability? myAvailability;
  final lastSuggested = <String, DateTime>{};
  final pauses = <String, SuggestionPause>{};
  final invitationsSentTo = <String, List<DateTime>>{};
  final acceptProbability = <String, double>{};
  final reports = <(String, ReportReason, DateTime)>[];

  // ----- debug knobs -----
  ForcedAnswer forcedAnswer = ForcedAnswer.auto;

  /// Fake delay before the other side answers, in seconds.
  int answerDelaySeconds = 3;

  /// Debug: simulate "no internet".
  bool offline = false;

  /// Debug: simulate a weak signal during a call.
  bool weakSignal = false;

  void notify() => _changes.add(null);

  void reset() {
    final t = DateTime.now().add(clockOffset);
    me = seedMe();
    prefs = const MyPreferences(circles: seedCircles);
    others.clear();
    connections.clear();
    blockedByMe.clear();
    blockedMe.clear();
    offline = false;
    weakSignal = false;
    availability.clear();
    myAvailability = null;
    lastSuggested.clear();
    pauses.clear();
    invitationsSentTo.clear();
    acceptProbability.clear();
    reports.clear();
    for (final s in fakeSeeds) {
      others[s.person.id] = s.person;
      acceptProbability[s.person.id] = s.acceptProbability;
      if (s.isConnection) {
        final last = s.daysSinceInteraction == null
            ? null
            : t.subtract(Duration(days: s.daysSinceInteraction!));
        connections[s.person.id] = Connection(
          personId: s.person.id,
          relationshipType: s.relationship,
          contextLabel: s.contextLabel,
          lastInteraction: last,
          callCount: s.callCount,
          quickConnect: s.myQuickConnect,
          feedback: [
            for (final r in s.feedback)
              FeedbackEntry(at: last ?? t, rating: r, wantAgain: true),
          ],
        );
      }
      if (s.availableMinutes != null) {
        availability[s.person.id] = Availability(
          mode: s.mode,
          startedAt: t,
          expiresAt: t.add(Duration(minutes: s.availableMinutes!)),
        );
      }
    }
    notify();
  }

  // ----- debug helpers -----

  void advanceClock(Duration d) {
    clockOffset += d;
    notify();
  }

  void setAvailable(
    String id,
    int? minutes, {
    AvailabilityMode mode = AvailabilityMode.free,
  }) {
    if (minutes == null) {
      availability.remove(id);
    } else {
      final t = now();
      availability[id] = Availability(
        mode: mode,
        startedAt: t,
        expiresAt: t.add(Duration(minutes: minutes)),
      );
    }
    notify();
  }

  /// Scenario: my availability ends in a couple of seconds.
  void expireMyAvailabilitySoon() {
    final a = myAvailability;
    if (a == null) return;
    myAvailability = Availability(
      mode: a.mode,
      startedAt: a.startedAt,
      expiresAt: now().add(const Duration(seconds: 2)),
      untilTripEnds: a.untilTripEnds,
      source: a.source,
      circleId: a.circleId,
    );
    notify();
  }

  void makeEveryoneUnavailable() {
    availability.clear();
    notify();
  }

  void profileChanged() => onProfileChanged?.call(me, prefs);

  /// Decide (fake) whether [id] says yes to talking now.
  /// [noAnswer] never completes on its own — the caller's timeout decides.
  Future<CallRequestOutcome> answerFor(String id) async {
    if (forcedAnswer == ForcedAnswer.noAnswer) {
      return Completer<CallRequestOutcome>().future;
    }
    await Future<void>.delayed(Duration(seconds: answerDelaySeconds));
    if (blockedMe.contains(id)) return CallRequestOutcome.declined;
    switch (forcedAnswer) {
      case ForcedAnswer.noAnswer:
        return CallRequestOutcome.timedOut;
      case ForcedAnswer.accept:
        return CallRequestOutcome.accepted;
      case ForcedAnswer.decline:
        return CallRequestOutcome.declined;
      case ForcedAnswer.auto:
        final p = acceptProbability[id] ?? 0.6;
        return random.nextDouble() < p
            ? CallRequestOutcome.accepted
            : CallRequestOutcome.declined;
    }
  }
}
