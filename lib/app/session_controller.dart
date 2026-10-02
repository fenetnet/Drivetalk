import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../features/common/labels.dart';
import '../l10n/app_localizations.dart';
import '../matching/match_reason.dart';
import '../matching/matching_engine.dart';
import '../platform/vehicle_signal_source.dart';
import '../platform/voice_service.dart';
import '../services/call_service.dart';
import '../services/invitation_service.dart';
import '../services/match_service.dart';
import 'providers.dart';

enum SessionPhase {
  /// Not searching. May still be available ("resting" after a call).
  idle,
  searching,

  /// A few people to choose from (driver mode shows only the first).
  options,
  waitingForAnswer,

  /// Mutual "quick connect": short countdown with a big cancel, then call.
  quickConnecting,
  inCall,
  feedback,

  /// Recording a short voice note for someone who couldn't talk (simulated).
  voiceMessage,
}

enum NoticeKind {
  declinedByOther,
  noAnswer,
  noLongerAvailable,
  availabilityEnded,
  invitationMuted,
  blocked,
  reported,
  pausedNotToday,
  pausedForAWhile,
  voiceMessageSent,
  micPermissionDenied,
  quickConnectCancelled,
}

class SessionNotice {
  const SessionNotice(this.kind, this.id, {this.person});
  final NoticeKind kind;
  final int id;
  final Person? person;

  /// Offer "leave a voice message" after someone couldn't talk.
  bool get offersVoiceMessage =>
      kind == NoticeKind.declinedByOther || kind == NoticeKind.noAnswer;
}

const _keep = Object();

class SessionState {
  const SessionState({
    this.phase = SessionPhase.idle,
    this.options = const [],
    this.selected,
    this.peer,
    this.callStartedAt,
    this.callMethod,
    this.muted = false,
    this.callDropped = false,
    this.callOnHold = false,
    this.quickConnectAt,
    this.skippedIds = const {},
    this.beaconSent = false,
    this.beaconRecipients = 0,
    this.pendingFeedbackPeer,
    this.invitation,
    this.notice,
    this.windowStartedAt,
    this.hadCallThisWindow = false,
    this.quickConnectsThisWindow = 0,
    this.inVehicle = false,
    this.stopAfterCall = false,
    this.listening = false,
  });

  final SessionPhase phase;

  /// People to choose from right now, best first.
  final List<Suggestion> options;

  /// The one I chose ("talk now") and am waiting for.
  final Suggestion? selected;

  /// The person in the current call / countdown / feedback / voice note.
  final Person? peer;
  final DateTime? callStartedAt;
  final CallMethod? callMethod;
  final bool muted;

  /// In-app call lost the connection (scenario).
  final bool callDropped;

  /// In-app call put on hold by a regular incoming phone call (scenario).
  final bool callOnHold;

  /// When the quick-connect countdown ends.
  final DateTime? quickConnectAt;
  final Set<String> skippedIds;
  final bool beaconSent;
  final int beaconRecipients;

  /// Feedback is never asked while driving; it waits here.
  final Person? pendingFeedbackPeer;
  final Invitation? invitation;
  final SessionNotice? notice;
  final DateTime? windowStartedAt;
  final bool hadCallThisWindow;
  final int quickConnectsThisWindow;

  /// The device is probably in a vehicle (never "the user is driving").
  final bool inVehicle;
  final bool stopAfterCall;

  /// Driver mode is waiting for a spoken "yes" / "no".
  final bool listening;

  /// The suggestion in focus: the chosen one, else the top option.
  Suggestion? get suggestion =>
      selected ?? (options.isEmpty ? null : options.first);

  SessionState copyWith({
    SessionPhase? phase,
    List<Suggestion>? options,
    Object? selected = _keep,
    Object? peer = _keep,
    Object? callStartedAt = _keep,
    Object? callMethod = _keep,
    bool? muted,
    bool? callDropped,
    bool? callOnHold,
    Object? quickConnectAt = _keep,
    Set<String>? skippedIds,
    bool? beaconSent,
    int? beaconRecipients,
    Object? pendingFeedbackPeer = _keep,
    Object? invitation = _keep,
    Object? notice = _keep,
    Object? windowStartedAt = _keep,
    bool? hadCallThisWindow,
    int? quickConnectsThisWindow,
    bool? inVehicle,
    bool? stopAfterCall,
    bool? listening,
  }) => SessionState(
    phase: phase ?? this.phase,
    options: options ?? this.options,
    selected: identical(selected, _keep)
        ? this.selected
        : selected as Suggestion?,
    peer: identical(peer, _keep) ? this.peer : peer as Person?,
    callStartedAt: identical(callStartedAt, _keep)
        ? this.callStartedAt
        : callStartedAt as DateTime?,
    callMethod: identical(callMethod, _keep)
        ? this.callMethod
        : callMethod as CallMethod?,
    muted: muted ?? this.muted,
    callDropped: callDropped ?? this.callDropped,
    callOnHold: callOnHold ?? this.callOnHold,
    quickConnectAt: identical(quickConnectAt, _keep)
        ? this.quickConnectAt
        : quickConnectAt as DateTime?,
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
    quickConnectsThisWindow:
        quickConnectsThisWindow ?? this.quickConnectsThisWindow,
    inVehicle: inVehicle ?? this.inVehicle,
    stopAfterCall: stopAfterCall ?? this.stopAfterCall,
    listening: listening ?? this.listening,
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

/// Orchestrates one availability window: search → options → mutual consent
/// (or mutual quick connect) → call → feedback.
class SessionController extends Notifier<SessionState> {
  Timer? _tick;
  Timer? _searchTimer;
  Timer? _beaconTimer;
  Timer? _quickTimer;
  var _noticeSeq = 0;
  var _voiceSeq = 0;

  /// personId → last quick connect (max one per person per day).
  final _quickConnectLog = <String, DateTime>{};

  /// Call waiting to be recorded once we know whether we actually talked.
  Person? _unrecordedCall;

  @override
  SessionState build() {
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _checkExpiry());
    final subs = <StreamSubscription<Object?>>[
      ref.read(invitationServiceProvider).incoming.listen(_onInvitation),
      ref.read(invitationServiceProvider).answers.listen(_onInvitationAnswer),
      ref.read(vehicleSignalProvider).events.listen(_onVehicleEvent),
    ];
    ref.listen(dataVersionProvider, (_, _) => _onDataChanged());
    ref.onDispose(() {
      _tick?.cancel();
      _searchTimer?.cancel();
      _beaconTimer?.cancel();
      _quickTimer?.cancel();
      for (final s in subs) {
        s.cancel();
      }
    });
    return const SessionState();
  }

  DateTime get _now => ref.read(clockProvider).now();
  AppLocalizations get _l => lookupAppLocalizations(const Locale('he'));
  void _log(String name, [Map<String, Object> props = const {}]) =>
      ref.read(analyticsServiceProvider).log(name, props);

  SessionNotice _notice(NoticeKind kind, {Person? person}) =>
      SessionNotice(kind, ++_noticeSeq, person: person);

  bool get _isDriverMode => isDriverMode(
    inVehicle: state.inVehicle,
    mine: ref.read(availabilityServiceProvider).mine,
    now: _now,
  );

  bool get _online => ref.read(networkServiceProvider).online;

  bool get _available {
    final mine = ref.read(availabilityServiceProvider).mine;
    return mine != null && mine.isActiveAt(_now);
  }

  void _onDataChanged() {
    switch (state.phase) {
      case SessionPhase.searching:
        if (!(_searchTimer?.isActive ?? false)) {
          _scheduleSearch(const Duration(milliseconds: 400));
        }
      case SessionPhase.waitingForAnswer:
        _checkWaitingStillPossible();
      default:
        break;
    }
  }

  // ------------------------------------------------------------ availability

  Future<void> startAvailability(
    AvailabilityMode mode, {
    int? minutes,
    bool untilTripEnds = false,
    AvailabilitySource source = AvailabilitySource.manual,
    String? circleId,
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
            circleId: circleId,
          ),
        );
    _log('availability_opened', {
      'mode': mode.name,
      'minutes': untilTripEnds ? 'trip' : duration.inMinutes,
      'source': source.name,
      'circle': circleId != null,
    });
    state = state.copyWith(
      phase: SessionPhase.searching,
      options: const [],
      selected: null,
      skippedIds: {},
      beaconSent: false,
      beaconRecipients: 0,
      windowStartedAt: now,
      hadCallThisWindow: false,
      quickConnectsThisWindow: 0,
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
    _quickTimer?.cancel();
    _stopVoice();
    if (state.windowStartedAt != null && !state.hadCallThisWindow) {
      _log('window_ended_without_call');
    }
    await ref.read(availabilityServiceProvider).stop();
    state = state.copyWith(
      phase: SessionPhase.idle,
      options: const [],
      selected: null,
      windowStartedAt: null,
      quickConnectAt: null,
      stopAfterCall: false,
      notice: expired ? _notice(NoticeKind.availabilityEnded) : state.notice,
    );
    _maybeShowPendingFeedback();
  }

  void _checkExpiry() {
    final mine = ref.read(availabilityServiceProvider).mine;
    if (mine == null || mine.isActiveAt(_now)) return;
    // A call (or voice note) in progress is never cut by a timer.
    if (state.phase == SessionPhase.inCall ||
        state.phase == SessionPhase.voiceMessage) {
      return;
    }
    _endWindow(expired: true);
  }

  // ---------------------------------------------------------------- search

  void _scheduleSearch(Duration delay) {
    _searchTimer?.cancel();
    _searchTimer = Timer(delay, _search);
  }

  void _search() {
    if (state.phase != SessionPhase.searching || !_available) return;
    if (!_online) {
      // No internet: try again shortly. The UI shows a banner.
      _scheduleSearch(const Duration(seconds: 3));
      return;
    }
    final config = ref.read(matchingConfigProvider);
    final result = ref
        .read(matchingFacadeProvider)
        .rank(excludeIds: state.skippedIds);
    if (ref.read(debugForceNoMatchProvider)) {
      _noMatchYet();
      return;
    }

    // Mutual quick connect comes first: no extra approval needed.
    final quick = _quickConnectCandidate(result);
    if (quick != null) {
      _startQuickConnect(quick);
      return;
    }

    final options = ref
        .read(matchingEngineProvider)
        .pickOptions(result, config.optionsShown);
    if (options.isEmpty) {
      _noMatchYet();
      return;
    }
    _showOptions(options);
  }

  void _noMatchYet() {
    if (!state.beaconSent && !(_beaconTimer?.isActive ?? false)) {
      final wait = ref
          .read(matchingConfigProvider)
          .beacon
          .waitSecondsBeforeBeacon;
      _beaconTimer = Timer(Duration(seconds: wait), _sendBeacon);
    }
  }

  void _showOptions(List<Suggestion> options) {
    _beaconTimer?.cancel();
    final now = _now;
    for (final s in options) {
      ref.read(matchServiceProvider).markSuggested(s.person.id, now);
      _log('suggestion_shown', {
        'tier': s.candidate.tier.name,
        'exploration': s.isExploration,
        'answeredInvitation': s.alreadyAccepted,
      });
    }
    state = state.copyWith(
      phase: SessionPhase.options,
      options: options,
      selected: null,
    );
    if (_isDriverMode) _announceTopOption();
  }

  /// Look for more people: everyone shown now is skipped for this window.
  void moreOptions() {
    _log('more_options');
    _skipAndSearch([for (final s in state.options) s.person.id]);
  }

  /// Simulate pressing "search" again after resting.
  void searchAgain() {
    if (!_available) return;
    state = state.copyWith(
      phase: SessionPhase.searching,
      options: const [],
      selected: null,
    );
    _scheduleSearch(const Duration(milliseconds: 1200));
  }

  /// Availability Beacon: when nobody is free right now, invite a few
  /// relevant people — never everyone — within rate limits.
  Future<void> _sendBeacon() async {
    if (state.phase != SessionPhase.searching || state.beaconSent) return;
    final mine = ref.read(availabilityServiceProvider).mine;
    if (mine == null || !mine.isActiveAt(_now) || !_online) return;
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
    _showOptions([
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
    ]);
  }

  // ---------------------------------------------------------- quick connect

  Person? _quickConnectCandidate(RankResult result) {
    final config = ref.read(matchingConfigProvider).quickConnect;
    if (state.quickConnectsThisWindow >= config.maxPerWindow) return null;
    final graph = ref.read(socialGraphServiceProvider);
    final now = _now;
    for (final c in result.ranked) {
      final id = c.input.person.id;
      if (!graph.isMutualQuickConnect(id)) continue;
      final last = _quickConnectLog[id];
      if (last != null &&
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day) {
        continue; // max one quick connect per person per day
      }
      return c.input.person;
    }
    return null;
  }

  void _startQuickConnect(Person person) {
    final seconds = ref
        .read(matchingConfigProvider)
        .quickConnect
        .countdownSeconds;
    final at = _now.add(Duration(seconds: seconds));
    _quickConnectLog[person.id] = _now;
    _log('quick_connect_countdown');
    state = state.copyWith(
      phase: SessionPhase.quickConnecting,
      peer: person,
      quickConnectAt: at,
      quickConnectsThisWindow: state.quickConnectsThisWindow + 1,
    );
    _quickTimer?.cancel();
    _quickTimer = Timer(Duration(seconds: seconds), () {
      if (state.phase == SessionPhase.quickConnecting &&
          state.peer?.id == person.id) {
        _log('quick_connect_called');
        _connect(person);
      }
    });
    // Announce and accept a spoken "cancel".
    final prefs = ref.read(profileServiceProvider).prefs;
    if (prefs.voiceReadout) {
      _speakThenListen(
        _l.voiceQuickConnect(person.name, seconds),
        onNo: cancelQuickConnect,
        listen: prefs.voiceCommands,
      );
    }
  }

  void cancelQuickConnect() {
    final p = state.peer;
    if (state.phase != SessionPhase.quickConnecting || p == null) return;
    _quickTimer?.cancel();
    _stopVoice();
    _log('quick_connect_cancelled');
    _skipAndSearch([
      p.id,
    ], notice: _notice(NoticeKind.quickConnectCancelled, person: p));
  }

  // ------------------------------------------------------- option actions

  Suggestion? _find(String personId) {
    for (final s in state.options) {
      if (s.person.id == personId) return s;
    }
    return state.selected?.person.id == personId ? state.selected : null;
  }

  /// "Talk now" with one of the options (default: the top one).
  Future<void> talkNow([Suggestion? choice]) async {
    final s = choice ?? state.suggestion;
    if (s == null) return;
    _stopVoice();
    _log('suggestion_accepted', {'tier': s.candidate.tier.name});
    if (s.alreadyAccepted) {
      await _connect(s.person);
      return;
    }
    state = state.copyWith(phase: SessionPhase.waitingForAnswer, selected: s);
    final timeout = Duration(
      seconds: ref.read(matchingConfigProvider).callAnswerTimeoutSeconds,
    );
    final outcome = await ref
        .read(matchServiceProvider)
        .requestCall(s.person.id)
        .timeout(timeout, onTimeout: () => CallRequestOutcome.timedOut);
    if (!ref.mounted) return;
    if (state.phase != SessionPhase.waitingForAnswer ||
        state.selected?.person.id != s.person.id) {
      return; // cancelled or replaced meanwhile
    }
    switch (outcome) {
      case CallRequestOutcome.accepted:
        await _connect(s.person);
      case CallRequestOutcome.declined:
        _log('call_request_declined');
        _dropOption(
          s.person.id,
          _notice(NoticeKind.declinedByOther, person: s.person),
        );
      case CallRequestOutcome.timedOut:
        _log('call_request_no_answer');
        _dropOption(
          s.person.id,
          _notice(NoticeKind.noAnswer, person: s.person),
        );
    }
  }

  /// While waiting: the other side stopped being available or blocked me.
  void _checkWaitingStillPossible() {
    final s = state.selected;
    if (s == null) return;
    final id = s.person.id;
    if (ref.read(socialGraphServiceProvider).blockedIds.contains(id)) {
      // Never reveal a block — it looks like "can't talk now".
      _dropOption(id, _notice(NoticeKind.declinedByOther, person: s.person));
      return;
    }
    final a = ref.read(availabilityServiceProvider).availabilityOf(id);
    if (!s.alreadyAccepted && (a == null || !a.isActiveAt(_now))) {
      _dropOption(id, _notice(NoticeKind.noLongerAvailable, person: s.person));
    }
  }

  void cancelWaiting() {
    final s = state.selected;
    if (s == null) return;
    _dropOption(s.person.id, null);
  }

  /// Driver mode "next": drop the top option.
  void next() {
    final s = state.suggestion;
    if (s == null) return;
    _stopVoice();
    _log('suggestion_skipped');
    _dropOption(s.person.id, null);
  }

  Future<void> notToday([Suggestion? s]) => _pause(PauseKind.notToday, s);
  Future<void> doNotSuggestForAWhile([Suggestion? s]) =>
      _pause(PauseKind.doNotSuggest, s);

  Future<void> _pause(PauseKind kind, Suggestion? choice) async {
    final s = choice ?? state.suggestion;
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
    _dropOption(
      s.person.id,
      _notice(
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
    if (_find(person.id) != null) {
      _dropOption(person.id, notice);
    } else {
      state = state.copyWith(notice: notice);
    }
  }

  /// Remove one person from the options; search again only if none are left.
  void _dropOption(String personId, SessionNotice? notice) {
    final remaining = [
      for (final s in state.options)
        if (s.person.id != personId) s,
    ];
    final skipped = {...state.skippedIds, personId};
    if (remaining.isEmpty || !_available) {
      _skipAndSearch([personId], notice: notice);
      return;
    }
    state = state.copyWith(
      phase: SessionPhase.options,
      options: remaining,
      selected: null,
      skippedIds: skipped,
      notice: notice ?? state.notice,
    );
    if (_isDriverMode) _announceTopOption();
  }

  void _skipAndSearch(List<String> personIds, {SessionNotice? notice}) {
    state = state.copyWith(
      phase: _available ? SessionPhase.searching : SessionPhase.idle,
      options: const [],
      selected: null,
      peer: null,
      quickConnectAt: null,
      skippedIds: {...state.skippedIds, ...personIds},
      notice: notice ?? state.notice,
    );
    if (_available) _scheduleSearch(const Duration(milliseconds: 1200));
  }

  // ------------------------------------------------------------------- call

  /// How we call [peer]: a regular phone call when numbers may be shared,
  /// otherwise inside the app (numbers stay private).
  CallMethod callMethodFor(Person peer) {
    final graph = ref.read(socialGraphServiceProvider);
    final me = ref.read(profileServiceProvider).me;
    if (peer.phoneNumber == null) return CallMethod.inApp;
    if (graph.connectionWith(peer.id) != null) return CallMethod.phone;
    final bothShare =
        me.sharesNumberWithFriendsOfFriends &&
        peer.sharesNumberWithFriendsOfFriends;
    return bothShare ? CallMethod.phone : CallMethod.inApp;
  }

  Future<void> _connect(Person peer) async {
    _searchTimer?.cancel();
    _beaconTimer?.cancel();
    _quickTimer?.cancel();
    _stopVoice();
    final method = callMethodFor(peer);
    if (method == CallMethod.inApp) {
      await ref.read(callServiceProvider).startInAppCall(peer.id);
    }
    // Phase 1: fake people are never dialed. If the owner set a test number,
    // that real number is dialed instead, to feel the real flow.
    if (method == CallMethod.phone) {
      final prefs = ref.read(profileServiceProvider).prefs;
      final test = prefs.testDialNumber;
      if (prefs.dialTestNumberOnEveryCall && test != null && test.isNotEmpty) {
        unawaited(ref.read(phoneDialerProvider).call(test));
      }
    }
    final started = state.windowStartedAt;
    _log('call_started', {
      'method': method.name,
      if (started != null) 'secondsToMatch': _now.difference(started).inSeconds,
    });
    state = state.copyWith(
      phase: SessionPhase.inCall,
      peer: peer,
      callStartedAt: _now,
      callMethod: method,
      muted: false,
      callDropped: false,
      callOnHold: false,
      invitation: null,
      quickConnectAt: null,
      hadCallThisWindow: true,
    );
  }

  Future<void> toggleMute() async {
    final muted = !state.muted;
    await ref.read(callServiceProvider).setMuted(muted);
    state = state.copyWith(muted: muted);
  }

  /// Scenario: the in-app call lost its connection.
  void simulateCallDropped() {
    if (state.phase != SessionPhase.inCall) return;
    _log('call_dropped');
    state = state.copyWith(callDropped: true);
  }

  Future<void> retryDroppedCall() async {
    final peer = state.peer;
    if (peer == null) return;
    await ref.read(callServiceProvider).startInAppCall(peer.id);
    state = state.copyWith(callDropped: false);
  }

  /// Scenario: a regular phone call came in during an in-app call.
  void simulateIncomingPhoneCall() {
    if (state.phase != SessionPhase.inCall ||
        state.callMethod != CallMethod.inApp) {
      return;
    }
    state = state.copyWith(callOnHold: true);
  }

  void resumeFromHold() => state = state.copyWith(callOnHold: false);

  Future<void> endCall() async {
    final peer = state.peer;
    if (state.phase != SessionPhase.inCall || peer == null) return;
    if (state.callMethod == CallMethod.inApp) {
      await ref.read(callServiceProvider).endInAppCall();
    }
    _log('call_ended', {
      'seconds': _now.difference(state.callStartedAt ?? _now).inSeconds,
    });
    _unrecordedCall = peer;
    final mine = ref.read(availabilityServiceProvider).mine;
    final windowOver =
        mine == null || !mine.isActiveAt(_now) || state.stopAfterCall;
    state = state.copyWith(
      phase: SessionPhase.idle,
      callStartedAt: null,
      callMethod: null,
      muted: false,
      callDropped: false,
      callOnHold: false,
      options: const [],
      selected: null,
      pendingFeedbackPeer: peer,
    );
    if (windowOver) {
      await _endWindow(expired: mine != null && !mine.isActiveAt(_now));
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

  /// We know we talked: count it as an in-app interaction (never the call log).
  Future<void> _recordCallIfPending({required bool talked}) async {
    final peer = _unrecordedCall;
    _unrecordedCall = null;
    if (peer == null || !talked) return;
    final graph = ref.read(socialGraphServiceProvider);
    final config = ref.read(matchingConfigProvider);
    final before = graph.connectionWith(peer.id);
    final last = before?.lastInteraction;
    if (last != null &&
        _now.difference(last).inDays >= config.dormantAfterDays) {
      _log('dormant_reconnected');
    }
    if (before == null && graph.mutualFriendsWith(peer.id) > 0) {
      _log('new_connection_via_friends_of_friends');
    }
    await graph.recordCall(peer.id, _now);
  }

  Future<void> submitFeedback(FeedbackRating rating, {bool? wantAgain}) async {
    final peer = state.peer;
    await _recordCallIfPending(talked: true);
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

  /// "We didn't end up talking" (e.g. the phone call wasn't answered).
  Future<void> didNotTalk() async {
    _log('call_not_answered');
    await _recordCallIfPending(talked: false);
    _closeFeedback();
  }

  Future<void> skipFeedback() async {
    await _recordCallIfPending(talked: true);
    _closeFeedback();
  }

  void _closeFeedback() {
    state = state.copyWith(
      phase: SessionPhase.idle,
      peer: null,
      pendingFeedbackPeer: null,
    );
  }

  // ---------------------------------------------------------- voice message

  /// Open the (simulated) voice-note recorder for someone who couldn't talk.
  void startVoiceMessage(Person person) {
    if (state.phase == SessionPhase.inCall) return;
    state = state.copyWith(phase: SessionPhase.voiceMessage, peer: person);
  }

  Future<void> sendVoiceMessage(Duration length) async {
    final p = state.peer;
    if (p == null) return;
    await ref.read(voiceMessageServiceProvider).send(p.id, length);
    _log('voice_message_sent', {'seconds': length.inSeconds});
    _leaveVoiceMessage(_notice(NoticeKind.voiceMessageSent, person: p));
  }

  void cancelVoiceMessage() => _leaveVoiceMessage(null);

  void _leaveVoiceMessage(SessionNotice? notice) {
    state = state.copyWith(
      phase: state.options.isNotEmpty
          ? SessionPhase.options
          : (_available ? SessionPhase.searching : SessionPhase.idle),
      peer: null,
      notice: notice ?? state.notice,
    );
    if (state.phase == SessionPhase.searching) {
      _scheduleSearch(const Duration(milliseconds: 800));
    }
  }

  // ------------------------------------------------------------ invitations

  void _onInvitation(Invitation inv) {
    // Busy in a call or countdown — the inviter simply gets no answer.
    if (state.phase == SessionPhase.inCall ||
        state.phase == SessionPhase.quickConnecting ||
        state.phase == SessionPhase.voiceMessage) {
      return;
    }
    _log('invitation_received');
    state = state.copyWith(invitation: inv);
    final person = ref
        .read(socialGraphServiceProvider)
        .personById(inv.fromPersonId);
    final prefs = ref.read(profileServiceProvider).prefs;
    if (person != null && _isDriverMode && prefs.voiceReadout) {
      _speakThenListen(
        _l.voiceInvitation(person.name, genderKey(person.gender), inv.minutes),
        listen: prefs.voiceCommands,
        onYes: () => respondToInvitation(InvitationResponse.talkNow),
        onNo: () => respondToInvitation(InvitationResponse.notNow),
      );
    }
  }

  Future<void> respondToInvitation(InvitationResponse response) async {
    final inv = state.invitation;
    if (inv == null) return;
    _stopVoice();
    await ref.read(invitationServiceProvider).respond(inv, response);
    _log('invitation_answered', {'response': response.name});
    switch (response) {
      case InvitationResponse.talkNow:
        final person = ref
            .read(socialGraphServiceProvider)
            .personById(inv.fromPersonId);
        // Accepting an invitation replaces whoever I was waiting for.
        state = state.copyWith(invitation: null, selected: null);
        if (person != null) await _connect(person);
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

  // ------------------------------------------------------------------ voice

  void _announceTopOption() {
    final s = state.suggestion;
    final prefs = ref.read(profileServiceProvider).prefs;
    if (s == null || !prefs.voiceReadout) return;
    final p = s.person;
    final minutes =
        ref
            .read(availabilityServiceProvider)
            .availabilityOf(p.id)
            ?.minutesLeftAt(_now) ??
        0;
    final who = relationshipLine(
      _l,
      connection: s.candidate.input.connection,
      mutualFriends: s.candidate.input.mutualFriends,
      sharedGroups: s.candidate.input.sharedGroups,
    );
    _speakThenListen(
      _l.voiceSuggestion(p.name, genderKey(p.gender), minutes, who),
      listen: prefs.voiceCommands,
      onYes: () {
        if (state.suggestion?.person.id == p.id) talkNow(s);
      },
      onNo: () {
        if (state.suggestion?.person.id == p.id) next();
      },
    );
  }

  /// Speak, then (optionally) listen for a spoken yes / no.
  Future<void> _speakThenListen(
    String text, {
    required bool listen,
    void Function()? onYes,
    void Function()? onNo,
  }) async {
    final seq = ++_voiceSeq;
    final voice = ref.read(voiceServiceProvider);
    await voice.speak(text);
    if (!listen || seq != _voiceSeq || !ref.mounted) return;
    state = state.copyWith(listening: true);
    final answer = await voice.listenYesNo();
    if (seq != _voiceSeq || !ref.mounted) return;
    state = state.copyWith(listening: false);
    switch (answer) {
      case VoiceAnswer.yes:
        _log('voice_answer', {'answer': 'yes'});
        onYes?.call();
      case VoiceAnswer.no:
        _log('voice_answer', {'answer': 'no'});
        onNo?.call();
      case VoiceAnswer.permissionDenied:
        state = state.copyWith(notice: _notice(NoticeKind.micPermissionDenied));
      case VoiceAnswer.none:
      case VoiceAnswer.unavailable:
        break; // big buttons are always there
    }
  }

  void _stopVoice() {
    _voiceSeq++;
    ref.read(voiceServiceProvider).stop();
    if (state.listening) state = state.copyWith(listening: false);
  }

  /// Scenario: pretend the microphone permission was refused.
  void simulateMicDenied() =>
      state = state.copyWith(notice: _notice(NoticeKind.micPermissionDenied));

  // ---------------------------------------------------------------- vehicle

  Future<void> _onVehicleEvent(VehicleEvent e) async {
    if (e.transition == VehicleTransition.enter) {
      state = state.copyWith(inVehicle: true);
      _log('vehicle_enter', {'confidence': e.confidence.name});
      final prefs = ref.read(profileServiceProvider).prefs;
      // Automatic AVAILABILITY only. Calls still need consent (or a mutual
      // quick-connect pre-approval with a cancellable countdown).
      if (prefs.autoDrivingAvailability && !_available) {
        await startAvailability(
          AvailabilityMode.driving,
          untilTripEnds: true,
          source: AvailabilitySource.automaticVehicle,
        );
      } else if (state.phase == SessionPhase.options) {
        _announceTopOption();
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
