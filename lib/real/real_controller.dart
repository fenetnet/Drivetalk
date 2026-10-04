import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/models.dart';
import '../l10n/app_localizations.dart';
import '../platform/contacts_reader.dart';
import '../platform/driving_detector.dart';
import '../platform/phone_dialer.dart';
import '../platform/voice_service.dart';
import 'backend_config.dart';
import 'contacts_hash.dart';
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

/// Phone contacts (numbers only, hashed before sending). Tests use a fake.
final contactsReaderProvider = Provider<ContactsReader>(
  (ref) => AndroidContactsReader(),
);

/// Automatic driving detection (Android). Tests use a fake.
final drivingDetectorProvider = Provider<DrivingDetector>(
  (ref) => AndroidDrivingDetector(),
);

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
    this.quick = false,
  });

  /// Quick connect (both pre-approved): no question, 5-second cancel.
  final bool quick;
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
  autoDrivingOn,
  autoDrivingOff,
  autoDrivingNoPermission,
  autoDrivingFailed,
  unblocked,
  contactsFound,
  contactsNone,
  contactsNoPermission,
  unblockedReconnected,
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
    this.driving = const DrivingStatus(),
    this.routines = const [],
  });

  /// My routines ("every weekday at 8:00, driving").
  final List<Routine> routines;

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

  /// Automatic driving availability on this phone.
  final DrivingStatus driving;

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
    DrivingStatus? driving,
    List<Routine>? routines,
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
    driving: driving ?? this.driving,
    routines: routines ?? this.routines,
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
  DateTime? _lastNudge;

  /// Downloaded profile photos: user id → (version, JPEG). Also kept on the
  /// phone so they don't download again on every launch.
  final _photos = <String, (int, Uint8List)>{};
  final _photoLoading = <String>{};

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

    final routines = _loadRoutines();
    if (!_backend.isConfigured) {
      return RealState(
        phase: RealPhase.notConfigured,
        prefs: prefs,
        routines: routines,
      );
    }
    Future.microtask(_start);
    return RealState(
      phase: RealPhase.starting,
      prefs: prefs,
      routines: routines,
    );
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
    final detector = ref.read(drivingDetectorProvider);
    _subs.add(
      detector.events.listen((e) {
        if (e == 'action') {
          unawaited(_handleLaunchAction());
        } else {
          // The background service updates the server; catch up shortly.
          unawaited(_loadDriving());
          Timer(const Duration(seconds: 2), refresh);
        }
      }),
    );
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
    unawaited(_loadDriving());
    unawaited(_handleLaunchAction());
    unawaited(_maybeSyncContacts());
    unawaited(_ensureDevice());
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
    unawaited(_loadDriving());
    unawaited(_handleLaunchAction());
  }

  // ------------------------------------------------------------ auto driving

  Future<void> _loadDriving() async {
    final detector = ref.read(drivingDetectorProvider);
    final st = await detector.status();
    if (!ref.mounted) return;
    // Keep the notification texts current after app updates.
    if (st.configured && !state.driving.configured) {
      unawaited(detector.updateTexts(_nativeTexts()));
    }
    state = state.copyWith(driving: st);
  }

  /// Turn on automatic driving availability (opt-in). Asks for the
  /// "physical activity" permission (and notifications).
  Future<bool> enableAutoDriving() async {
    final detector = ref.read(drivingDetectorProvider);
    if (!await detector.requestPermission()) {
      _notify(RealNoticeKind.autoDrivingNoPermission);
      await _loadDriving();
      return false;
    }
    var ok = false;
    await _run(() async {
      final token = await _backend.createDeviceToken();
      ok = await detector.enable(
        url: BackendConfig.supabaseUrl,
        key: BackendConfig.supabaseAnonKey,
        token: token,
        minutes: 120,
        texts: _nativeTexts(),
      );
      if (!ok) await _backend.revokeDeviceTokens();
    });
    _notify(
      ok ? RealNoticeKind.autoDrivingOn : RealNoticeKind.autoDrivingFailed,
    );
    await _loadDriving();
    return ok;
  }

  /// Texts for the Android notifications (Hebrew lives in the ARB file).
  Map<String, String> _nativeTexts() => {
    'channelStatus': _l.realNotifChannelStatus,
    'channelOffers': _l.realNotifChannelOffers,
    'statusTitle': _l.realNotifStatusTitle,
    'statusBody': _l.realNotifStatusBody,
    'stop': _l.driverStop,
    'offerTitle': _l.realOfferTitle('{name}', 'male'),
    'offerBody': _l.realOfferNote,
    'talk': _l.realTalkNow,
    'notNow': _l.realNotNow,
    'voiceOffer': _l.realVoiceOffer('{name}', 'male'),
    'quickTitle': _l.realQuickNotif('{name}'),
    'quickBody': _l.realQuickWhy,
    'voiceQuick': _l.realVoiceQuick('{name}'),
    'manualTitle': _l.realNotifManualTitle,
    'quickOff': _l.realQuickOff,
    'quickOn': _l.realQuickOn,
    'tileLabel': 'DriveTalk',
    'routineTitle': _l.realRoutineNotifTitle,
    'routineBody': _l.realRoutineNotifBody,
    'manualBody': _l.realNotifManualBody,
  };

  /// Background notifications need this phone's device token. Created once.
  Future<void> _ensureDevice() async {
    final detector = ref.read(drivingDetectorProvider);
    final st = await detector.status();
    if (!st.supported || st.configured || !ref.mounted) return;
    try {
      final token = await _backend.createDeviceToken();
      await detector.configure(
        url: BackendConfig.supabaseUrl,
        key: BackendConfig.supabaseAnonKey,
        token: token,
        texts: _nativeTexts(),
      );
    } on RealBackendException {
      // Try again next start.
    }
  }

  /// While I'm free: a small notification watches for friends, even when
  /// the app is closed (until my availability ends).
  Future<void> _watchWhileFree() async {
    final mine = myActiveAvailability(state, _now());
    if (mine == null || mine.auto) return;
    final detector = ref.read(drivingDetectorProvider);
    await _ensureDevice();
    await detector.requestNotificationPermission();
    await detector.startAvailable(mine.expiresAt);
  }

  Future<void> disableAutoDriving() async {
    // Detection off. The device token stays: it also brings "X is free"
    // notifications whenever I mark myself free.
    await ref.read(drivingDetectorProvider).disable();
    _notify(RealNoticeKind.autoDrivingOff);
    await _loadDriving();
    await refresh();
  }

  /// Paired Bluetooth devices, to pick the car.
  Future<List<(String, String)>> carCandidates() =>
      ref.read(drivingDetectorProvider).bondedDevices();

  /// The car's Bluetooth as an extra trip signal (turns automatic driving
  /// availability on if it was off).
  Future<void> setCar(String address, String name) async {
    if (!state.driving.enabled && address.isNotEmpty) {
      final ok = await enableAutoDriving();
      if (!ok) return;
    }
    await ref.read(drivingDetectorProvider).setCar(address, name);
    await _loadDriving();
    _notify(RealNoticeKind.saved);
  }

  /// Developer tools: pretend a trip started / ended.
  Future<void> simulateTrip({required bool enter}) =>
      ref.read(drivingDetectorProvider).simulate(enter: enter);

  /// "Talk now" on a driving notification → answer yes in the app.
  Future<void> _handleLaunchAction() async {
    if (state.phase != RealPhase.ready) return;
    final action = await ref.read(drivingDetectorProvider).takeLaunchAction();
    if (action == null || !ref.mounted) return;
    await refresh();
    if (!action.accept || !ref.mounted) return;
    final offer = state.snapshot?.offers
        .where((o) => o.id == action.offerId)
        .firstOrNull;
    if (offer != null &&
        offer.status == OfferStatus.pending &&
        _myAnswer(state, offer) == null) {
      await respond(offer, accept: true);
    }
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
      // Right away: friends who are already here, from my contacts.
      unawaited(syncContacts());
      unawaited(_ensureDevice());
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
    await ref.read(drivingDetectorProvider).forget();
    try {
      await _backend.revokeDeviceTokens();
    } on RealBackendException {
      // Signing out anyway.
    }
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
      // While I'm free, let the server create offers that became possible
      // (a pause ended, someone's circle changed) — at most every 15s.
      final now = _now();
      if (myActiveAvailability(state, now) != null &&
          (_lastNudge == null ||
              now.difference(_lastNudge!) > const Duration(seconds: 15))) {
        _lastNudge = now;
        try {
          await _backend.nudgeOffers();
        } on RealBackendException {
          // The fetch below reports connection problems.
        }
      }
      final snap = _withPhotos(await _backend.fetchSnapshot());
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
      unawaited(_loadPhotos(snap));
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

  // ------------------------------------------------------------ photos

  static String _photoKey(String id) => 'real.photo.$id';

  (int, Uint8List)? _cachedPhoto(String id) {
    final mem = _photos[id];
    if (mem != null) return mem;
    try {
      final raw = _store.getString(_photoKey(id));
      if (raw == null) return null;
      final i = raw.indexOf(':');
      final hit = (
        int.parse(raw.substring(0, i)),
        base64Decode(raw.substring(i + 1)),
      );
      _photos[id] = hit;
      return hit;
    } catch (_) {
      return null;
    }
  }

  void _keepPhoto(String id, int version, Uint8List? bytes) {
    if (bytes == null) {
      _photos.remove(id);
      _store.setString(_photoKey(id), null);
    } else {
      _photos[id] = (version, bytes);
      _store.setString(_photoKey(id), '$version:${base64Encode(bytes)}');
    }
  }

  /// Fill in every photo we already have at the right version.
  RealSnapshot _withPhotos(RealSnapshot snap) {
    final have = <String, Uint8List>{};
    for (final p in [snap.me, ...snap.friends]) {
      if (p.photoVersion <= 0) continue;
      final c = _cachedPhoto(p.id);
      if (c != null && c.$1 == p.photoVersion) have[p.id] = c.$2;
    }
    return have.isEmpty ? snap : snap.withPhotos(have);
  }

  /// Download new or changed photos in the background, then show them.
  Future<void> _loadPhotos(RealSnapshot snap) async {
    var got = false;
    for (final p in [snap.me, ...snap.friends]) {
      if (p.photoVersion <= 0) {
        if (_photos.containsKey(p.id) ||
            _store.getString(_photoKey(p.id)) != null) {
          _keepPhoto(p.id, 0, null);
        }
        continue;
      }
      if (p.photo != null || _photoLoading.contains(p.id)) continue;
      _photoLoading.add(p.id);
      try {
        final bytes = await _backend.downloadPhoto(p.id);
        if (bytes != null && bytes.isNotEmpty) {
          _keepPhoto(p.id, p.photoVersion, bytes);
          got = true;
        }
      } finally {
        _photoLoading.remove(p.id);
      }
      if (!ref.mounted) return;
    }
    final current = state.snapshot;
    if (got && current != null && ref.mounted) {
      state = state.copyWith(snapshot: _withPhotos(current));
    }
  }

  /// My profile photo (already shrunk to a small JPEG); null removes it.
  /// Returns an error code, or null when it worked.
  Future<String?> setPhoto(Uint8List? jpeg) async {
    try {
      await _backend.setPhoto(jpeg);
    } on RealBackendException catch (e) {
      return e.code;
    }
    final me = _backend.userId;
    if (me != null) {
      final snap = await _backend.fetchSnapshot().then<RealSnapshot?>(
        (s) => s,
        onError: (Object _) => null,
      );
      if (!ref.mounted) return null;
      if (snap != null) {
        _keepPhoto(me, snap.me.photoVersion, jpeg);
        state = state.copyWith(snapshot: _withPhotos(snap));
      }
    }
    return null;
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

  Future<bool> startAvailability(
    AvailabilityMode mode,
    int minutes, {
    String? circleId,
  }) async {
    final ok = await _run(
      () => _backend.setAvailability(
        mode,
        minutes.clamp(1, 180),
        circleId: circleId,
      ),
    );
    _lastNudge = null;
    await refresh();
    if (ok && ref.mounted) unawaited(_watchWhileFree());
    return ok;
  }

  Future<void> stopAvailability() async {
    _stopVoice();
    // Also end the trip-bound background service, if one is running.
    if (state.driving.inVehicle) {
      await ref.read(drivingDetectorProvider).simulate(enter: false);
    }
    await ref.read(drivingDetectorProvider).stopAvailable();
    await _run(_backend.clearAvailability);
    unawaited(_loadDriving());
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
      quick: offer.quick,
    );
    // Quick connect: everyone gets 5 seconds to cancel. A normal match:
    // only the side that dials gets 3 seconds.
    final countdown = offer.quick ? 5 : (role == CallRole.iCall ? 3 : 0);
    state = state.copyWith(call: call, dialCountdown: countdown);
    if (countdown == 0) {
      _proceed();
      return;
    }
    if (_driving(_now()) || offer.quick) {
      _speak(
        offer.quick
            ? _l.realVoiceQuick(other.name)
            : _l.realVoiceCalling(other.name),
      );
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
        _proceed();
      }
    });
  }

  /// After the countdown: dial, wait for their call, or the in-app call.
  void _proceed() {
    final call = state.call;
    if (call == null || state.callStage != CallStage.connecting) return;
    switch (call.role) {
      case CallRole.iCall:
        unawaited(_dial());
      case CallRole.theyCall:
        state = state.copyWith(callStage: CallStage.waitingForTheirCall);
        if (_driving(_now())) {
          _speak(
            _l.realVoiceTheyCall(
              call.other.name,
              _genderKey(call.other.gender),
            ),
          );
        }
      case CallRole.inApp:
        state = state.copyWith(callStage: CallStage.inApp);
    }
  }

  /// "Call now" without waiting for the countdown.
  Future<void> dialNow() async {
    _dialTimer?.cancel();
    state = state.copyWith(dialCountdown: 0);
    _proceed();
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

  // ------------------------------------------------------------ routines

  static const _routinesKey = 'real.routines.v1';

  List<Routine> _loadRoutines() {
    try {
      final raw = _store.getString(_routinesKey);
      if (raw == null) return const [];
      return [
        for (final r in jsonDecode(raw) as List)
          Routine.fromJson((r as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Save routines here and hand them to the phone's alarm.
  Future<void> saveRoutines(List<Routine> list) async {
    state = state.copyWith(routines: list);
    await _store.setString(
      _routinesKey,
      jsonEncode([for (final r in list) r.toJson()]),
    );
    await _ensureDevice();
    await ref
        .read(drivingDetectorProvider)
        .setRoutines(
          jsonEncode([
            for (final r in list)
              {
                'id': r.id,
                'days': r.weekdays.toList(),
                'hour': r.minuteOfDay ~/ 60,
                'minute': r.minuteOfDay % 60,
                'mode': r.mode.name,
                'minutes': r.durationMinutes,
                'enabled': true,
              },
          ]),
        );
    _notify(RealNoticeKind.saved);
  }

  /// A routine whose time is now, while I'm not free yet.
  Routine? dueRoutine(DateTime now) {
    if (myActiveAvailability(state, now) != null) return null;
    for (final r in state.routines) {
      final minutes = now.hour * 60 + now.minute;
      if (r.weekdays.contains(now.weekday) &&
          minutes >= r.minuteOfDay &&
          minutes - r.minuteOfDay <= 20) {
        return r;
      }
    }
    return null;
  }

  // ------------------------------------------------------------ contacts

  static const _contactsSyncKey = 'real.contactsSyncedAt';

  /// Friends from the phone's contacts: whoever has my number and whose
  /// number I have becomes a friend automatically (owner decision D-047).
  /// Only hashes of numbers leave the phone; names never do.
  Future<void> syncContacts({bool ask = true}) async {
    final reader = ref.read(contactsReaderProvider);
    final allowed = ask
        ? await reader.requestPermission()
        : await reader.hasPermission();
    if (!ref.mounted) return;
    if (!allowed) {
      if (ask) _notify(RealNoticeKind.contactsNoPermission);
      return;
    }
    final numbers = await reader.phoneNumbers();
    if (!ref.mounted) return;
    final hashes = {for (final n in numbers) ?hashPhone(n)}.toList();
    await _run(() async {
      final names = await _backend.syncContacts(hashes);
      if (!ref.mounted) return;
      _store.setString(_contactsSyncKey, _now().toIso8601String());
      if (names.isNotEmpty) {
        _notify(RealNoticeKind.contactsFound, name: names.join(', '));
      } else if (ask) {
        _notify(RealNoticeKind.contactsNone);
      }
    });
    if (ref.mounted) await refresh();
  }

  /// Quietly again every 12 hours (only if permission was given before).
  Future<void> _maybeSyncContacts() async {
    final last = DateTime.tryParse(_store.getString(_contactsSyncKey) ?? '');
    if (last != null && _now().difference(last) < const Duration(hours: 12)) {
      return;
    }
    await syncContacts(ask: false);
  }

  Future<List<RealProfile>> blockedPeople() async {
    try {
      return await _backend.blockedPeople();
    } on RealBackendException catch (e) {
      _setError(e.code, show: true);
      return const [];
    }
  }

  Future<void> unblock(RealProfile p) async {
    await _run(() async {
      final back = await _backend.unblock(p.id);
      _notify(
        back ? RealNoticeKind.unblockedReconnected : RealNoticeKind.unblocked,
        name: p.name,
        gender: p.gender,
      );
    });
    await refresh();
  }

  Future<bool> saveCircle(RealCircle circle) async {
    final ok = await _run(() async {
      await _backend.saveCircle(circle);
      _notify(RealNoticeKind.saved);
    });
    await refresh();
    return ok;
  }

  Future<void> deleteCircle(RealCircle circle) async {
    await _run(() => _backend.deleteCircle(circle.id));
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
      'auto driving: ${s.driving.enabled ? 'on' : 'off'}'
          '${s.driving.supported ? '' : ' (unsupported)'}'
          '${s.driving.permission ? '' : ' (no permission)'}'
          '${s.driving.inVehicle ? ', in vehicle' : ''}',
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
