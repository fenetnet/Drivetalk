import 'dart:async';

import '../../domain/models.dart';
import '../../platform/vehicle_signal_source.dart';
import '../analytics_service.dart';
import '../availability_service.dart';
import '../call_service.dart';
import '../clock_service.dart';
import '../invitation_service.dart';
import '../match_service.dart';
import '../profile_service.dart';
import '../safety_service.dart';
import '../social_graph_service.dart';
import 'fake_seed.dart';
import 'fake_world.dart';

// Phase 1 implementations of the service interfaces, all backed by one
// in-memory FakeWorld. Replacing these with Supabase/LiveKit versions must not
// require changes in the UI.

class FakeClockService implements ClockService {
  FakeClockService(this.world);
  final FakeWorld world;
  @override
  DateTime now() => world.now();
}

class FakeProfileService implements ProfileService {
  FakeProfileService(this.world);
  final FakeWorld world;

  @override
  Stream<void> get changes => world.changes;
  @override
  Person get me => world.me;
  @override
  MyPreferences get prefs => world.prefs;

  @override
  Future<void> updateMe(Person me) async {
    world.me = me;
    world.notify();
  }

  @override
  Future<void> updatePrefs(MyPreferences prefs) async {
    world.prefs = prefs;
    world.notify();
  }
}

class FakeSocialGraphService implements SocialGraphService {
  FakeSocialGraphService(this.world);
  final FakeWorld world;

  @override
  Stream<void> get changes => world.changes;

  @override
  List<Person> get people => world.others.values.toList();

  @override
  Person? personById(String id) => id == meId ? world.me : world.others[id];

  @override
  List<Connection> get connections => world.connections.values.toList();

  @override
  Connection? connectionWith(String personId) => world.connections[personId];

  @override
  int mutualFriendsWith(String personId) {
    final p = world.others[personId];
    if (p == null) return 0;
    final mine = world.connections.keys.toSet();
    return mine.intersection(p.friendIds).length;
  }

  @override
  List<Group> sharedGroupsWith(String personId) {
    final p = world.others[personId];
    if (p == null) return const [];
    return [
      for (final g in world.me.groupIds.intersection(p.groupIds))
        if (fakeGroups[g] != null) fakeGroups[g]!,
    ];
  }

  @override
  Group? groupById(String id) => fakeGroups[id];

  @override
  Set<String> get blockedIds => {...world.blockedByMe};

  @override
  List<Person> get blockedByMe => [
    for (final id in world.blockedByMe)
      if (world.others[id] != null) world.others[id]!,
  ];

  void _update(String id, Connection Function(Connection c) f) {
    final c = world.connections[id];
    if (c == null) return;
    world.connections[id] = f(c);
    world.notify();
  }

  @override
  Future<void> setRelationship(String personId, RelationshipType? type) async =>
      _update(
        personId,
        (c) => type == null
            ? c.copyWith(clearRelationshipType: true)
            : c.copyWith(relationshipType: type),
      );

  @override
  Future<void> addConnection(String personId) async {
    if (world.connections.containsKey(personId)) return;
    world.connections[personId] = Connection(personId: personId);
    world.notify();
  }

  @override
  Future<void> unmatch(String personId) async {
    world.connections.remove(personId);
    world.notify();
  }

  @override
  Future<void> block(String personId) async {
    world.blockedByMe.add(personId);
    world.notify();
  }

  @override
  Future<void> unblock(String personId) async {
    world.blockedByMe.remove(personId);
    world.notify();
  }

  @override
  SuggestionPause? pauseFor(String personId) => world.pauses[personId];

  @override
  Future<void> pauseSuggestions(
    String personId,
    PauseKind kind,
    DateTime until,
  ) async {
    world.pauses[personId] = SuggestionPause(kind: kind, until: until);
    if (world.connections.containsKey(personId)) {
      _update(personId, (c) => c.copyWith(lastDeclinedAt: world.now()));
    } else {
      world.notify();
    }
  }

  @override
  Future<void> allowSuggestions(String personId) async {
    world.pauses.remove(personId);
    world.notify();
  }

  @override
  Future<void> recordCall(String personId, DateTime at) async {
    world.connections.putIfAbsent(
      personId,
      () => Connection(personId: personId),
    );
    _update(
      personId,
      (c) => c.copyWith(lastInteraction: at, callCount: c.callCount + 1),
    );
  }

  @override
  Future<void> addFeedback(String personId, FeedbackEntry entry) async =>
      _update(personId, (c) => c.copyWith(feedback: [...c.feedback, entry]));

  @override
  List<Person> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return world.others.values
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) &&
              !world.blockedByMe.contains(p.id),
        )
        .toList();
  }
}

class FakeAvailabilityService implements AvailabilityService {
  FakeAvailabilityService(this.world);
  final FakeWorld world;

  @override
  Stream<void> get changes => world.changes;

  @override
  Availability? get mine => world.myAvailability;

  @override
  Future<void> start(Availability availability) async {
    world.myAvailability = availability;
    world.notify();
  }

  @override
  Future<void> stop() async {
    world.myAvailability = null;
    world.notify();
  }

  @override
  Availability? availabilityOf(String personId) => world.availability[personId];
}

class FakeMatchService implements MatchService {
  FakeMatchService(this.world);
  final FakeWorld world;

  @override
  Stream<void> get changes => world.changes;

  @override
  DateTime? lastSuggestedAt(String personId) => world.lastSuggested[personId];

  @override
  Future<void> markSuggested(String personId, DateTime at) async {
    world.lastSuggested[personId] = at;
  }

  @override
  Future<CallRequestOutcome> requestCall(String personId) =>
      world.answerFor(personId);
}

class FakeInvitationService implements InvitationService {
  FakeInvitationService(this.world);
  final FakeWorld world;
  final _incoming = StreamController<Invitation>.broadcast();
  final _answers = StreamController<InvitationAnswer>.broadcast();
  var _nextId = 0;

  @override
  Stream<Invitation> get incoming => _incoming.stream;

  @override
  Stream<InvitationAnswer> get answers => _answers.stream;

  @override
  int sentTodayTo(String personId, DateTime now) =>
      (world.invitationsSentTo[personId] ?? const [])
          .where((t) => now.difference(t).inHours < 24)
          .length;

  @override
  Future<List<String>> sendBeacon(
    List<String> personIds,
    Availability mine,
  ) async {
    final now = world.now();
    for (final id in personIds) {
      world.invitationsSentTo.putIfAbsent(id, () => []).add(now);
      // Fake: each recipient may answer "yes" after a little while.
      unawaited(
        world.answerFor(id).then((outcome) {
          if (outcome != CallRequestOutcome.accepted) return;
          if (!(world.myAvailability?.isActiveAt(world.now()) ?? false)) return;
          // Answering yes makes them available for the overlap of our windows.
          world.availability[id] = Availability(
            mode: AvailabilityMode.free,
            startedAt: world.now(),
            expiresAt: world.myAvailability!.expiresAt,
          );
          world.notify();
          _answers.add(InvitationAnswer(personId: id, accepted: true));
        }),
      );
    }
    return personIds;
  }

  @override
  Future<void> respond(
    Invitation invitation,
    InvitationResponse response,
  ) async {}

  /// Debug: pretend [fromPersonId] sent me an invitation.
  /// Returns false if my settings muted it (so it is not delivered).
  bool simulateIncoming(String fromPersonId, int minutes) {
    final now = world.now();
    final prefs = world.prefs;
    if (prefs.beaconFrequency == BeaconFrequency.off) return false;
    if (prefs.beaconMutedUntil?.isAfter(now) ?? false) return false;
    world.availability[fromPersonId] = Availability(
      mode: AvailabilityMode.driving,
      startedAt: now,
      expiresAt: now.add(Duration(minutes: minutes)),
    );
    world.notify();
    _incoming.add(
      Invitation(
        id: 'inv${_nextId++}',
        fromPersonId: fromPersonId,
        minutes: minutes,
        mode: AvailabilityMode.driving,
        sentAt: now,
      ),
    );
    return true;
  }
}

class FakeCallService implements CallService {
  @override
  Future<void> startCall(String personId) async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> endCall() async {}
}

class FakeSafetyService implements SafetyService {
  FakeSafetyService(this.world);
  final FakeWorld world;

  @override
  Future<void> report(String personId, ReportReason reason) async {
    world.reports.add((personId, reason, world.now()));
  }
}

class LocalAnalyticsService implements AnalyticsService {
  LocalAnalyticsService(this.clock);
  final ClockService clock;
  final _events = <AnalyticsEvent>[];

  @override
  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  @override
  void log(String name, [Map<String, Object> props = const {}]) {
    _events.add(AnalyticsEvent(name, clock.now(), props));
  }
}

class FakeVehicleSignalSource implements VehicleSignalSource {
  final _events = StreamController<VehicleEvent>.broadcast();
  bool _inVehicle = false;

  @override
  Stream<VehicleEvent> get events => _events.stream;

  @override
  bool get probablyInVehicle => _inVehicle;

  void simulate(
    VehicleTransition t, {
    VehicleConfidence confidence = VehicleConfidence.normal,
  }) {
    _inVehicle = t == VehicleTransition.enter;
    _events.add(VehicleEvent(t, confidence: confidence));
  }
}
