import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../matching/match_reason.dart';
import '../matching/matching_engine.dart';
import '../platform/vehicle_signal_source.dart';
import '../services/invitation_service.dart';
import '../services/match_service.dart';
import 'providers.dart';

enum SessionPhase {
  /// Not searching. May still be available ("resting" after a call).
  idle,
  searching,
  suggestion,
  waitingForAnswer,
  inCall,
  feedback,
}

enum NoticeKind {
  declinedByOther,
  availabilityEnded,
  invitationMuted,
  blocked,
  reported,
  pausedNotToday,
  pausedForAWhile,
}

class SessionNotice {
  const SessionNotice(this.kind, this.id, {this.person});
  final NoticeKind kind;
  final int id;
  final Person? person;
}

const _keep = Object();

class SessionState {
  const SessionState({
    this.phase = SessionPhase.idle,
    this.suggestion,
    this.peer,
    this.callStartedAt,
    this.muted = false,
    this.skippedIds = const {},
    this.beaconSent = false,
    this.beaconRecipients = 0,
    this.pendingFeedbackPeer,
    this.invitation,
    this.notice,
    this.windowStartedAt,
    this.hadCallThisWindow = false,
    this.inVehicle = false,
    this.stopAfterCall = false,
  });

  final SessionPhase phase;
  final Suggestion? suggestion;

  /// The person in the current call, or the one we ask feedback about.
  final Person? peer;
  final DateTime? callStartedAt;
  final bool muted;
  final Set<String> skippedIds;
  final bool beaconSent;
  final int beaconRecipients;

  /// Feedback is never asked while driving; it waits here.
  final Person? pendingFeedbackPeer;
  final Invitation? invitation;
  final SessionNotice? notice;
  final DateTime? windowStartedAt;
  final bool hadCallThisWindow;

  /// The device is probably in a vehicle (never "the user is driving").
  final bool inVehicle;
  final bool stopAfterCall;

  SessionState copyWith({
    SessionPhase? phase,
    Object? suggestion = _keep,
    Object? peer = _keep,
    Object? callStartedAt = _keep,
    bool? muted,
    Set<String>? skippedIds,
    bool? beaconSent,
    int? beaconRecipients,
    Object? pendingFeedbackPeer = _keep,
    Object? invitation = _keep,
    Object? notice = _keep,
    Object? windowStartedAt = _keep,
    bool? hadCallThisWindow,
    bool? inVehicle,
    bool? stopAfterCall,
  }) => SessionState(
    phase: phase ?? this.phase,
    suggestion: identical(suggestion, _keep)
        ? this.suggestion
        : suggestion as Suggestion?,
    peer: identical(peer, _keep) ? this.peer : peer as Person?,
    callStartedAt: identical(callStartedAt, _keep)
        ? this.callStartedAt
        : callStartedAt as DateTime?,
    muted: muted ?? this.muted,
    skippedIds: skippedIds ?? this.skippedIds,
    beaconSent: beaconSent ?? this.beaconSent,
    beaconRecipients: beaconRecipients ?? this.beaconRecipients,
    pendingFeedbackPeer: identical(pendingFeedbackPeer, _keep)
        ? this.pendingFeedbackPeer
        : pendingFeedbackPeer as Person?,
    invitation: identical(invitation, _keep)
        ? this.invitation
        : invitation as Invitation?,
    notice: identical(notice, _keep) ? this.notice : notice as SessionNotice?,
    windowStartedAt: identical(windowStartedAt, _keep)
        ? this.windowStartedAt
        : windowStartedAt as DateTime?,
    hadCallThisWindow: hadCallThisWindow ?? this.hadCallThisWindow,
    inVehicle: inVehicle ?? this.inVehicle,
    stopAfterCall: stopAfterCall ?? this.stopAfterCall,
  );
}

/// Developer-screen switch: pretend nobody matches right now.
final debugForceNoMatchProvider = NotifierProvider<DebugFlag, bool>(
  DebugFlag.new,
);

class DebugFlag extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// True when the UI must switch to the minimal driver mode.
final driverModeProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionProvider);
  ref.watch(dataVersionProvider);
  final now = ref.watch(nowProvider);
  final mine = ref.watch(availabilityServiceProvider).mine;
  return isDriverMode(inVehicle: session.inVehicle, mine: mine, now: now);
});

/// Driver mode = the device is probably in a vehicle, or the user chose
/// "driving" availability.
bool isDriverMode({
  required bool inVehicle,
  required Availability? mine,
  required DateTime now,
}) =>
    inVehicle ||
    (mine != null &&
        mine.isActiveAt(now) &&
        mine.mode == AvailabilityMode.driving);

/// Orchestrates one availability window: search → suggest → mutual consent →
/// call → feedback. Never starts a call without both sides saying yes.
class SessionController extends Notifier<SessionState> {
  Timer? _tick;
  Timer? _searchTimer;
  Timer? _beaconTimer;
  var _noticeSeq = 0;

  @override
  SessionState build() {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _checkExpiry());
    final subs = <StreamSubscription<Object?>>[
      ref.read(invitationServiceProvider).incoming.listen(_onInvitation),
      ref.read(invitationServiceProvider).answers.listen(_onInvitationAnswer),
      ref.read(vehicleSignalProvider).events.listen(_onVehicleEvent),
    ];
    ref.listen(dataVersionProvider, (_, _) {
      if (state.phase == SessionPhase.searching &&
          !(_searchTimer?.isActive ?? false)) {
        _scheduleSearch(const Duration(milliseconds: 400));
      }
    });
    ref.onDispose(() {
      _tick?.cancel();
      _searchTimer?.cancel();
      _beaconTimer?.cancel();
      for (final s in subs) {
        s.cancel();
      }
    });
    return const SessionState();
  }

  DateTime get _now => ref.read(clockProvider).now();
  void _log(String name, [Map<String, Object> props = const {}]) =>
      ref.read(analyticsServiceProvider).log(name, props);

  SessionNotice _notice(NoticeKind kind, {Person? person}) =>
      SessionNotice(kind, ++_noticeSeq, person: person);

  bool get _isDriverMode => isDriverMode(
    inVehicle: state.inVehicle,
    mine: ref.read(availabilityServiceProvider).mine,
    now: _now,
  );

  // ------------------------------------------------------------ availability

  Future<void> startAvailability(
    AvailabilityMode mode, {
    int? minutes,
    bool untilTripEnds = false,
    AvailabilitySource source = AvailabilitySource.manual,
  }) async {
    final config = ref.read(matchingConfigProvider);
    final now = _now;
    final duration = untilTripEnds
        ? Duration(minutes: config.snooze.drivingSafetyCapMinutes)
        : Duration(minutes: minutes ?? 30);
    await ref
        .read(availabilityServiceProvider)
        .start(
          Availability(
            mode: mode,
            startedAt: now,
            expiresAt: now.add(duration),
            untilTripEnds: untilTripEnds,
            source: source,
          ),
        );
    _log('availability_opened', {
      'mode': mode.name,
      'minutes': untilTripEnds ? 'trip' : duration.inMinutes,
      'source': source.name,
    });
    state = state.copyWith(
      phase: SessionPhase.searching,
      suggestion: null,
      skippedIds: {},
      beaconSent: false,
      beaconRecipients: 0,
      windowStartedAt: now,
      hadCallThisWindow: false,
      stopAfterCall: false,
    );
    _scheduleSearch(const Duration(milliseconds: 1500));
  }

  Future<void> stopAvailability() async {
    if (state.phase == SessionPhase.inCall) return;
    await _endWindow();
  }

  Future<void> _endWindow({bool expired = false}) async {
    _searchTimer?.cancel();
    _beaconTimer?.cancel();
    if (state.windowStartedAt != null && !state.hadCallThisWindow) {
      _log('window_ended_without_call');
    }
    await ref.read(availabilityServiceProvider).stop();
    state = state.copyWith(
      phase: SessionPhase.idle,
      suggestion: null,
      windowStartedAt: null,
      stopAfterCall: false,
      notice: expired ? _notice(NoticeKind.availabilityEnded) : state.notice,
    );
    _maybeShowPendingFeedback();
  }

  void _checkExpiry() {
    final mine = ref.read(availabilityServiceProvider).mine;
    if (mine == null || mine.isActiveAt(_now)) return;
    if (state.phase == SessionPhase.inCall) return; // let the call finish
    _endWindow(expired: true);
  }

  // ---------------------------------------------------------------- search

  void _scheduleSearch(Duration delay) {
    _searchTimer?.cancel();
    _searchTimer = Timer(delay, _search);
  }

  void _search() {
    if (state.phase != SessionPhase.searching) return;
    final mine = ref.read(availabilityServiceProvider).mine;
    if (mine == null || !mine.isActiveAt(_now)) return;
    final facade = ref.read(matchingFacadeProvider);
    final result = facade.rank(excludeIds: state.skippedIds);
    final suggestion = ref.read(debugForceNoMatchProvider)
        ? null
        : ref.read(matchingEngineProvider).pick(result);
    if (suggestion != null) {
      _showSuggestion(suggestion);
      return;
    }
    if (!state.beaconSent && !(_beaconTimer?.isActive ?? false)) {
      final wait = ref
          .read(matchingConfigProvider)
          .beacon
          .waitSecondsBeforeBeacon;
      _beaconTimer = Timer(Duration(seconds: wait), _sendBeacon);
    }
  }

  void _showSuggestion(Suggestion s) {
    _beaconTimer?.cancel();
    ref.read(matchServiceProvider).markSuggested(s.person.id, _now);
    _log('suggestion_shown', {
      'tier': s.candidate.tier.name,
      'exploration': s.isExploration,
      'answeredInvitation': s.alreadyAccepted,
    });
    state = state.copyWith(phase: SessionPhase.suggestion, suggestion: s);
  }

  /// Simulate pressing "search" again after resting.
  void searchAgain() {
    final mine = ref.read(availabilityServiceProvider).mine;
    if (mine == null || !mine.isActiveAt(_now)) return;
    state = state.copyWith(phase: SessionPhase.searching, suggestion: null);
    _scheduleSearch(const Duration(milliseconds: 1200));
  }

  /// Availability Beacon: when nobody is free right now, invite a few
  /// relevant people — never everyone — within rate limits.
  Future<void> _sendBeacon() async {
    if (state.phase != SessionPhase.searching || state.beaconSent) return;
    final mine = ref.read(availabilityServiceProvider).mine;
    if (mine == null || !mine.isActiveAt(_now)) return;
    final config = ref.read(matchingConfigProvider).beacon;
    final invitations = ref.read(invitationServiceProvider);
    final now = _now;
    final ranked = ref
        .read(matchingFacadeProvider)
        .rank(requireAvailable: false, excludeIds: state.skippedIds)
        .ranked;
    final recipients = <String>[];
    for (final c in ranked) {
      if (recipients.length >= config.maxRecipientsPerWindow) break;
      if (c.input.availability?.isActiveAt(now) ?? false) continue;
      if (invitations.sentTodayTo(c.input.person.id, now) >=
          config.maxPerRecipientPerDayNormal) {
        continue;
      }
      recipients.add(c.input.person.id);
    }
    final sent = recipients.isEmpty
        ? const <String>[]
        : await invitations.sendBeacon(recipients, mine);
    _log('beacon_sent', {'recipients': sent.length});
    state = state.copyWith(beaconSent: true, beaconRecipients: sent.length);
  }

  void _onInvitationAnswer(InvitationAnswer answer) {
    if (!answer.accepted || state.phase != SessionPhase.searching) return;
    final ranked = ref.read(matchingFacadeProvider).rank().ranked;
    final match = ranked.where((c) => c.input.person.id == answer.personId);
    if (match.isEmpty) return;
    final c = match.first;
    _showSuggestion(
      Suggestion(
        alreadyAccepted: true,
        candidate: ScoredCandidate(
          input: c.input,
          tier: c.tier,
          score: c.score,
          contributions: c.contributions,
          reasons: [
            const AnsweredYourInvitationReason(),
            ...c.reasons.take(ref.read(matchingConfigProvider).maxReasons - 1),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------- suggestion actions

  Future<void> talkNow() async {
    final s = state.suggestion;
    if (s == null) return;
    _log('suggestion_accepted', {'tier': s.candidate.tier.name});
    if (s.alreadyAccepted) {
      await _startCall(s.person);
      return;
    }
    state = state.copyWith(phase: SessionPhase.waitingForAnswer);
    final outcome = await ref
        .read(matchServiceProvider)
        .requestCall(s.person.id);
    if (!ref.mounted) return;
    if (state.phase != SessionPhase.waitingForAnswer ||
        state.suggestion?.person.id != s.person.id) {
      return; // cancelled meanwhile
    }
    if (outcome == CallRequestOutcome.accepted) {
      await _startCall(s.person);
    } else {
      _log('call_request_declined');
      _skipAndSearch(
        s.person.id,
        notice: _notice(NoticeKind.declinedByOther, person: s.person),
      );
    }
  }

  void cancelWaiting() {
    final s = state.suggestion;
    if (s == null) return;
    _skipAndSearch(s.person.id);
  }

  void next() {
    final s = state.suggestion;
    if (s == null) return;
    _log('suggestion_skipped');
    _skipAndSearch(s.person.id);
  }

  Future<void> notToday() => _pause(PauseKind.notToday);
  Future<void> doNotSuggestForAWhile() => _pause(PauseKind.doNotSuggest);

  Future<void> _pause(PauseKind kind) async {
    final s = state.suggestion;
    if (s == null) return;
    final now = _now;
    final until = kind == PauseKind.notToday
        ? DateTime(now.year, now.month, now.day + 1)
        : now.add(
            Duration(
              days: ref.read(matchingConfigProvider).snooze.doNotSuggestDays,
            ),
          );
    await ref
        .read(socialGraphServiceProvider)
        .pauseSuggestions(s.person.id, kind, until);
    _log('suggestion_paused', {'kind': kind.name});
    _skipAndSearch(
      s.person.id,
      notice: _notice(
        kind == PauseKind.notToday
            ? NoticeKind.pausedNotToday
            : NoticeKind.pausedForAWhile,
        person: s.person,
      ),
    );
  }

  Future<void> blockPerson(Person person) async {
    await ref.read(socialGraphServiceProvider).block(person.id);
    _log('block');
    _afterSafetyAction(person, _notice(NoticeKind.blocked, person: person));
  }

  Future<void> reportPerson(
    Person person,
    ReportReason reason, {
    required bool alsoBlock,
  }) async {
    await ref.read(safetyServiceProvider).report(person.id, reason);
    _log('report', {'reason': reason.name});
    if (alsoBlock) await ref.read(socialGraphServiceProvider).block(person.id);
    _afterSafetyAction(person, _notice(NoticeKind.reported, person: person));
  }

  void _afterSafetyAction(Person person, SessionNotice notice) {
    if (state.suggestion?.person.id == person.id) {
      _skipAndSearch(person.id, notice: notice);
    } else {
      state = state.copyWith(notice: notice);
    }
  }

  void _skipAndSearch(String personId, {SessionNotice? notice}) {
    state = state.copyWith(
      phase: SessionPhase.searching,
      suggestion: null,
      skippedIds: {...state.skippedIds, personId},
      notice: notice ?? state.notice,
    );
    _scheduleSearch(const Duration(milliseconds: 1200));
  }

  // ------------------------------------------------------------------- call

  Future<void> _startCall(Person peer) async {
    _searchTimer?.cancel();
    _beaconTimer?.cancel();
    await ref.read(callServiceProvider).startCall(peer.id);
    final started = state.windowStartedAt;
    _log('call_started', {
      if (started != null) 'secondsToMatch': _now.difference(started).inSeconds,
    });
    state = state.copyWith(
      phase: SessionPhase.inCall,
      peer: peer,
      callStartedAt: _now,
      muted: false,
      invitation: null,
      hadCallThisWindow: true,
    );
  }

  Future<void> toggleMute() async {
    final muted = !state.muted;
    await ref.read(callServiceProvider).setMuted(muted);
    state = state.copyWith(muted: muted);
  }

  Future<void> endCall() async {
    final peer = state.peer;
    if (state.phase != SessionPhase.inCall || peer == null) return;
    await ref.read(callServiceProvider).endCall();
    final graph = ref.read(socialGraphServiceProvider);
    final config = ref.read(matchingConfigProvider);
    final now = _now;
    final before = graph.connectionWith(peer.id);
    final last = before?.lastInteraction;
    if (last != null &&
        now.difference(last).inDays >= config.dormantAfterDays) {
      _log('dormant_reconnected');
    }
    if (before == null && graph.mutualFriendsWith(peer.id) > 0) {
      _log('new_connection_via_friends_of_friends');
    }
    await graph.recordCall(peer.id, now);
    _log('call_ended', {
      'seconds': now.difference(state.callStartedAt ?? now).inSeconds,
    });

    final mine = ref.read(availabilityServiceProvider).mine;
    final windowOver =
        mine == null || !mine.isActiveAt(now) || state.stopAfterCall;
    state = state.copyWith(
      phase: SessionPhase.idle,
      callStartedAt: null,
      muted: false,
      suggestion: null,
      pendingFeedbackPeer: peer,
    );
    if (windowOver) {
      await _endWindow(expired: mine != null && !mine.isActiveAt(now));
    } else {
      _maybeShowPendingFeedback();
    }
  }

  // --------------------------------------------------------------- feedback

  /// Feedback is asked only when not in driver mode.
  void _maybeShowPendingFeedback() {
    final peer = state.pendingFeedbackPeer;
    if (peer == null || _isDriverMode) return;
    if (state.phase != SessionPhase.idle) return;
    state = state.copyWith(phase: SessionPhase.feedback, peer: peer);
  }

  Future<void> submitFeedback(FeedbackRating rating, {bool? wantAgain}) async {
    final peer = state.peer;
    if (peer != null) {
      await ref
          .read(socialGraphServiceProvider)
          .addFeedback(
            peer.id,
            FeedbackEntry(at: _now, rating: rating, wantAgain: wantAgain),
          );
      _log('feedback', {'rating': rating.name, 'wantAgain': ?wantAgain});
    }
    _closeFeedback();
  }

  void skipFeedback() => _closeFeedback();

  void _closeFeedback() {
    state = state.copyWith(
      phase: SessionPhase.idle,
      peer: null,
      pendingFeedbackPeer: null,
    );
  }

  // ------------------------------------------------------------ invitations

  void _onInvitation(Invitation inv) {
    if (state.phase == SessionPhase.inCall ||
        state.phase == SessionPhase.waitingForAnswer) {
      return; // busy — the inviter simply gets no answer
    }
    _log('invitation_received');
    state = state.copyWith(invitation: inv);
  }

  Future<void> respondToInvitation(InvitationResponse response) async {
    final inv = state.invitation;
    if (inv == null) return;
    await ref.read(invitationServiceProvider).respond(inv, response);
    _log('invitation_answered', {'response': response.name});
    switch (response) {
      case InvitationResponse.talkNow:
        final person = ref
            .read(socialGraphServiceProvider)
            .personById(inv.fromPersonId);
        state = state.copyWith(invitation: null);
        if (person != null) await _startCall(person);
      case InvitationResponse.notNow:
        state = state.copyWith(invitation: null);
      case InvitationResponse.mute:
        final profile = ref.read(profileServiceProvider);
        final hours = ref.read(matchingConfigProvider).snooze.beaconMuteHours;
        await profile.updatePrefs(
          profile.prefs.copyWith(
            beaconMutedUntil: _now.add(Duration(hours: hours)),
          ),
        );
        state = state.copyWith(
          invitation: null,
          notice: _notice(NoticeKind.invitationMuted),
        );
    }
  }

  // ---------------------------------------------------------------- vehicle

  Future<void> _onVehicleEvent(VehicleEvent e) async {
    if (e.transition == VehicleTransition.enter) {
      state = state.copyWith(inVehicle: true);
      _log('vehicle_enter', {'confidence': e.confidence.name});
      final prefs = ref.read(profileServiceProvider).prefs;
      final mine = ref.read(availabilityServiceProvider).mine;
      final alreadyAvailable = mine != null && mine.isActiveAt(_now);
      // Automatic AVAILABILITY only — never an automatic call.
      if (prefs.autoDrivingAvailability && !alreadyAvailable) {
        await startAvailability(
          AvailabilityMode.driving,
          untilTripEnds: true,
          source: AvailabilitySource.automaticVehicle,
        );
      }
      return;
    }
    state = state.copyWith(inVehicle: false);
    _log('vehicle_exit');
    final mine = ref.read(availabilityServiceProvider).mine;
    final tripBound =
        mine != null &&
        (mine.untilTripEnds ||
            mine.source == AvailabilitySource.automaticVehicle);
    if (tripBound) {
      if (state.phase == SessionPhase.inCall) {
        state = state.copyWith(stopAfterCall: true);
      } else {
        await _endWindow();
        return;
      }
    }
    _maybeShowPendingFeedback();
  }
}
