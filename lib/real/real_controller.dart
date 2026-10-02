import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import '../l10n/app_localizations.dart';
import '../platform/phone_dialer.dart';
import '../platform/voice_service.dart';
import 'backend_config.dart';
import 'local_store.dart';
import 'real_backend.dart';
import 'real_models.dart';
import 'supabase_backend.dart';

// ---------------------------------------------------------------------------
// Demo (fake people) vs. real (two-user test). Kept completely separate: the
// demo world is never sent to the server, real friends never appear in demo.
// ---------------------------------------------------------------------------

enum AppMode { demo, real }

const _modeKey = 'app.mode';

final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(
  AppModeNotifier.new,
);

class AppModeNotifier extends Notifier<AppMode> {
  @override
  AppMode build() {
    final stored = ref.watch(localStoreProvider).getString(_modeKey);
    if (stored == 'real') return AppMode.real;
    if (stored == 'demo') return AppMode.demo;
    return ref.watch(realBackendProvider).isConfigured
        ? AppMode.real
        : AppMode.demo;
  }

  void set(AppMode mode) {
    state = mode;
    ref.read(localStoreProvider).setString(_modeKey, mode.name);
  }
}

final realBackendProvider = Provider<RealBackend>(
  (ref) => SupabaseRealBackend(),
);

/// "Now" for real mode (tests use fake time).
final realClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Base of invitation links (empty → message with download link + code).
final inviteBaseUrlProvider = Provider<String>(
  (ref) => BackendConfig.inviteBaseUrl,
);

final apkUrlProvider = Provider<String>((ref) => BackendConfig.apkUrl);

/// App version for diagnostics (overridden in main from package_info).
final appVersionProvider = Provider<String>((ref) => '?');

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum RealPhase { notConfigured, starting, signedOut, ready }

/// Who places the regular phone call once BOTH said yes.
enum CallRole {
  /// I have their number (they chose to share it) → I call.
  iCall,

  /// They have my number → they call me.
  theyCall,

  /// No numbers shared → simulated in-app call (real audio comes later).
  inApp,
}

enum CallStage {
  none,
  connecting,
  dialed,
  waitingForTheirCall,
  inApp,
  feedback,
}

class RealCall {
  const RealCall({
    required this.offerId,
    required this.other,
    required this.role,
    required this.startedAt,
    this.phone,
  });
  final String offerId;
  final RealProfile other;
  final CallRole role;
  final DateTime startedAt;

  /// Only for [CallRole.iCall]; never shown on screen or in diagnostics.
  final String? phone;
}

enum RealNoticeKind {
  didNotWorkOut,
  connected,
  inviteProblem,
  error,
  blocked,
  reported,
  unmatched,
  feedbackThanks,
  saved,
  dialFailed,
  micDenied,
}

class RealNotice {
  const RealNotice(this.id, this.kind, {this.name, this.gender, this.code});
  final int id;
  final RealNoticeKind kind;
  final String? name;
  final Gender? gender;

  /// For errors: a short code like "offline" (never secret).
  final String? code;
}

class RealPrefs {
  const RealPrefs({this.voice = true, this.testTab = true});
  final bool voice;
  final bool testTab;

  RealPrefs copyWith({bool? voice, bool? testTab}) =>
      RealPrefs(voice: voice ?? this.voice, testTab: testTab ?? this.testTab);

  Map<String, Object?> toJson() => {'voice': voice, 'testTab': testTab};
  static RealPrefs fromJson(Map<String, Object?> j) => RealPrefs(
    voice: j['voice'] as bool? ?? true,
    testTab: j['testTab'] as bool? ?? true,
  );
}

/// An invitation link/code opened on this phone.
class PendingInvite {
  const PendingInvite(this.token, {this.info, this.loading = false});
  final String token;
  final InviteInfo? info;
  final bool loading;
}

class RealState {
  const RealState({
    required this.phase,
    this.snapshot,
    this.live = LiveStatus.disconnected,
    this.busy = false,
    this.lastError,
    this.lastErrorAt,
    this.invite,
    this.callStage = CallStage.none,
    this.call,
    this.dialCountdown = 0,
    this.notice,
    this.prefs = const RealPrefs(),
    this.myPhone,
    this.localAnswers = const {},
    this.dismissedOffers = const {},
    this.listening = false,
  });

  final RealPhase phase;
  final RealSnapshot? snapshot;
  final LiveStatus live;
  final bool busy;
  final String? lastError;
  final DateTime? lastErrorAt;
  final PendingInvite? invite;
  final CallStage callStage;
  final RealCall? call;
  final int dialCountdown;
  final RealNotice? notice;
  final RealPrefs prefs;
  final String? myPhone;

  /// Answers sent but not yet confirmed by a fresh snapshot.
  final Map<String, bool> localAnswers;

  /// Offers I said "not now" to (hidden immediately).
  final Set<String> dismissedOffers;
  final bool listening;

  String? get myId => snapshot?.me.id;

  static const _keep = Object();

  RealState copyWith({
    RealPhase? phase,
    Object? snapshot = _keep,
    LiveStatus? live,
    bool? busy,
    Object? lastError = _keep,
    Object? lastErrorAt = _keep,
    Object? invite = _keep,
    CallStage? callStage,
    Object? call = _keep,
    int? dialCountdown,
    Object? notice = _keep,
    RealPrefs? prefs,
    Object? myPhone = _keep,
    Map<String, bool>? localAnswers,
    Set<String>? dismissedOffers,
    bool? listening,
  }) => RealState(
    phase: phase ?? this.phase,
    snapshot: identical(snapshot, _keep)
        ? this.snapshot
        : snapshot as RealSnapshot?,
    live: live ?? this.live,
    busy: busy ?? this.busy,
    lastError: identical(lastError, _keep)
        ? this.lastError
        : lastError as String?,
    lastErrorAt: identical(lastErrorAt, _keep)
        ? this.lastErrorAt
        : lastErrorAt as DateTime?,
    invite: identical(invite, _keep) ? this.invite : invite as PendingInvite?,
    callStage: callStage ?? this.callStage,
    call: identical(call, _keep) ? this.call : call as RealCall?,
    dialCountdown: dialCountdown ?? this.dialCountdown,
    notice: identical(notice, _keep) ? this.notice : notice as RealNotice?,
    prefs: prefs ?? this.prefs,
    myPhone: identical(myPhone, _keep) ? this.myPhone : myPhone as String?,
    localAnswers: localAnswers ?? this.localAnswers,
    dismissedOffers: dismissedOffers ?? this.dismissedOffers,
    listening: listening ?? this.listening,
  );
}

// ---------------------------------------------------------------------------
// Pure helpers (also used by the UI)
// ---------------------------------------------------------------------------

/// My availability if it is still running at [now].
RealAvailability? myActiveAvailability(RealState s, DateTime now) {
  final mine = s.snapshot?.mine;
  return mine != null && mine.isActiveAt(now) ? mine : null;
}

/// Friends free right now (not me), soonest-ending last.
List<(RealProfile, RealAvailability)> freeFriends(RealState s, DateTime now) {
  final snap = s.snapshot;
  if (snap == null) return const [];
  return [
    for (final f in snap.friends)
      if (snap.availability[f.id] case final a? when a.isActiveAt(now)) (f, a),
  ]..sort((x, y) => y.$2.expiresAt.compareTo(x.$2.expiresAt));
}

/// No call in progress (a pending feedback question doesn't count).
bool _callIdle(RealState s) =>
    s.callStage == CallStage.none || s.callStage == CallStage.feedback;

bool? _myAnswer(RealState s, RealOffer o) =>
    s.localAnswers[o.id] ?? o.myAnswer(s.myId!);

/// The offer waiting for MY answer (oldest first), if any.
RealOffer? currentOffer(RealState s, DateTime now) {
  final snap = s.snapshot;
  if (snap == null || !_callIdle(s)) return null;
  final open = [
    for (final o in snap.offers)
      if (o.status == OfferStatus.pending &&
          now.isBefore(o.expiresAt) &&
          _myAnswer(s, o) == null &&
          !s.dismissedOffers.contains(o.id) &&
          snap.friend(o.otherId(snap.me.id)) != null)
        o,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return open.firstOrNull;
}

/// The offer I said yes to and that waits for the other side.
RealOffer? waitingOffer(RealState s, DateTime now) {
  final snap = s.snapshot;
  if (snap == null || !_callIdle(s)) return null;
  for (final o in snap.offers) {
    if (o.status == OfferStatus.pending &&
        now.isBefore(o.expiresAt) &&
        _myAnswer(s, o) == true &&
        snap.friend(o.otherId(snap.me.id)) != null) {
      return o;
    }
  }
  return null;
}

bool isRealDriving(RealState s, DateTime now) =>
    myActiveAvailability(s, now)?.mode == AvailabilityMode.driving;

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

final realProvider = NotifierProvider<RealController, RealState>(
  RealController.new,
);

const _prefsKey = 'real.prefs.v1';
const _handledKey = 'real.handledOffers.v1';

class RealController extends Notifier<RealState> {
  late RealBackend _backend;
  late LocalStore _store;
  late DateTime Function() _now;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _debounce;
  Timer? _ticker;
  Timer? _dialTimer;
  AppLifecycleListener? _lifecycle;
  var _noticeSeq = 0;
  var _voiceSeq = 0;
  var _tick = 0;
  var _refreshing = false;
  var _refreshAgain = false;
  String? _spokenOfferId;

  /// Offers whose outcome was already shown (so a restart doesn't repeat it).
  final _handled = <String>{};

  AppLocalizations get _l => lookupAppLocalizations(const Locale('he'));

  @override
  RealState build() {
    _backend = ref.watch(realBackendProvider);
    _store = ref.watch(localStoreProvider);
    _now = ref.watch(realClockProvider);
    ref.onDispose(_dispose);

    var prefs = const RealPrefs();
    try {
      final raw = _store.getString(_prefsKey);
      if (raw != null) {
        prefs = RealPrefs.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>(),
        );
      }
      final handled = _store.getString(_handledKey);
      if (handled != null) {
        _handled.addAll((jsonDecode(handled) as List).cast<String>());
      }
    } catch (_) {}

    if (!_backend.isConfigured) {
      return RealState(phase: RealPhase.notConfigured, prefs: prefs);
    }
    Future.microtask(_start);
    return RealState(phase: RealPhase.starting, prefs: prefs);
  }

  void _dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _debounce?.cancel();
    _ticker?.cancel();
    _dialTimer?.cancel();
    _lifecycle?.dispose();
  }

  Future<void> _start() async {
    _subs.add(
      _backend.changes.listen((_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), refresh);
      }),
    );
    _subs.add(
      _backend.liveStatus.listen((s) {
        if (ref.mounted) state = state.copyWith(live: s);
      }),
    );
    // Safety net when realtime is down: refresh every 10s while something is
    // going on, every 30s otherwise; also notice my own expiry promptly.
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => _onTick());
    try {
      _lifecycle = AppLifecycleListener(onResume: _onResume);
    } catch (_) {
      // No binding (pure unit tests).
    }

    try {
      await _backend.start();
    } on RealBackendException catch (e) {
      _setError(e.code);
    }
    if (!ref.mounted) return;
    if (_backend.userId == null) {
      state = state.copyWith(phase: RealPhase.signedOut);
      return;
    }
    await refresh();
    if (!ref.mounted) return;
    if (state.snapshot == null && state.lastError == 'no_profile') {
      state = state.copyWith(phase: RealPhase.signedOut);
      return;
    }
    // Known account but offline: still show the app (it retries).
    state = state.copyWith(phase: RealPhase.ready);
    unawaited(_loadPhone());
    _openPendingInvite();
  }

  void _onTick() {
    if (state.phase != RealPhase.ready) return;
    _tick++;
    final now = _now();
    final mine = state.snapshot?.mine;
    final myExpired = mine != null && !mine.isActiveAt(now);
    final busy =
        myActiveAvailability(state, now) != null ||
        waitingOffer(state, now) != null;
    final every = busy || state.live != LiveStatus.connected ? 2 : 6;
    if (myExpired || _tick % every == 0) refresh();
  }

  void _onResume() {
    if (state.phase != RealPhase.ready) return;
    // Back from the phone call → ask how it went.
    if (state.callStage == CallStage.dialed) {
      state = state.copyWith(callStage: CallStage.feedback);
    }
    refresh();
  }

  // ------------------------------------------------------------ account

  Future<void> signIn(String name, Gender gender, {String? phone}) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await _backend.signIn(name, gender);
      if (phone != null && phone.trim().isNotEmpty) {
        try {
          await _backend.setMyPhone(phone);
          state = state.copyWith(myPhone: normalizePhone(phone));
        } on RealBackendException catch (e) {
          _setError(e.code, show: true);
        }
      }
      if (!ref.mounted) return;
      state = state.copyWith(phase: RealPhase.ready, busy: false);
      await refresh();
      _openPendingInvite();
    } on RealBackendException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(busy: false);
      _setError(e.code, show: true);
    }
  }

  Future<void> updateProfile(String name, Gender gender) async {
    await _run(() async {
      await _backend.updateProfile(name, gender);
      _notify(RealNoticeKind.saved);
    });
    await refresh();
  }

  Future<void> _loadPhone() async {
    try {
      final p = await _backend.getMyPhone();
      if (ref.mounted) state = state.copyWith(myPhone: p);
    } on RealBackendException {
      // Not important enough to bother the user.
    }
  }

  /// Save (or remove, with null/empty) my number for regular calls.
  Future<bool> setMyPhone(String? phone) async {
    final value = (phone == null || phone.trim().isEmpty) ? null : phone;
    if (value != null && normalizePhone(value) == null) {
      _setError('invalid_phone', show: true);
      return false;
    }
    return _run(() async {
      await _backend.setMyPhone(value);
      state = state.copyWith(
        myPhone: value == null ? null : normalizePhone(value),
      );
      _notify(RealNoticeKind.saved);
    });
  }

  /// Start over as a new user on this phone (the old test account stays
  /// on the server but is no longer used).
  Future<void> signOut() async {
    await _backend.signOut();
    if (!ref.mounted) return;
    state = RealState(phase: RealPhase.signedOut, prefs: state.prefs);
  }

  void setPrefs(RealPrefs prefs) {
    state = state.copyWith(prefs: prefs);
    _store.setString(_prefsKey, jsonEncode(prefs.toJson()));
    if (!prefs.voice) _stopVoice();
  }

  // ------------------------------------------------------------ data

  Future<void> refresh() async {
    if (state.phase == RealPhase.notConfigured ||
        state.phase == RealPhase.signedOut ||
        _backend.userId == null) {
      return;
    }
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      final snap = await _backend.fetchSnapshot();
      if (!ref.mounted) return;
      final prev = state;
      // Drop local answers the server now knows about.
      final answers = {
        for (final e in prev.localAnswers.entries)
          if (snap.offers.any(
            (o) => o.id == e.key && o.myAnswer(snap.me.id) == null,
          ))
            e.key: e.value,
      };
      state = state.copyWith(
        snapshot: snap,
        localAnswers: answers,
        lastError: prev.lastError == 'offline' ? null : prev.lastError,
      );
      _react(snap);
    } on RealBackendException catch (e) {
      if (ref.mounted) _setError(e.code);
    } finally {
      _refreshing = false;
      if (_refreshAgain && ref.mounted) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    }
  }

  /// What changed on the server that the user must see.
  void _react(RealSnapshot snap) {
    final me = snap.me.id;
    final now = _now();
    for (final o in snap.offers) {
      if (_handled.contains(o.id)) continue;
      final mine = state.localAnswers[o.id] ?? o.myAnswer(me);
      final other = snap.friend(o.otherId(me));
      final fresh =
          now.difference(o.updatedAt).abs() < const Duration(minutes: 5);
      switch (o.status) {
        case OfferStatus.accepted:
          _markHandled(o.id);
          if (fresh && other != null && _callIdle(state)) {
            unawaited(_beginCall(o, other));
          }
        case OfferStatus.declined:
        case OfferStatus.expired:
        case OfferStatus.cancelled:
          _markHandled(o.id);
          // Only the one who said yes is told — gently, without blame.
          if (fresh && mine == true) {
            _notify(RealNoticeKind.didNotWorkOut);
            if (_driving(now)) _speak(_l.realVoiceDidNotWorkOut);
          }
        case OfferStatus.pending:
          break;
      }
    }
    // A new question for me → read it aloud when driving.
    final offer = currentOffer(state, now);
    if (offer != null && offer.id != _spokenOfferId && _driving(now)) {
      _spokenOfferId = offer.id;
      final p = snap.friend(offer.otherId(me))!;
      unawaited(_askByVoice(offer, p));
    }
  }

  bool _driving(DateTime now) => state.prefs.voice && isRealDriving(state, now);

  void _markHandled(String id) {
    _handled.add(id);
    final list = _handled.toList();
    final keep = list.length > 100 ? list.sublist(list.length - 100) : list;
    _store.setString(_handledKey, jsonEncode(keep));
  }

  // ------------------------------------------------------------ availability

  Future<bool> startAvailability(AvailabilityMode mode, int minutes) async {
    final ok = await _run(
      () => _backend.setAvailability(mode, minutes.clamp(1, 180)),
    );
    await refresh();
    return ok;
  }

  Future<void> stopAvailability() async {
    _stopVoice();
    await _run(_backend.clearAvailability);
    await refresh();
  }

  // ------------------------------------------------------------ offers

  Future<void> respond(RealOffer offer, {required bool accept}) async {
    _stopVoice();
    if (accept) {
      state = state.copyWith(
        localAnswers: {...state.localAnswers, offer.id: true},
      );
    } else {
      // "Not now" hides it at once; the other side only hears "didn't work out".
      state = state.copyWith(
        dismissedOffers: {...state.dismissedOffers, offer.id},
      );
      _markHandled(offer.id);
    }
    try {
      final status = await _backend.respondOffer(offer.id, accept: accept);
      if (!ref.mounted) return;
      if (accept && status == OfferStatus.accepted) {
        final other = state.snapshot?.friend(offer.otherId(state.myId!));
        _markHandled(offer.id);
        if (other != null) unawaited(_beginCall(offer, other));
      } else if (accept &&
          (status == OfferStatus.expired ||
              status == OfferStatus.cancelled ||
              status == OfferStatus.declined)) {
        _markHandled(offer.id);
        _notify(RealNoticeKind.didNotWorkOut);
      }
    } on RealBackendException catch (e) {
      if (!ref.mounted) return;
      final answers = {...state.localAnswers}..remove(offer.id);
      state = state.copyWith(localAnswers: answers);
      _setError(e.code, show: true);
    }
    await refresh();
  }

  /// Stop waiting for the other side (counts as "not now" for this offer).
  Future<void> cancelWaiting(RealOffer offer) async {
    _markHandled(offer.id);
    await _run(() => _backend.respondOffer(offer.id, accept: false));
    await refresh();
  }

  Future<void> _askByVoice(RealOffer offer, RealProfile p) async {
    final seq = ++_voiceSeq;
    final voice = ref.read(voiceServiceProvider);
    await voice.speak(_l.realVoiceOffer(p.name, _genderKey(p.gender)));
    if (seq != _voiceSeq || !ref.mounted) return;
    state = state.copyWith(listening: true);
    final answer = await voice.listenYesNo();
    if (seq != _voiceSeq || !ref.mounted) return;
    state = state.copyWith(listening: false);
    if (currentOffer(state, _now())?.id != offer.id) return;
    switch (answer) {
      case VoiceAnswer.yes:
        await respond(offer, accept: true);
      case VoiceAnswer.no:
        await respond(offer, accept: false);
      case VoiceAnswer.permissionDenied:
        _notify(RealNoticeKind.micDenied);
      case VoiceAnswer.none:
      case VoiceAnswer.unavailable:
        break; // the big buttons are always there
    }
  }

  void _speak(String text) {
    _voiceSeq++;
    unawaited(ref.read(voiceServiceProvider).speak(text));
  }

  void _stopVoice() {
    _voiceSeq++;
    ref.read(voiceServiceProvider).stop();
    if (state.listening) state = state.copyWith(listening: false);
  }

  // ------------------------------------------------------------ the call

  Future<void> _beginCall(RealOffer offer, RealProfile other) async {
    if (!_callIdle(state)) return;
    _stopVoice();
    // Show "connecting" at once; numbers are fetched only now.
    state = state.copyWith(
      callStage: CallStage.connecting,
      call: RealCall(
        offerId: offer.id,
        other: other,
        role: CallRole.inApp,
        startedAt: _now(),
      ),
      dialCountdown: 0,
    );
    var details = const CallDetails();
    try {
      details = await _backend.callDetails(offer.id);
    } on RealBackendException catch (e) {
      _setError(e.code);
    }
    if (!ref.mounted || state.call?.offerId != offer.id) return;
    final me = state.myId!;
    final role =
        details.otherPhone != null && (!details.iShare || me == offer.userA)
        ? CallRole.iCall
        : details.iShare
        ? CallRole.theyCall
        : CallRole.inApp;
    final call = RealCall(
      offerId: offer.id,
      other: other,
      role: role,
      startedAt: _now(),
      phone: role == CallRole.iCall ? details.otherPhone : null,
    );
    switch (role) {
      case CallRole.iCall:
        // Short, cancellable countdown, then the phone's own dialer.
        state = state.copyWith(call: call, dialCountdown: 3);
        if (_driving(_now())) {
          _speak(_l.realVoiceCalling(other.name));
        }
        _dialTimer?.cancel();
        _dialTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!ref.mounted || state.call?.offerId != offer.id) {
            t.cancel();
            return;
          }
          final left = state.dialCountdown - 1;
          if (left > 0) {
            state = state.copyWith(dialCountdown: left);
          } else {
            t.cancel();
            state = state.copyWith(dialCountdown: 0);
            unawaited(_dial());
          }
        });
      case CallRole.theyCall:
        state = state.copyWith(
          call: call,
          callStage: CallStage.waitingForTheirCall,
        );
        if (_driving(_now())) {
          _speak(_l.realVoiceTheyCall(other.name, _genderKey(other.gender)));
        }
      case CallRole.inApp:
        state = state.copyWith(call: call, callStage: CallStage.inApp);
    }
  }

  /// "Call now" without waiting for the countdown.
  Future<void> dialNow() async {
    _dialTimer?.cancel();
    await _dial();
  }

  Future<void> _dial() async {
    final call = state.call;
    if (call == null || call.phone == null) return;
    if (state.callStage != CallStage.connecting) return;
    state = state.copyWith(callStage: CallStage.dialed, dialCountdown: 0);
    final r = await ref.read(phoneDialerProvider).call(call.phone!);
    if (!ref.mounted) return;
    if (r == DialResult.failed || r == DialResult.unsupported) {
      // Couldn't open the phone: fall back to the in-app (simulated) call.
      _notify(RealNoticeKind.dialFailed);
      state = state.copyWith(callStage: CallStage.inApp);
    }
  }

  /// Cancel during the countdown (before anything was dialed).
  void cancelCall() {
    _dialTimer?.cancel();
    _stopVoice();
    state = state.copyWith(callStage: CallStage.feedback, dialCountdown: 0);
  }

  void finishCall() {
    _dialTimer?.cancel();
    _stopVoice();
    state = state.copyWith(callStage: CallStage.feedback, dialCountdown: 0);
  }

  Future<void> sendFeedback({
    required bool talked,
    FeedbackRating? rating,
  }) async {
    final call = state.call;
    state = state.copyWith(callStage: CallStage.none, call: null);
    try {
      await _backend.sendFeedback(
        offerId: call?.offerId,
        talked: talked,
        rating: rating,
        wantAgain: rating == null ? null : rating != FeedbackRating.notReally,
      );
      if (ref.mounted) _notify(RealNoticeKind.feedbackThanks);
    } on RealBackendException catch (e) {
      if (ref.mounted) _setError(e.code);
    }
  }

  void skipFeedback() =>
      state = state.copyWith(callStage: CallStage.none, call: null);

  // ------------------------------------------------------------ invitations

  /// The text to share, with a link (or download link + code).
  Future<String?> createInviteMessage() async {
    String? message;
    await _run(() async {
      final inv = await _backend.createInvitation();
      message = inviteMessageFor(
        _l,
        token: inv.token,
        baseUrl: ref.read(inviteBaseUrlProvider),
        apkUrl: ref.read(apkUrlProvider),
      );
    });
    return message;
  }

  /// A link or code was opened on this phone.
  void openInvite(String token) {
    state = state.copyWith(invite: PendingInvite(token, loading: true));
    _openPendingInvite();
  }

  /// Returns false if [input] contains no invitation code.
  bool openInviteText(String input) {
    final token = parseInviteToken(input);
    if (token == null) return false;
    openInvite(token);
    return true;
  }

  Future<void> _openPendingInvite() async {
    final inv = state.invite;
    if (inv == null || state.phase != RealPhase.ready) return;
    try {
      final info = await _backend.getInvitation(inv.token);
      if (!ref.mounted || state.invite?.token != inv.token) return;
      state = state.copyWith(invite: PendingInvite(inv.token, info: info));
    } on RealBackendException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(invite: null);
      _setError(e.code, show: true);
    }
  }

  Future<void> acceptInvite() async {
    final inv = state.invite;
    if (inv == null) return;
    await _run(() async {
      final r = await _backend.acceptInvitation(inv.token);
      final name = inv.info?.inviterName;
      state = state.copyWith(invite: null);
      switch (r) {
        case AcceptResult.accepted:
        case AcceptResult.alreadyConnected:
          _notify(
            RealNoticeKind.connected,
            name: name,
            gender: inv.info?.inviterGender,
          );
        case AcceptResult.own:
        case AcceptResult.used:
        case AcceptResult.expired:
        case AcceptResult.notFound:
          _notify(RealNoticeKind.inviteProblem, code: r.name);
      }
    });
    await refresh();
  }

  void dismissInvite() => state = state.copyWith(invite: null);

  // ------------------------------------------------------------ safety

  Future<void> block(RealProfile p) async {
    await _run(() async {
      await _backend.block(p.id);
      _notify(RealNoticeKind.blocked, name: p.name, gender: p.gender);
    });
    await refresh();
  }

  Future<void> unmatch(RealProfile p) async {
    await _run(() async {
      await _backend.unmatch(p.id);
      _notify(RealNoticeKind.unmatched, name: p.name, gender: p.gender);
    });
    await refresh();
  }

  Future<void> report(RealProfile p, ReportReason reason) async {
    await _run(() async {
      await _backend.report(p.id, reason);
      _notify(RealNoticeKind.reported);
    });
  }

  // ------------------------------------------------------------ diagnostics

  /// Text for "copy test info": no keys, tokens, phone numbers or full ids.
  String diagnostics() {
    final s = state;
    final now = _now();
    final snap = s.snapshot;
    final mine = myActiveAvailability(s, now);
    final lastOffer = snap?.offers.isEmpty ?? true
        ? null
        : (snap!.offers.toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
              .first;
    String short(String? id) =>
        id == null ? '—' : (id.length <= 6 ? id : id.substring(0, 6));
    String time(DateTime? t) => t == null
        ? '—'
        : '${t.hour.toString().padLeft(2, '0')}:'
              '${t.minute.toString().padLeft(2, '0')}:'
              '${t.second.toString().padLeft(2, '0')}';
    return [
      'DriveTalk — test info',
      'version: ${ref.read(appVersionProvider)}',
      'mode: real',
      'server: ${BackendConfig.backendHost}',
      'configured: ${_backend.isConfigured}',
      'phase: ${s.phase.name}',
      'user: ${short(_backend.userId)}',
      'live: ${s.live.name}',
      'friends: ${snap?.friends.length ?? 0}',
      'me available: ${mine == null ? 'no' : '${mine.mode.name}, ${mine.minutesLeftAt(now)} min left'}',
      'friends free now: ${freeFriends(s, now).length}',
      'last offer: ${lastOffer == null ? '—' : '${lastOffer.status.name}, my answer ${lastOffer.myAnswer(snap!.me.id) ?? 'none'}, ${time(lastOffer.updatedAt)}'}',
      'call stage: ${s.callStage.name}${s.call == null ? '' : ' (${s.call!.role.name})'}',
      'phone shared: ${s.myPhone != null ? 'yes' : 'no'}',
      'last refresh: ${time(snap?.fetchedAt)}',
      'last error: ${s.lastError ?? '—'}${s.lastErrorAt == null ? '' : ' at ${time(s.lastErrorAt)}'}',
      'now: ${now.toIso8601String()}',
    ].join('\n');
  }

  // ------------------------------------------------------------ helpers

  Future<bool> _run(Future<void> Function() body) async {
    state = state.copyWith(busy: true);
    try {
      await body();
      if (ref.mounted) state = state.copyWith(busy: false);
      return true;
    } on RealBackendException catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
        _setError(e.code, show: true);
      }
      return false;
    }
  }

  void _setError(String code, {bool show = false}) {
    state = state.copyWith(lastError: code, lastErrorAt: _now());
    if (show) _notify(RealNoticeKind.error, code: code);
  }

  void _notify(
    RealNoticeKind kind, {
    String? name,
    Gender? gender,
    String? code,
  }) {
    state = state.copyWith(
      notice: RealNotice(
        ++_noticeSeq,
        kind,
        name: name,
        gender: gender,
        code: code,
      ),
    );
  }
}

String _genderKey(Gender g) => switch (g) {
  Gender.female => 'female',
  Gender.male => 'male',
  Gender.unspecified => 'other',
};

/// The share text. With an invite site: message + link. Without: message +
/// download link + code to type in the app.
String inviteMessageFor(
  AppLocalizations l, {
  required String token,
  required String baseUrl,
  required String apkUrl,
}) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  if (base.isNotEmpty) {
    return '${l.realInviteMessage}\n$base/i/$token';
  }
  return '${l.realInviteMessage}\n${l.realInviteMessageNoSite(apkUrl, token)}';
}
