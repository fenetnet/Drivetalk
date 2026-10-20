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
import 'photo_cache.dart';
import 'real_backend.dart';
import 'real_models.dart';
import 'routine_suggest.dart';
import 'supabase_backend.dart';
import 'update_checker.dart';

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

/// Friends' photos on this phone (cache folder, not backed up).
final photoCacheProvider = Provider<PhotoCache>((ref) => FilePhotoCache());

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

/// This build's number (CI run number); null when unknown (e.g. tests).
final appBuildProvider = Provider<int?>((ref) => null);

/// The phone's time zone name (for quiet hours on the server).
final timeZoneProvider = Provider<String?>((ref) => null);

/// "Is there a newer version?" (version.json next to the APK).
final updateCheckerProvider = Provider<UpdateChecker>(
  // Google Play build: ask Google Play; the test APK: the GitHub release.
  (ref) => BackendConfig.store ? PlayUpdateChecker() : HttpUpdateChecker(),
);

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

/// After joining: find people from contacts → result → how it works.
enum FirstRunStep { photo, contacts, result, routine, permissions, magic }

/// The phone permissions asked for at the start (and in Settings).
enum PhonePermission { notifications, calls, mic, background }

class PhonePermissions {
  const PhonePermissions({
    required this.supported,
    required this.notifications,
    required this.calls,
    required this.mic,
    required this.background,
    required this.autoDriving,
  });

  /// Android (background notifications etc.); elsewhere only calls + mic.
  final bool supported;
  final bool notifications;
  final bool calls;
  final bool mic;
  final bool background;
  final bool autoDriving;

  bool has(PhonePermission p) => switch (p) {
    PhonePermission.notifications => !supported || notifications,
    PhonePermission.calls => calls,
    PhonePermission.mic => mic,
    PhonePermission.background => !supported || background,
  };
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
    this.dialFailed = false,
  });

  /// The phone's dialer couldn't be opened (call them by hand).
  final bool dialFailed;

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
  noAnswer,
  later,
  quickCancelled,
  quickTooLate,
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

  /// Tapping a free friend didn't ask them ([RealNotice.code] says why).
  askFailed,
  friendKept,
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
    this.notice,
    this.prefs = const RealPrefs(),
    this.myPhone,
    this.localAnswers = const {},
    this.dismissedOffers = const {},
    this.listening = false,
    this.driving = const DrivingStatus(),
    this.routines = const [],
    this.directCall,
    this.firstRun,
    this.serverSchema,
    this.newBuild,
    this.admin = false,
    this.normalViewFor,
    this.callHiddenFor,
  });

  /// I left the call screen for the main one during this call (its offer
  /// id); a banner brings it back. Another call shows its screen again.
  final String? callHiddenFor;

  /// The call screen is set aside for now.
  bool get callHidden => call != null && callHiddenFor == call!.offerId;

  /// While driving, I chose the regular screen for this trip (its start
  /// time). A new trip shows the driver screen again.
  final DateTime? normalViewFor;

  /// My routines ("every weekday at 8:00, driving").
  final List<Routine> routines;

  /// May calls start without an extra tap (asked ahead)? null = unknown.
  final bool? directCall;

  /// First steps after joining (until a first friend + how it works).
  final FirstRunStep? firstRun;

  /// The server's version (null = not checked yet). Below
  /// [kRequiredSchema]: the server needs an update — said clearly.
  final int? serverSchema;

  /// A newer version of the app is out (its build number).
  final int? newBuild;

  /// The owner's tools are open on this phone (test tab, demo, links…).
  final bool admin;

  bool get serverOutdated =>
      serverSchema != null && serverSchema! < kRequiredSchema;

  final RealPhase phase;
  final RealSnapshot? snapshot;
  final LiveStatus live;
  final bool busy;
  final String? lastError;
  final DateTime? lastErrorAt;
  final PendingInvite? invite;
  final CallStage callStage;
  final RealCall? call;
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
    Object? notice = _keep,
    RealPrefs? prefs,
    Object? myPhone = _keep,
    Map<String, bool>? localAnswers,
    Set<String>? dismissedOffers,
    bool? listening,
    DrivingStatus? driving,
    List<Routine>? routines,
    bool? directCall,
    Object? firstRun = _keep,
    int? serverSchema,
    int? newBuild,
    bool? admin,
    Object? normalViewFor = _keep,
    Object? callHiddenFor = _keep,
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
    notice: identical(notice, _keep) ? this.notice : notice as RealNotice?,
    prefs: prefs ?? this.prefs,
    myPhone: identical(myPhone, _keep) ? this.myPhone : myPhone as String?,
    localAnswers: localAnswers ?? this.localAnswers,
    dismissedOffers: dismissedOffers ?? this.dismissedOffers,
    listening: listening ?? this.listening,
    driving: driving ?? this.driving,
    routines: routines ?? this.routines,
    directCall: directCall ?? this.directCall,
    serverSchema: serverSchema ?? this.serverSchema,
    newBuild: newBuild ?? this.newBuild,
    admin: admin ?? this.admin,
    normalViewFor: identical(normalViewFor, _keep)
        ? this.normalViewFor
        : normalViewFor as DateTime?,
    callHiddenFor: identical(callHiddenFor, _keep)
        ? this.callHiddenFor
        : callHiddenFor as String?,
    firstRun: identical(firstRun, _keep)
        ? this.firstRun
        : firstRun as FirstRunStep?,
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
      if (snap.availability[f.id] case final a?
          when a.isActiveAt(now) && !a.inCallAt(now))
        (f, a),
  ]..sort((x, y) => y.$2.expiresAt.compareTo(x.$2.expiresAt));
}

/// Free friends I can really ask now (D-107): not those who'd refuse
/// anyway (rated me "never", said no this time, busy, quiet minutes…).
List<(RealProfile, RealAvailability)> askableFriends(
  RealState s,
  DateTime now,
) {
  final can = s.snapshot?.askable;
  return [
    for (final f in freeFriends(s, now))
      if (can == null || can.contains(f.$1.id)) f,
  ];
}

/// Friends who marked themselves free but are in a call right now.
List<(RealProfile, RealAvailability)> busyFriends(RealState s, DateTime now) {
  final snap = s.snapshot;
  if (snap == null) return const [];
  return [
    for (final f in snap.friends)
      if (snap.availability[f.id] case final a?
          when a.isActiveAt(now) && a.inCallAt(now))
        (f, a),
  ];
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

/// The big driver screen — unless I chose the regular one for this trip.
bool showDriverScreen(RealState s, DateTime now) {
  final mine = myActiveAvailability(s, now);
  return mine?.mode == AvailabilityMode.driving &&
      s.normalViewFor != mine!.startedAt;
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

final realProvider = NotifierProvider<RealController, RealState>(
  RealController.new,
);

const _prefsKey = 'real.prefs.v1';

/// The server version this app needs (supabase/migrations, schema_version()).
const kRequiredSchema = 50;
const _firstRunKey = 'real.firstRun.v1';
const _adminKey = 'real.admin.v1';

/// SHA-256 of "drivetalk-admin:<code>" — the code itself is not in the app.
/// It only hides the owner's tools from friends; it protects no data.
const _handledKey = 'real.handledOffers.v1';

class RealController extends Notifier<RealState> {
  late RealBackend _backend;
  late LocalStore _store;
  late PhotoCache _photoCache;
  late DateTime Function() _now;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _debounce;
  Timer? _ticker;
  Timer? _fastTicker;
  AppLifecycleListener? _lifecycle;
  var _noticeSeq = 0;
  var _voiceSeq = 0;
  var _tick = 0;
  DateTime? _expiryRefreshed;
  var _refreshing = false;
  DateTime? _refreshStarted;

  /// A refresh asked for while one runs: done when the NEXT one finishes
  /// (so "save, then refresh" always shows the saved data).
  Completer<void>? _refreshAgain;
  String? _spokenOfferId;
  String? _shownOfferId;
  DateTime? _lastNudge;

  /// When I started waiting for the other side's answer (per offer).
  final _waitingSince = <String, DateTime>{};
  final _givingUp = <String>{};

  /// Offers whose answer from this phone is on its way: the refresh must not
  /// act on them too (e.g. start the same call twice).
  final _answering = <String>{};

  /// A quick-connect cancel on its way (the countdown poll waits for it).
  String? _cancellingQuick;
  String? _quickTooLate;

  /// The app is on screen (not just running behind another app, which it
  /// does while the availability notification is up).
  var _foreground = true;

  /// When "both said yes" reached this phone (to measure the time to dial).
  DateTime? _bothYesAt;
  var _hadFriends = true;

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
    _photoCache = ref.watch(photoCacheProvider);
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
        admin: _store.getString(_adminKey) == 'on',
        phase: RealPhase.notConfigured,
        prefs: prefs,
        routines: routines,
      );
    }
    Future.microtask(_start);
    return RealState(
      admin: _store.getString(_adminKey) == 'on',
      phase: RealPhase.starting,
      prefs: prefs,
      routines: routines,
      firstRun: FirstRunStep.values
          .asNameMap()[_store.getString(_firstRunKey) ?? ''],
    );
  }

  void _dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _debounce?.cancel();
    _ticker?.cancel();
    _fastTicker?.cancel();
    _lifecycle?.dispose();
  }

  Future<void> _start() async {
    // Photos saved on the phone: in the background, never delaying startup.
    unawaited(
      _photoCache.loadAll().then((saved) {
        if (!ref.mounted || saved.isEmpty) return;
        for (final e in saved.entries) {
          _photos.putIfAbsent(e.key, () => e.value);
        }
        final snap = state.snapshot;
        if (snap != null) state = state.copyWith(snapshot: _withPhotos(snap));
      }, onError: (Object _) {}),
    );
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
    // Waiting for an answer: look every 2 seconds, so each step shows at
    // once even when instant updates are down (D-129).
    _fastTicker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_foreground && !_refreshing && waitingOffer(state, _now()) != null) {
        refresh();
      }
    });
    try {
      _lifecycle = AppLifecycleListener(
        onResume: _onResume,
        onStateChange: _onLifecycle,
      );
      unawaited(checkForUpdate());
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
    unawaited(_backend.touchSeen());
    unawaited(flushCrashes());
    if (state.serverSchema == null) unawaited(_checkSchema());
    unawaited(_loadPhone());
    unawaited(_loadDriving());
    unawaited(_handleLaunchAction());
    unawaited(_maybeSyncContacts());
    unawaited(_ensureDevice());
    unawaited(_ensurePushToken());
    unawaited(_ensurePresets(thenRefresh: true));
    _openPendingInvite();
  }

  void _onTick() {
    if (state.phase != RealPhase.ready) return;
    _tick++;
    if (_foreground) unawaited(checkForUpdate());
    final now = _now();
    final mine = state.snapshot?.mine;
    // My time just ran out: refresh once for it (the server removes the
    // row within a minute; no need to ask every 5 seconds until then).
    final myExpired =
        mine != null &&
        !mine.isActiveAt(now) &&
        _expiryRefreshed != mine.expiresAt;
    if (myExpired) _expiryRefreshed = mine.expiresAt;
    final busy =
        myActiveAvailability(state, now) != null ||
        waitingOffer(state, now) != null;
    final every = busy || state.live != LiveStatus.connected ? 2 : 6;
    if (myExpired || _tick % every == 0) refresh();
    // Instant updates stopped: try again (at most once a minute).
    if (state.live == LiveStatus.error && _foreground) _reconnectLive();
    checkWaiting();
    // A call screen left open (the call was taken on the phone and the
    // screen forgotten): once I'm back in the app 20 minutes after it
    // started, it moves on to "when again?", so new questions can show
    // again. Never while the app is behind the phone call itself.
    final call = state.call;
    if (call != null &&
        _foreground &&
        const {
          CallStage.waitingForTheirCall,
          CallStage.dialed,
        }.contains(state.callStage) &&
        now.difference(call.startedAt) > const Duration(minutes: 20)) {
      finishCall();
    }
  }

  /// Tests: one tick of the 5-second timer.
  @visibleForTesting
  void debugTick() => _onTick();

  /// How long I wait for the other side after my "yes" before giving up.
  static const waitLimit = Duration(seconds: 25);

  /// A quick connect whose countdown ended this long ago without a call
  /// doesn't start any more (same as the server).
  static const _quickStale = Duration(minutes: 2);

  /// Seconds left before I stop waiting for [offer] (the waiting screen's
  /// countdown); null when not known.
  int? waitSecondsLeft(RealOffer offer, DateTime now) {
    final since = _waitingSince[offer.id];
    if (since == null) return null;
    final left = waitLimit - now.difference(since);
    return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  }

  /// Runs every 5 seconds (public for tests).
  @visibleForTesting
  void checkWaiting() {
    final now = _now();
    final w = waitingOffer(state, now);
    if (w == null || _handled.contains(w.id) || _givingUp.contains(w.id)) {
      return;
    }
    final since = _waitingSince.putIfAbsent(w.id, () => now);
    if (now.difference(since) >= waitLimit) unawaited(_giveUpWaiting(w));
  }

  /// No answer in time: withdraw my "yes" (the other side's question
  /// disappears too) and say so gently.
  Future<void> _giveUpWaiting(RealOffer offer) async {
    if (!_givingUp.add(offer.id)) return;
    try {
      final answer = await _backend.answerOffer(offer.id, accept: false);
      if (!ref.mounted) return;
      // They said yes at the same moment: the call goes on as usual.
      if (answer.status == OfferStatus.accepted) return;
      _dropLocalAnswer(offer.id);
      if (answer.status == OfferStatus.declined) {
        // Maybe they pressed "I'll get back to you": then that is what I
        // hear (the refresh after this shows it), not "no answer".
        await refresh();
        if (!ref.mounted) return;
        final o = state.snapshot?.offers
            .where((x) => x.id == offer.id)
            .firstOrNull;
        if (o?.laterFrom != null && o!.laterFrom != state.myId) return;
      }
      _markHandled(offer.id);
      _event('wait_timeout');
      _notify(RealNoticeKind.noAnswer);
      if (_driving(_now())) _speak(_l.realNoAnswer);
    } on RealBackendException catch (e) {
      _setError(e.code);
    } finally {
      // Kept until here, so the next 5-second check can't give up twice.
      try {
        if (ref.mounted) await refresh();
      } finally {
        _givingUp.remove(offer.id);
      }
    }
  }

  void _dropLocalAnswer(String id) {
    if (!state.localAnswers.containsKey(id)) return;
    state = state.copyWith(localAnswers: {...state.localAnswers}..remove(id));
  }

  void _onLifecycle(AppLifecycleState s) {
    _foreground =
        s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;
    // Behind another app or locked: no hidden question and no open
    // microphone — the notification takes over there (D-111).
    if (!_foreground && _voiceAsking && ref.mounted) _stopVoice();
  }

  /// Tests: the app goes behind another app / comes back.
  @visibleForTesting
  void debugLifecycle(AppLifecycleState s) {
    _onLifecycle(s);
    if (s == AppLifecycleState.resumed) _onResume();
  }

  DateTime? _lastReconnect;

  void _reconnectLive() {
    final now = DateTime.now();
    if (_lastReconnect != null &&
        now.difference(_lastReconnect!) < const Duration(minutes: 1)) {
      return;
    }
    _lastReconnect = now;
    unawaited(_quietly(_backend.reconnectLive));
  }

  void _onResume() {
    unawaited(checkForUpdate());
    if (state.phase != RealPhase.ready) return;
    // Back from the phone call → ask how it went (and I'm free again).
    if (state.callStage == CallStage.dialed) {
      state = state.copyWith(callStage: CallStage.feedback);
      final id = state.call?.offerId;
      if (id != null) unawaited(_quietly(() => _backend.endCall(id)));
    }
    if (state.myPhone == null) unawaited(_loadPhone());
    unawaited(_refreshAndRewatch());
    unawaited(_backend.touchSeen());
    unawaited(_handleLaunchAction());
    unawaited(_ensurePushToken());
    // New people from my contacts (at most twice a day).
    unawaited(_maybeSyncContacts());
  }

  // ------------------------------------------------------------ auto driving

  Future<void> _checkSchema() async {
    try {
      final v = await _backend.schemaVersion();
      if (ref.mounted) state = state.copyWith(serverSchema: v);
    } on RealBackendException {
      // Checked again on the next refresh.
    }
  }

  /// "Delete what was synced from my contacts" (connections stay).
  Future<void> clearContacts() async {
    await _run(() async {
      await _backend.clearContactHashes();
      await _store.setString(_contactsSyncKey, null);
      await _store.setString(_localNamesKey, null);
      // Don't upload them again by itself (a manual search turns it back on).
      await _store.setString(_contactsOffKey, 'on');
      _notify(RealNoticeKind.saved);
    });
  }

  // ------------------------------------------------------------ routine hint

  static const _freeLogKey = 'real.freeLog.v1';
  static const _hintNoKey = 'real.routineHintNo.v1';

  List<(DateTime, AvailabilityMode)> _freeLog() {
    try {
      final raw = _store.getString(_freeLogKey);
      if (raw == null) return [];
      return [
        for (final e in jsonDecode(raw) as List)
          (
            DateTime.parse((e as List)[0] as String),
            AvailabilityMode.values.byName(e[1] as String),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Only on this phone: when I marked myself free (for a routine hint).
  void _logFree(AvailabilityMode mode) {
    final now = _now();
    final keep = [
      for (final e in _freeLog())
        if (now.difference(e.$1) < const Duration(days: 35)) e,
      (now, mode),
    ];
    _store.setString(
      _freeLogKey,
      jsonEncode([
        for (final e in keep) [e.$1.toIso8601String(), e.$2.name],
      ]),
    );
  }

  Set<String> _hintNo() {
    try {
      return {
        ...(jsonDecode(_store.getString(_hintNoKey) ?? '[]') as List)
            .cast<String>(),
      };
    } catch (_) {
      return {};
    }
  }

  /// "Usually free on Sundays around 17:30 — make it a routine?"
  RoutineSuggestion? routineSuggestion(DateTime now) => suggestRoutine(
    log: _freeLog(),
    routines: state.routines,
    dismissed: _hintNo(),
    now: now,
  );

  Future<void> acceptRoutineSuggestion(RoutineSuggestion r) async {
    await saveRoutines([
      ...state.routines,
      Routine(
        id: _now().microsecondsSinceEpoch.toString(),
        weekdays: {r.weekday},
        minuteOfDay: r.minuteOfDay,
        durationMinutes: 30,
        mode: r.mode,
      ),
    ]);
  }

  void dismissRoutineSuggestion(RoutineSuggestion r) {
    _store.setString(_hintNoKey, jsonEncode([..._hintNo(), r.key]));
    state = state.copyWith();
  }

  // ------------------------------------------------------------ app update

  DateTime? _lastUpdateCheck;

  /// Is a newer version published? At start, on return and while the app
  /// is open — every 30 minutes until one is found (Google Play often
  /// learns about a new version a while after the app started).
  Future<void> checkForUpdate({bool force = false}) async {
    final mine = ref.read(appBuildProvider);
    if (mine == null) return;
    if (!force && state.newBuild != null) return;
    final now = _now();
    if (!force &&
        _lastUpdateCheck != null &&
        now.difference(_lastUpdateCheck!) < const Duration(minutes: 30)) {
      return;
    }
    _lastUpdateCheck = now;
    final latest = await ref.read(updateCheckerProvider).latestBuild();
    if (!ref.mounted || latest == null) return;
    if (latest > mine) state = state.copyWith(newBuild: latest);
  }

  // ------------------------------------------------------------ admin

  /// The owner's code opens the test tab and the other tools on this phone.
  /// The owner's code — checked only by the server (the app holds no copy
  /// of it, D-093). True = this account is the owner.
  Future<bool> unlockAdmin(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    bool ok;
    try {
      ok = await _backend.claimOwner(trimmed);
    } on RealBackendException catch (e) {
      _setError(e.code, show: true);
      return false;
    }
    if (!ok || !ref.mounted) return false;
    _store.setString(_adminKey, 'on');
    state = state.copyWith(admin: true);
    return true;
  }

  void lockAdmin() {
    _store.setString(_adminKey, null);
    state = state.copyWith(admin: false);
  }

  // ------------------------------------------------------------ first run

  /// "Let's see who of your people is already here" → contacts.
  Future<void> firstRunFindPeople() async {
    await syncContacts(quiet: true);
    markMatchesSeen();
    _setFirstRun(FirstRunStep.result);
  }

  void firstRunNext() {
    // Past the permissions step: no "before we start…" note again later.
    if (state.firstRun == FirstRunStep.permissions) markPermissionIntroShown();
    _firstRunAdvance();
  }

  void _firstRunAdvance() => _setFirstRun(switch (state.firstRun) {
    FirstRunStep.photo => FirstRunStep.contacts,
    FirstRunStep.contacts => FirstRunStep.result,
    FirstRunStep.result => FirstRunStep.routine,
    FirstRunStep.routine => FirstRunStep.permissions,
    FirstRunStep.permissions => FirstRunStep.magic,
    _ => null,
  });

  /// First steps: "when are you usually on the road?" → routines Sun–Thu
  /// (availability turns on by itself then; editable in settings).
  /// [morning] / [evening]: minute of the day, or null = not picked.
  Future<void> firstRunRoutines({int? morning, int? evening}) async {
    final workdays = {7, 1, 2, 3, 4}; // Sun–Thu
    final now = _now().microsecondsSinceEpoch;
    final picked = [
      if (morning != null)
        Routine(
          id: 'r$now-m',
          name: _l.routineNameToWork,
          weekdays: workdays,
          minuteOfDay: morning,
          durationMinutes: 30,
          mode: AvailabilityMode.driving,
        ),
      if (evening != null)
        Routine(
          id: 'r$now-e',
          name: _l.routineNameHome,
          weekdays: workdays,
          minuteOfDay: evening,
          durationMinutes: 30,
          mode: AvailabilityMode.driving,
        ),
    ];
    if (picked.isNotEmpty) {
      await saveRoutines([...state.routines, ...picked]);
      _event('onboarding_routine');
    }
    firstRunNext();
  }

  void _setFirstRun(FirstRunStep? step) {
    if (!ref.mounted) return;
    if (step == null && state.firstRun != null) _event('onboarding_completed');
    _store.setString(_firstRunKey, step?.name);
    state = state.copyWith(firstRun: step);
  }

  // ------------------------------------------------------------ talk intent

  /// "I'd like to talk with them" — quietly; they are never told. When both
  /// are free later, they are offered first.
  Future<void> setTalkIntent(RealProfile friend, TalkIntentSpan span) async {
    final now = _now();
    final until = switch (span) {
      TalkIntentSpan.today => DateTime(now.year, now.month, now.day + 1),
      TalkIntentSpan.week => now.add(const Duration(days: 7)),
      TalkIntentSpan.always => null,
    };
    await _run(() => _backend.setTalkIntent(friend.id, until));
    _event('talk_intent_created');
    await refresh();
  }

  Future<void> clearTalkIntent(RealProfile friend) async {
    await _run(() => _backend.clearTalkIntent(friend.id));
    await refresh();
  }

  // ------------------------------------------------------------ direct call

  Future<void> _loadDirectCall() async {
    final ok = await ref.read(phoneDialerProvider).canCallDirectly();
    if (ref.mounted) state = state.copyWith(directCall: ok);
  }

  /// What the phone already allows (asks nothing).
  Future<PhonePermissions> phonePermissions() async {
    await _loadDriving();
    final mic = await ref.read(voiceServiceProvider).micAllowed();
    final d = state.driving;
    return PhonePermissions(
      supported: d.supported,
      notifications: d.notifications,
      calls: state.directCall == true,
      mic: mic,
      background: d.background,
      autoDriving: d.enabled,
    );
  }

  /// One permission now (a calm moment, never in the middle of a drive).
  Future<void> askPermission(PhonePermission p) async {
    final detector = ref.read(drivingDetectorProvider);
    switch (p) {
      case PhonePermission.notifications:
        await detector.requestNotificationPermission();
      case PhonePermission.calls:
        await askDirectCall();
      case PhonePermission.mic:
        await ref.read(voiceServiceProvider).prepare();
      case PhonePermission.background:
        await allowBackground();
    }
    await _loadDriving();
  }

  /// "Allow all": the ones still missing, one after the other.
  Future<void> askAllPermissions() async {
    final now = await phonePermissions();
    for (final p in PhonePermission.values) {
      if (!now.has(p)) await askPermission(p);
    }
  }

  /// Ask for direct calls now (a calm moment), so later a call starts at once.
  Future<bool> askDirectCall() async {
    final ok = await ref.read(phoneDialerProvider).requestDirectCall();
    if (!ref.mounted) return ok;
    state = state.copyWith(directCall: ok);
    return ok;
  }

  /// Calls always start at once when both said yes (owner decision D-075).
  /// Until Android's "phone calls" permission is given, "I'm free" asks
  /// for it (before any offer shows up); Android itself stops asking after
  /// the user declined twice — then the dialer opens with the number.
  Future<void> _maybeAskDirectCall() async {
    // Right after joining it isn't known yet.
    if (state.directCall == null) await _loadDirectCall();
    if (!ref.mounted || state.directCall != false) return;
    await askDirectCall();
  }

  static const _widgetTipKey = 'real.widgetTip.v1';

  /// Once: the home-screen button / quick tile exist (Android).
  bool get showWidgetTip =>
      state.driving.supported && _store.getString(_widgetTipKey) == null;

  void dismissWidgetTip() {
    _store.setString(_widgetTipKey, 'seen');
    state = state.copyWith();
  }

  static const _bgTipKey = 'real.backgroundTip.v1';
  static const _usedFreeKey = 'real.usedFree.v1';
  static const _micTipKey = 'real.micTip.v1';

  /// Battery saving may stop the background service: ask once, but only
  /// people who use it (auto driving, routines, or "I'm free" before).
  bool get showBackgroundTip =>
      state.driving.supported &&
      !state.driving.background &&
      _store.getString(_bgTipKey) == null &&
      (state.driving.enabled ||
          state.routines.isNotEmpty ||
          _store.getString(_usedFreeKey) != null);

  /// Settings → "Notifications": the phone's own switch (re-read on return).
  Future<void> openNotificationSettings() =>
      ref.read(drivingDetectorProvider).openNotificationSettings();

  Future<void> allowBackground() async {
    await ref.read(drivingDetectorProvider).allowBackground();
    // The answer is read again when the app comes back (on resume).
  }

  void dismissBackgroundTip() {
    _store.setString(_bgTipKey, 'dismissed');
    state = state.copyWith();
  }

  /// Contacts were searched before (then "My people" shows a small button).
  bool get contactsSynced => _store.getString(_contactsSyncKey) != null;

  Future<void> _loadDriving() async {
    unawaited(_loadDirectCall());
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
    });
    // Voice answers on the road: the microphone question comes now.
    if (ok && state.prefs.voice) await ref.read(voiceServiceProvider).prepare();
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
    'channelTalk': _l.realNotifChannelTalk,
    // "X is on the way" (D-119).
    'channelTrip': _l.tripNotifChannel,
    'tripTitle': _l.tripNotifTitle('{name}'),
    'tripBody': _l.tripNotifBody,
    'tripTalk': _l.tripNotifTalk,
    'pushTestTitle': _l.pushTestTitle,
    // News (D-120): a new version, notes for the owners.
    'channelNews': _l.notifChannelNews,
    'ownerFeedback': _l.ownerNotifFeedback,
    'ownerCrash': _l.ownerNotifCrash,
    'ownerUser': _l.ownerNotifUser('{name}'),
    'versionTitle': _l.versionNotifTitle,
    'versionBody': _l.versionNotifBody,
    // "X tried to reach you" (D-121), by their gender.
    'missedTitleF': _l.missedNotifTitle('{name}', 'female'),
    'missedTitleM': _l.missedNotifTitle('{name}', 'male'),
    'missedTitleO': _l.missedNotifTitle('{name}', 'other'),
    'missedBody': _l.missedNotifBody,
    'statusTitle': _l.realNotifStatusTitle,
    'statusBody': _l.realNotifStatusBody,
    'stop': _l.driverStop,
    'offerTitle': _l.realOfferTitle('{name}', 'other'),
    'directTitle': _l.directTitle('{name}'),
    'voiceDirect': _l.voiceDirect('{name}'),
    'offerBody': _l.realOfferNote,
    'talk': _l.realTalkNow,
    'notNow': _l.realNotNow,
    'voiceOffer': _l.realVoiceOffer('{name}', 'other'),
    'quickTitle': _l.realQuickConnecting('{name}'),
    'quickBody': _l.realQuickConnectingBody,
    'cancel': _l.cancel,
    'publicOffer': _l.realNotifPublic,
    'bgFailedTitle': _l.realBgFailedTitle,
    'bgFailedBody': _l.realBgFailedBody,
    'voiceQuick': _l.realVoiceQuick('{name}'),
    'manualTitle': _l.realNotifManualTitle,
    'quickOff': _l.realQuickOff,
    'quickOn': _l.realQuickOn,
    'tileLabel': 'DriveBond',
    'routineTitle': _l.realRoutineNotifTitle,
    'routineBody': _l.realRoutineNotifBody,
    // The routine asks first when Android won't start the watcher by itself.
    'routineAskTitle': _l.routineAskTitle,
    'routineAskBody': _l.routineAskBody('{minutes}'),
    'routineAskYes': _l.routineAskYes,
    'manualBody': _l.realNotifManualBody,
    // Background: "yes" can't be heard there — say how to answer (D-111).
    'bgVoiceOffer': _l.bgVoiceOffer('{name}'),
    'bgVoiceDirect': _l.bgVoiceDirect('{name}'),
    'publicOfferTalk': _l.notifPublicTalk,
    'answeredTheyCall': _l.answeredTheyCall('{name}'),
    'answeredYouCall': _l.answeredYouCall('{name}'),
    'answeredWaiting': _l.answeredWaiting('{name}'),
    'answeredMissed': _l.answeredMissed,
    'answeredRetry': _l.answeredRetry,
    'voiceYouCall': _l.voiceYouCall('{name}'),
  };

  /// Background notifications need this phone's device token. Created once.
  Future<void> _ensureDevice() => _ensuringDevice ??= _ensureDeviceOnce()
      .whenComplete(() => _ensuringDevice = null);
  Future<void>? _ensuringDevice;

  Future<void> _ensureDeviceOnce() async {
    final detector = ref.read(drivingDetectorProvider);
    final st = await detector.status();
    if (!st.supported || st.configured || !ref.mounted) return;
    try {
      final token = await _backend.createDeviceToken();
      if (!ref.mounted) return;
      await detector.configure(
        url: BackendConfig.supabaseUrl,
        key: BackendConfig.supabaseAnonKey,
        token: token,
        texts: _nativeTexts(),
      );
      await detector.setNames(_localNames);
    } on RealBackendException {
      // Try again next start.
    }
  }

  /// While I'm free: a small notification watches for friends, even when
  /// the app is closed (until my availability ends).
  Future<void> _watchWhileFree({bool ask = true}) async {
    final mine = myActiveAvailability(state, _now());
    if (mine == null || mine.auto) return;
    final detector = ref.read(drivingDetectorProvider);
    await _ensureDevice();
    if (ask) await detector.requestNotificationPermission();
    final tripOnly = _store.getString(_tripOnlyKey);
    await detector.startAvailable(
      mine.expiresAt,
      endWithTrip: tripOnly == mine.startedAt.toIso8601String(),
    );
  }

  /// Back in the app: catch up; and if I'm free but the background watcher
  /// isn't running (Android stopped it), start it again — quietly.
  Future<void> _refreshAndRewatch() async {
    await refresh();
    if (!ref.mounted) return;
    // Back in the app: instant updates may have stopped meanwhile.
    if (state.live != LiveStatus.connected) _reconnectLive();
    await _loadDriving();
    if (!ref.mounted) return;
    final d = state.driving;
    final mine = myActiveAvailability(state, _now());
    if (mine != null &&
        !mine.auto &&
        d.configured &&
        !d.watching &&
        !d.inVehicle) {
      await _watchWhileFree(ask: false);
    }
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

  /// "Short stops keep the trip" (D-128).
  Future<void> setShortStops(bool on) async {
    await ref.read(drivingDetectorProvider).setShortStops(on);
    await _loadDriving();
  }

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
    // "Talk" on "X is on the way": my tap is my yes — ask them now (free
    // for 30 minutes first, like tapping a free friend).
    if (action.askFriend case final id?) {
      final friend = state.snapshot?.friend(id);
      if (friend == null || !ref.mounted) return;
      if (myActiveAvailability(state, _now()) == null &&
          !await startAvailability(AvailabilityMode.free, 30)) {
        return;
      }
      if (!ref.mounted) return;
      // Both free now: quick connect may already be connecting us.
      final already = state.snapshot?.offers.any(
        (o) =>
            o.otherId(state.myId ?? '') == id &&
            (o.status == OfferStatus.pending ||
                (o.status == OfferStatus.accepted && !o.callOver)),
      );
      if (already != true) await askFriend(friend);
      return;
    }
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
        // Joining is complete only with the number saved (friends find
        // each other by it). On failure: stay here and try again.
        await _backend.setMyPhone(phone);
        state = state.copyWith(myPhone: normalizePhone(phone));
      }
      _phoneKnown = true;
      if (!ref.mounted) return;
      // First: a picture (optional), then my people.
      await _store.setString(_firstRunKey, FirstRunStep.photo.name);
      _event('onboarding_started');
      state = state.copyWith(
        phase: RealPhase.ready,
        busy: false,
        firstRun: FirstRunStep.photo,
      );
      await _ensurePresets();
      await refresh();
      _openPendingInvite();
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
      if (!ref.mounted) return;
      _phoneKnown = true;
      state = state.copyWith(myPhone: p);
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
    try {
      await _backend.revokeDeviceTokens();
      // No more notifications for this account on this phone.
      final push = _store.getString(_pushKey);
      if (push != null) await _backend.forgetPushToken(push);
    } on RealBackendException {
      // Signing out anyway.
    }
    await _backend.signOut();
    // A new account starts clean (groups, routines, tips, lists).
    await _clearLocal();
    if (!ref.mounted) return;
    state = RealState(phase: RealPhase.signedOut, prefs: state.prefs);
  }

  /// Everything this phone kept about the account (sign-out / deletion).
  Future<void> _clearLocal() async {
    final detector = ref.read(drivingDetectorProvider);
    await detector.setRoutines('[]');
    await detector.forget();
    _photos.clear();
    await _photoCache.clear();
    for (final k in [
      _firstRunKey,
      _adminKey,
      _handledKey,
      _routinesKey,
      _contactsSyncKey,
      _localNamesKey,
      _contactsOffKey,
      _freeLogKey,
      _hintNoKey,
      _seenMatchesKey,
      _keepInactiveKey,
      _widgetTipKey,
      _bgTipKey,
      _usedFreeKey,
      _micTipKey,
      _presetsKey,
      _permIntroKey,
      _addNumberKey,
      _knownFriendsKey,
      _quickAsksKey,
      _quickIntroKey,
      _crashesKey,
      _tripOnlyKey,
      _pushKey,
    ]) {
      await _store.setString(k, null);
    }
    _handled.clear();
    _answering.clear();
    _givingUp.clear();
    _waitingSince.clear();
    _pendingChecked.clear();
    contactMatches = const [];
    _phoneKnown = false;
  }

  /// "Delete my account and my information": on the server (everything,
  /// photo included) and on this phone. Returns an error code or null.
  Future<String?> deleteAccount() async {
    state = state.copyWith(busy: true);
    try {
      // The server first: if it fails, nothing on this phone is lost.
      await _backend.deleteAccount();
    } on RealBackendException catch (e) {
      if (ref.mounted) state = state.copyWith(busy: false);
      return e.code;
    }
    await _clearLocal();
    if (!ref.mounted) return null;
    state = RealState(phase: RealPhase.signedOut, prefs: state.prefs);
    return null;
  }

  /// Errors a successful refresh proves are over.
  static bool _passing(String? code) =>
      code == 'offline' ||
      code == 'unknown' ||
      (code?.startsWith('auth') ?? false);

  /// A measurement (never content, numbers or names).
  void _event(String name, {int? ms}) =>
      unawaited(_backend.logEvent(name, ms: ms));

  void setPrefs(RealPrefs prefs) {
    final wasVoice = state.prefs.voice;
    state = state.copyWith(prefs: prefs);
    _store.setString(_prefsKey, jsonEncode(prefs.toJson()));
    if (!prefs.voice) _stopVoice();
    if (prefs.voice && !wasVoice) {
      unawaited(ref.read(voiceServiceProvider).prepare());
    }
  }

  // ------------------------------------------------------------ data

  Future<void> refresh() async {
    // A late timer after the app closed (or a test ended): nothing to do.
    if (!ref.mounted) return;
    if (state.phase == RealPhase.notConfigured ||
        state.phase == RealPhase.signedOut ||
        _backend.userId == null) {
      return;
    }
    if (_refreshing) {
      return (_refreshAgain ??= Completer<void>()).future;
    }
    _refreshing = true;
    _refreshStarted = _now();
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
      final snap = _withPhotos(await _backend.fetchSnapshot())
          .withLocalNames(_localNames);
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
        // It worked: a network or sign-in hiccup is over.
        lastError: _passing(prev.lastError) ? null : prev.lastError,
      );
      _react(snap);
      unawaited(_loadPhotos(snap));
      unawaited(_checkPending(snap));
      if (state.serverSchema == null) unawaited(_checkSchema());
    } on RealBackendException catch (e) {
      if (ref.mounted) _setError(e.code);
    } finally {
      _refreshing = false;
      final again = _refreshAgain;
      _refreshAgain = null;
      if (again != null) {
        if (ref.mounted) {
          unawaited(refresh().whenComplete(again.complete));
        } else {
          again.complete();
        }
      }
    }
  }

  // ------------------------------------------------------------ photos

  /// Older versions kept photos in the settings storage: move them out.
  static String _oldPhotoKey(String id) => 'real.photo.$id';

  (int, Uint8List)? _cachedPhoto(String id) {
    final mem = _photos[id];
    if (mem != null) return mem;
    try {
      final raw = _store.getString(_oldPhotoKey(id));
      if (raw == null) return null;
      _store.setString(_oldPhotoKey(id), null);
      final i = raw.indexOf(':');
      final hit = (
        int.parse(raw.substring(0, i)),
        base64Decode(raw.substring(i + 1)),
      );
      _keepPhoto(id, hit.$1, hit.$2);
      return hit;
    } catch (_) {
      return null;
    }
  }

  void _keepPhoto(String id, int version, Uint8List? bytes) {
    if (bytes == null) {
      _photos.remove(id);
      unawaited(_photoCache.remove(id));
    } else {
      _photos[id] = (version, bytes);
      unawaited(_photoCache.put(id, version, bytes));
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
    // Not my friend any more (blocked / removed): forget their photo.
    final visible = {snap.me.id, for (final f in snap.friends) f.id};
    for (final id in _photos.keys.toList()) {
      if (!visible.contains(id)) _keepPhoto(id, 0, null);
    }
    for (final p in [snap.me, ...snap.friends]) {
      if (p.photoVersion <= 0) {
        if (_photos.containsKey(p.id)) _keepPhoto(p.id, 0, null);
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
      if (snap != null) _keepPhoto(me, snap.me.photoVersion, jpeg);
      // The normal refresh (with the names saved on this phone).
      await refresh();
    }
    return null;
  }

  /// What changed on the server that the user must see.
  void _react(RealSnapshot snap) {
    final me = snap.me.id;
    final now = _now();
    for (final o in snap.offers) {
      // The other side cancelled the quick connect during the 5 seconds.
      if (o.status == OfferStatus.cancelled &&
          state.call?.offerId == o.id &&
          state.callStage == CallStage.connecting) {
        _endQuick(cancelledByOther: true);
      }
      if (_handled.contains(o.id) || _answering.contains(o.id)) continue;
      if (_givingUp.contains(o.id) && o.status != OfferStatus.accepted) {
        continue;
      }
      final mine = state.localAnswers[o.id] ?? o.myAnswer(me);
      final other = snap.friend(o.otherId(me));
      // A just-agreed call (not one that already ended — e.g. the other
      // side answered "when to suggest again?", which also touches it).
      final agreedAt = o.acceptedAt ?? o.updatedAt;
      final fresh =
          now.difference(o.updatedAt).abs() < const Duration(minutes: 5) &&
          now.difference(agreedAt).abs() < const Duration(minutes: 5) &&
          !o.callOver;
      switch (o.status) {
        case OfferStatus.accepted
            when o.quick &&
                o.caller == null &&
                o.notBefore != null &&
                now.difference(o.notBefore!) > _quickStale:
          // A quick connect nobody started while its countdown was fresh
          // never dials out of the blue later (D-026); the server ends it.
          _markHandled(o.id);
          unawaited(_quietly(() => _backend.startCall(o.id)));
        case OfferStatus.accepted:
          // Behind another app (the notification is up): the phone can't
          // dial from the background — handled when the app is opened.
          if (!_foreground && fresh) break;
          if (other != null && !_callIdle(state)) {
            // Busy with another call / question: this one waits its turn
            // (its own call is, of course, already handled).
            if (state.call?.offerId == o.id) _markHandled(o.id);
            break;
          }
          _markHandled(o.id);
          // My side of it is already over (I answered "when again?").
          if (other == null || (me == o.userA ? o.endedA : o.endedB)) break;
          if (fresh) {
            unawaited(_beginCall(o, other));
          } else if (now.difference(agreedAt) < const Duration(hours: 12)) {
            // The call happened while the app was closed (e.g. answered
            // from the notification): still ask "when to suggest X again?".
            state = state.copyWith(
              callStage: CallStage.feedback,
              call: RealCall(
                offerId: o.id,
                other: other,
                role: CallRole.inApp,
                startedAt: agreedAt,
                quick: o.quick,
              ),
            );
          }
        case OfferStatus.declined when o.laterFrom != null && o.laterFrom != me:
          _markHandled(o.id);
          // "Not now — I'll get back to you": told even if I hadn't answered.
          if (fresh && other != null) {
            _notify(RealNoticeKind.later, name: other.name);
            if (_driving(now)) _speak(_l.realLaterNote(other.name));
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
    if (offer != null && offer.id != _shownOfferId && _foreground) {
      _shownOfferId = offer.id;
      _event('offer_shown');
      // The one who asked sees it reached me (D-129).
      unawaited(_quietly(() => _backend.offerShown(offer.id)));
    }
    // The first time on this phone: everyone already here is "known".
    if (_knownFriends == null) _rememberFriends(snap.friends.map((f) => f.id));
    final hasFriends = snap.friends.isNotEmpty;
    if (hasFriends && !_hadFriends) _event('first_friend_connected');
    _hadFriends = hasFriends;
    // Read aloud (and listen) only on screen: in the background the
    // notification already reads it — never twice, never a hidden mic.
    if (offer != null &&
        offer.id != _spokenOfferId &&
        _driving(now) &&
        _foreground) {
      _spokenOfferId = offer.id;
      final p = snap.friend(offer.otherId(me))!;
      unawaited(_askByVoice(offer, p));
    }
  }

  bool _driving(DateTime now) => state.prefs.voice && isRealDriving(state, now);

  void _markHandled(String id) {
    _handled.add(id);
    _saveHandled();
  }

  void _unmarkHandled(String id) {
    if (_handled.remove(id)) _saveHandled();
  }

  void _saveHandled() {
    final list = _handled.toList();
    final keep = list.length > 100 ? list.sublist(list.length - 100) : list;
    _store.setString(_handledKey, jsonEncode(keep));
  }

  // ------------------------------------------------------------ availability

  Future<bool> startAvailability(
    AvailabilityMode mode,
    int minutes, {
    String? circleId,
    bool untilTripEnds = false,
  }) async {
    await _maybeAskDirectCall();
    // Answering "yes"/"no" by voice needs the microphone: ask now, while
    // the person is looking at the screen, never in the middle of a drive.
    if (mode == AvailabilityMode.driving && state.prefs.voice) {
      await ref.read(voiceServiceProvider).prepare();
    }
    final ok = await _run(
      () => _backend.setAvailability(
        mode,
        minutes.clamp(1, 180),
        circleId: circleId,
      ),
    );
    _lastNudge = null;
    if (ok) {
      _store.setString(_usedFreeKey, 'yes');
      _event('availability_started');
      _logFree(mode);
    }
    await refresh();
    if (!ref.mounted) return ok;
    if (ok) {
      // "For the whole trip": the background watcher also ends it when the
      // detected trip ends. Remembered by this window's start time.
      final mine = myActiveAvailability(state, _now());
      await _store.setString(
        _tripOnlyKey,
        untilTripEnds && mine != null ? mine.startedAt.toIso8601String() : null,
      );
      if (ref.mounted) unawaited(_watchWhileFree());
      // On the way: my quick-connect friends hear about it (D-119; the
      // server decides who, at most once a day each).
      if (mode == AvailabilityMode.driving) {
        unawaited(_quietly(_backend.notifyTrip));
      }
    }
    return ok;
  }

  static const _tripOnlyKey = 'real.tripOnly.v1';

  /// The push address last saved for this phone (D-119).
  static const _pushKey = 'real.pushToken.v1';

  /// Saves this phone's push address when it's new or changed.
  Future<void> _ensurePushToken() async {
    final token = await ref.read(drivingDetectorProvider).pushToken();
    if (token == null || !ref.mounted || _store.getString(_pushKey) == token) {
      return;
    }
    try {
      await _backend.savePushToken(token, build: ref.read(appBuildProvider));
      await _store.setString(_pushKey, token);
    } on RealBackendException {
      // Tried again next time the app opens.
    }
  }

  /// The test screen: a notification to my own phone (checks the whole
  /// push chain). Returns a code (see [RealBackend.testPush]).
  Future<String> testPush() async {
    final token = await ref.read(drivingDetectorProvider).pushToken();
    if (token == null) return 'no_app_push';
    // Saved again now, in case it changed or the server was just updated.
    try {
      await _backend.savePushToken(token, build: ref.read(appBuildProvider));
      await _store.setString(_pushKey, token);
    } on RealBackendException catch (e) {
      // Saving this phone's address failed (the reason, for the owner).
      return e.code == 'offline' ? 'offline' : 'save_failed: ${e.code}';
    }
    return _backend.testPush();
  }

  /// "Tell my quick-connect friends when I'm on the way" (D-119).
  Future<void> setTripNotify(bool on) async {
    await _run(() => _backend.setTripNotify(on));
    await refresh();
  }

  Future<void> stopAvailability() async {
    _stopVoice();
    // I stopped: the question I was waiting on ends without a "sorry".
    final w = waitingOffer(state, _now());
    if (w != null) _markHandled(w.id);
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
    _answering.add(offer.id);
    try {
      if (accept) {
        _event('offer_accepted_local');
        _waitingSince[offer.id] = _now();
      }
      final answer = await _backend.answerOffer(offer.id, accept: accept);
      final status = answer.status;
      if (!ref.mounted) return;
      if (accept && status == OfferStatus.accepted) {
        final other = state.snapshot?.friend(offer.otherId(state.myId!));
        _markHandled(offer.id);
        _event('both_accepted');
        if (other != null && _callIdle(state)) {
          // I said the second "yes": I dial — now, not after a countdown.
          _bothYesAt = DateTime.now();
          _startCall(offer, other, iCall: answer.iCall, phone: answer.phone);
        }
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
    } finally {
      _answering.remove(offer.id);
    }
    await refresh();
  }

  /// "Not now — I'll get back to you": a no, and they are told so.
  Future<void> respondLater(RealOffer offer) async {
    _stopVoice();
    state = state.copyWith(
      dismissedOffers: {...state.dismissedOffers, offer.id},
    );
    _markHandled(offer.id);
    await _run(() => _backend.declineLater(offer.id));
    await refresh();
  }

  /// Stop waiting for the other side (counts as "not now" for this offer).
  Future<void> cancelWaiting(RealOffer offer) async {
    OfferAnswer? answer;
    _answering.add(offer.id);
    try {
      await _run(
        () async =>
            answer = await _backend.answerOffer(offer.id, accept: false),
      );
    } finally {
      _answering.remove(offer.id);
    }
    // They said yes at the same moment: the call goes on (the refresh
    // starts it, so I see who calls whom). Otherwise it's simply over.
    if (answer?.status != OfferStatus.accepted) {
      _markHandled(offer.id);
      _dropLocalAnswer(offer.id);
    }
    await refresh();
  }

  Future<void> _askByVoice(RealOffer offer, RealProfile p) async {
    final seq = ++_voiceSeq;
    final voice = ref.read(voiceServiceProvider);
    final direct = offer.askedBy(p.id);
    final question = direct
        ? _l.voiceDirect(p.name)
        : _l.realVoiceOffer(p.name, _genderKey(p.gender));
    // No answer: asked again right away, 3 times in all (D-112) — only
    // while the app is on screen.
    _askingSeq = seq;
    try {
      for (var i = 0; i < _askTimes; i++) {
        if (!_foreground) return;
        await voice.speak(question);
        if (seq != _voiceSeq || !ref.mounted || !_foreground) return;
        state = state.copyWith(listening: true);
        final answer = await voice.listenYesNo(timeout: _askListen);
        if (seq != _voiceSeq || !ref.mounted) return;
        state = state.copyWith(listening: false);
        if (currentOffer(state, _now())?.id != offer.id) return;
        switch (answer) {
          case VoiceAnswer.yes:
            await respond(offer, accept: true);
            return;
          case VoiceAnswer.no:
            await respond(offer, accept: false);
            return;
          case VoiceAnswer.permissionDenied:
            // Said once; after that the buttons simply do the job.
            if (_store.getString(_micTipKey) == null) {
              _store.setString(_micTipKey, 'shown');
              _notify(RealNoticeKind.micDenied);
            }
            return;
          case VoiceAnswer.unavailable:
            return; // the big buttons are always there
          case VoiceAnswer.none:
            break; // nothing heard: ask again
        }
      }
    } finally {
      if (_askingSeq == seq) _askingSeq = null;
    }
  }

  /// A question is being asked aloud (and listened for) right now.
  int? _askingSeq;
  bool get _voiceAsking => _askingSeq != null;

  /// The question, up to 3 times; about 3 seconds to answer each time.
  static const _askTimes = 3;
  static const _askListen = Duration(seconds: 4);

  void _speak(String text) {
    _voiceSeq++;
    unawaited(ref.read(voiceServiceProvider).speak(text));
  }

  void _stopVoice() {
    _voiceSeq++;
    _askingSeq = null;
    ref.read(voiceServiceProvider).stop();
    if (state.listening) state = state.copyWith(listening: false);
  }

  // ------------------------------------------------------------ the call

  /// An agreed call I learned about from the server (not from my own
  /// "yes"): they dial me, or — after a restart — I still have to dial.
  Future<void> _beginCall(RealOffer offer, RealProfile other) async {
    if (!_callIdle(state)) return;
    if (offer.quick && offer.caller == null) {
      await _beginQuick(offer, other);
      return;
    }
    // Who calls whom depends on my own number: know it first (right after
    // the app starts it may still be loading).
    if (!_phoneKnown) {
      await _loadPhone();
      if (!ref.mounted || !_callIdle(state)) return;
    }
    final me = state.myId!;
    if (offer.caller != null && offer.caller != me) {
      _startCall(offer, other, iCall: false);
      return;
    }
    // I'm the caller (or an older server): ask for the number.
    try {
      final r = await _backend.startCall(offer.id);
      if (!ref.mounted || !_callIdle(state)) return;
      if (r.state == CallStartState.ready) {
        _startCall(offer, other, iCall: r.iCall, phone: r.phone);
      }
    } on RealBackendException catch (e) {
      _setError(e.code);
      // Not lost: the next refresh tries again while it's still fresh.
      _unmarkHandled(offer.id);
    }
  }

  /// Both agreed: go. The caller's phone dials at once; the other side is
  /// told who is calling. No extra screens, no countdown.
  void _startCall(
    RealOffer offer,
    RealProfile other, {
    required bool iCall,
    String? phone,
  }) {
    _stopVoice();
    final role = iCall
        ? (phone != null ? CallRole.iCall : CallRole.inApp)
        : (state.myPhone != null ? CallRole.theyCall : CallRole.inApp);
    final call = RealCall(
      offerId: offer.id,
      other: other,
      role: role,
      startedAt: _now(),
      phone: role == CallRole.iCall ? phone : null,
      quick: offer.quick,
    );
    state = state.copyWith(call: call, callStage: CallStage.connecting);
    // Only my own dialing is measured ("both said yes" → dialing).
    if (role != CallRole.iCall) _bothYesAt = null;
    // The background service shouldn't also say "X is calling you" about it
    // (for my own dialing: once the phone really dialed, see [_dial]).
    if (role == CallRole.theyCall) {
      unawaited(ref.read(drivingDetectorProvider).callHandled(call.offerId));
    }
    switch (role) {
      case CallRole.iCall:
        unawaited(_dial());
        if (_driving(_now())) {
          _speak(_l.realVoiceCalling(other.name));
        }
      case CallRole.theyCall:
        state = state.copyWith(callStage: CallStage.waitingForTheirCall);
        if (_driving(_now())) {
          _speak(_l.realVoiceTheyCall(other.name, _genderKey(other.gender)));
        }
      case CallRole.inApp:
        state = state.copyWith(callStage: CallStage.inApp);
    }
  }

  /// Quick connect: "Connecting to Dani…" with Cancel. The server decides
  /// when the 5 seconds (after both phones saw it) are over.
  Future<void> _beginQuick(RealOffer offer, RealProfile other) async {
    _stopVoice();
    state = state.copyWith(
      callStage: CallStage.connecting,
      call: RealCall(
        offerId: offer.id,
        other: other,
        role: CallRole.inApp,
        startedAt: _now(),
        quick: true,
      ),
    );
    _speak(_l.realVoiceQuick(other.name));
    try {
      await _backend.seenCall(offer.id);
    } on RealBackendException {
      // start_call below marks it seen too.
    }
    await _pollQuick(offer, other);
  }

  Future<void> _pollQuick(RealOffer offer, RealProfile other) async {
    for (var tries = 0; tries < 120; tries++) {
      if (!ref.mounted ||
          state.call?.offerId != offer.id ||
          state.callStage != CallStage.connecting) {
        return;
      }
      CallStart r;
      try {
        r = await _backend.startCall(offer.id);
      } on RealBackendException catch (e) {
        _setError(e.code);
        r = const CallStart(CallStartState.wait, waitMs: 1000);
      }
      if (!ref.mounted ||
          state.call?.offerId != offer.id ||
          state.callStage != CallStage.connecting) {
        return;
      }
      if (_cancellingQuick == offer.id) {
        // "Cancel" was tapped: wait for the server's answer to it.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      }
      switch (r.state) {
        case CallStartState.ready:
          if (_quickTooLate == offer.id) {
            _quickTooLate = null;
            _notify(RealNoticeKind.quickTooLate);
          }
          _startCall(offer, other, iCall: r.iCall, phone: r.phone);
          return;
        case CallStartState.cancelled:
        case CallStartState.gone:
          _endQuick(cancelledByOther: r.state == CallStartState.cancelled);
          return;
        case CallStartState.wait:
          final ms = (r.waitMs ?? 500).clamp(100, 500);
          await Future<void>.delayed(Duration(milliseconds: ms));
      }
    }
    if (ref.mounted && state.call?.offerId == offer.id) {
      // Gave up: tell the server too, so the other phone stops waiting.
      await _quietly(() async {
        await _backend.cancelCall(offer.id);
      });
      if (ref.mounted && state.call?.offerId == offer.id) {
        _endQuick(cancelledByOther: false);
      }
    }
  }

  void _endQuick({required bool cancelledByOther}) {
    _stopVoice();
    final id = state.call?.offerId;
    state = state.copyWith(callStage: CallStage.none, call: null);
    if (id != null) unawaited(_quietly(() => _backend.endCall(id)));
    _notify(
      cancelledByOther
          ? RealNoticeKind.quickCancelled
          : RealNoticeKind.didNotWorkOut,
    );
  }

  Future<void> _quietly(Future<void> Function() body) async {
    try {
      await body();
    } on RealBackendException {
      // Not worth bothering the user.
    }
  }

  Future<void> _dial() async {
    final call = state.call;
    if (call == null || call.phone == null) return;
    if (state.callStage != CallStage.connecting) return;
    state = state.copyWith(callStage: CallStage.dialed);
    final since = _bothYesAt;
    _bothYesAt = null;
    final r = await ref.read(phoneDialerProvider).call(call.phone!);
    // The key number: from "both said yes" to the phone dialing.
    _event(
      'dial_started',
      ms: since == null
          ? null
          : DateTime.now().difference(since).inMilliseconds,
    );
    if (!ref.mounted) return;
    if (r == DialResult.calling || r == DialResult.openedDialer) {
      // Dialing: the background service needn't say "tap to call" too.
      unawaited(ref.read(drivingDetectorProvider).callHandled(call.offerId));
    }
    if (r == DialResult.failed || r == DialResult.unsupported) {
      // Couldn't open the phone: fall back to the in-app (simulated) call.
      state = state.copyWith(
        callStage: CallStage.inApp,
        call: RealCall(
          offerId: call.offerId,
          other: call.other,
          role: call.role,
          startedAt: call.startedAt,
          quick: call.quick,
          dialFailed: true,
        ),
      );
    }
  }

  /// Quick connect: cancel during the 5 seconds (reaches the other side).
  Future<void> cancelCall() async {
    final call = state.call;
    if (call == null || state.callStage != CallStage.connecting) return;
    if (_cancellingQuick == call.offerId) return;
    _stopVoice();
    _cancellingQuick = call.offerId;
    var cancelled = true;
    try {
      cancelled = await _backend.cancelCall(call.offerId);
    } on RealBackendException {
      // Offline: at least stop on this phone.
    } finally {
      _cancellingQuick = null;
    }
    if (!ref.mounted) return;
    if (!cancelled) {
      // Too late (the 5 seconds were over) — or the other side already
      // cancelled. Keep going; the next check tells which.
      _quickTooLate = call.offerId;
      return;
    }
    if (state.call?.offerId == call.offerId) {
      state = state.copyWith(callStage: CallStage.none, call: null);
    }
    await _quietly(() => _backend.endCall(call.offerId));
  }

  void finishCall() {
    _stopVoice();
    final id = state.call?.offerId;
    state = state.copyWith(callStage: CallStage.feedback);
    // Free both of us right away (feedback can wait).
    if (id != null) unawaited(_quietly(() => _backend.endCall(id)));
  }

  /// After the call: it was good / not again soon / we didn't talk.
  /// After the call: when to suggest them again (0 = any time) and
  /// whether we really talked. Skipping keeps the 3 quiet days (D-108).
  Future<void> afterCall(int days, {bool talked = true}) async {
    final call = state.call;
    state = state.copyWith(callStage: CallStage.none, call: null);
    if (call == null) return;
    try {
      await _backend.afterCall(call.offerId, days: days, talked: talked);
      _event('call_feedback_submitted');
      if (ref.mounted) _notify(RealNoticeKind.feedbackThanks);
    } on RealBackendException catch (e) {
      // At least free me for the next offer.
      await _quietly(() => _backend.endCall(call.offerId));
      if (ref.mounted) _setError(e.code);
    }
  }

  void skipFeedback() {
    final call = state.call;
    state = state.copyWith(callStage: CallStage.none, call: null);
    if (call != null) unawaited(_quietly(() => _backend.endCall(call.offerId)));
  }

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
        store: BackendConfig.store,
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
    final before = {...?state.snapshot?.friends.map((f) => f.id)};
    _joiningInvite = true;
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
    try {
      await refresh();
      // The one I just joined through their invitation isn't news to me.
      _rememberFriends([
        for (final f in state.snapshot?.friends ?? const <RealProfile>[])
          if (!before.contains(f.id)) f.id,
      ]);
    } finally {
      _joiningInvite = false;
    }
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
    await _ensureDevice();
    // A routine is useless if its notifications can't be shown.
    if (list.isNotEmpty) {
      await ref.read(drivingDetectorProvider).requestNotificationPermission();
    }
    await _storeRoutines(list);
    _notify(RealNoticeKind.saved);
  }

  Future<void> _storeRoutines(List<Routine> list) async {
    state = state.copyWith(routines: list);
    await _store.setString(
      _routinesKey,
      jsonEncode([for (final r in list) r.toJson()]),
    );
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
                'circle': r.circleId ?? '',
                'enabled': true,
              },
          ]),
        );
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
  /// [quiet]: no pop-up about the result (the first-run screen shows it).
  Future<void> syncContacts({
    bool ask = true,
    bool quiet = false,
    bool auto = false,
  }) async {
    if (!auto) await _store.setString(_contactsOffKey, null);
    final reader = ref.read(contactsReaderProvider);
    final allowed = ask
        ? await reader.requestPermission()
        : await reader.hasPermission();
    if (!ref.mounted) return;
    if (!allowed) {
      if (ask && !quiet) _notify(RealNoticeKind.contactsNoPermission);
      return;
    }
    final contacts = await reader.contacts();
    if (!ref.mounted) return;
    // Hash → the name saved on THIS phone (never sent anywhere).
    final saved = <String, String>{};
    for (final c in contacts) {
      final h = hashPhone(c.number);
      if (h == null || (saved[h]?.isNotEmpty ?? false)) continue;
      saved[h] = c.name.trim();
    }
    Future<void> body() async {
      // The server takes up to 5000 numbers at a time.
      final found = await _backend.syncContacts(saved.keys.take(5000).toList());
      if (!ref.mounted) return;
      _store.setString(_contactsSyncKey, _now().toIso8601String());
      final names = {..._localNames};
      for (final m in found) {
        final local = saved[m.hash] ?? '';
        if (local.trim().isNotEmpty) names[m.id] = local.trim();
      }
      _saveLocalNames(names);
      contactMatches = [
        for (final m in found)
          if (!m.isFriend) names[m.id] == null ? m : m.named(names[m.id]!),
      ];
      if (!quiet && ask && contactMatches.isEmpty) {
        _notify(RealNoticeKind.contactsNone);
      }
    }

    if (auto) {
      // In the background: no spinner, no error message.
      try {
        await body();
      } on RealBackendException {
        return;
      }
    } else {
      await _run(body);
    }
    if (ref.mounted) await refresh();
  }

  static const _seenMatchesKey = 'real.contactsSeen.v1';
  static const _localNamesKey = 'real.localNames.v1';
  static const _contactsOffKey = 'real.contactsOff.v1';

  /// Friend id → the name saved in MY contacts. Only on this phone.
  Map<String, String> get _localNames {
    try {
      return (jsonDecode(_store.getString(_localNamesKey) ?? '{}') as Map)
          .cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  void _saveLocalNames(Map<String, String> names) {
    _store.setString(_localNamesKey, jsonEncode(names));
    // The background notifications use the same names.
    unawaited(ref.read(drivingDetectorProvider).setNames(names));
  }

  /// Contacts who use DriveTalk and aren't my friends yet (from the last
  /// search). Nobody is added unless I pick them.
  List<ContactMatch> contactMatches = const [];

  Set<String> get _seenMatches {
    try {
      return {
        ...(jsonDecode(_store.getString(_seenMatchesKey) ?? '[]') as List)
            .cast<String>(),
      };
    } catch (_) {
      return {};
    }
  }

  void _markSeen(Iterable<String> ids) {
    final all = {..._seenMatches, ...ids}.toList();
    final keep = all.length > 500 ? all.sublist(all.length - 500) : all;
    _store.setString(_seenMatchesKey, jsonEncode(keep));
  }

  /// Someone from my contacts joined since I last looked → one quiet card.
  ContactMatch? get newContactMatch {
    final seen = _seenMatches;
    return contactMatches.where((m) => !seen.contains(m.id)).firstOrNull;
  }

  /// The list was shown: what's in it isn't "new" any more.
  void markMatchesSeen() => _markSeen(contactMatches.map((m) => m.id));

  /// Add the people I picked — connected at once.
  Future<void> addContacts(List<ContactMatch> picked) async {
    if (picked.isEmpty) return;
    _markSeen(picked.map((m) => m.id));
    final ids = {for (final m in picked) m.id};
    _rememberFriends(ids); // I added them: no "X added you" card
    final ok = await _run(() async {
      final names = await _backend.addContacts(ids.toList());
      if (!ref.mounted) return;
      contactMatches = [
        for (final m in contactMatches)
          if (!ids.contains(m.id)) m,
      ];
      if (names.isNotEmpty) {
        _notify(RealNoticeKind.contactsFound, name: names.join(', '));
      }
    });
    if (ok) _event('contacts_added');
    await refresh();
  }

  /// People I removed — to bring someone back. null = couldn't load.
  Future<List<ContactMatch>?> removedFriends() async {
    try {
      final names = _localNames;
      return [
        for (final m in await _backend.removedFriends())
          names[m.id] == null ? m : m.named(names[m.id]!),
      ];
    } on RealBackendException catch (e) {
      _setError(e.code);
      return null;
    }
  }

  /// Bring back someone I removed: friends again at once.
  Future<bool> restoreFriend(ContactMatch m) async {
    var ok = false;
    _rememberFriends([m.id]);
    await _run(() async => ok = await _backend.restoreFriend(m.id));
    if (ok) _notify(RealNoticeKind.contactsFound, name: m.name);
    await refresh();
    return ok;
  }

  /// "Not this one" on the new-contact card.
  void dismissMatch(ContactMatch m) {
    _markSeen([m.id]);
    state = state.copyWith();
  }

  /// How much I want to talk with this friend: 0 (never offer) – 5 (first).
  Future<void> setRating(RealProfile friend, int rating) async {
    await _run(() => _backend.setRating(friend.id, rating.clamp(0, 5)));
    await refresh();
  }

  /// "Cancel the pause" on a friend's card (D-113).
  Future<void> clearPause(RealProfile friend) async {
    await _run(() => _backend.clearPause(friend.id));
    await refresh();
  }

  /// Quick connect with one friend (D-112).
  Future<void> setQuick(RealProfile friend, bool on) async {
    await _run(() => _backend.setQuick(friend.id, on));
    _seenQuickAsk(friend.id);
    await refresh();
  }

  static const _quickAsksKey = 'real.quickAsksSeen.v1';
  static const _quickIntroKey = 'real.quickIntro.v1';

  Set<String> get _quickAsksSeen {
    final raw = _store.getString(_quickAsksKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  void _seenQuickAsk(String id) {
    final seen = _quickAsksSeen..add(id);
    _store.setString(_quickAsksKey, jsonEncode(seen.toList()));
  }

  /// A friend turned quick connect on for me (and I haven't): asked once,
  /// only here in the app.
  RealProfile? get quickAsk {
    final snap = state.snapshot;
    if (snap == null) return null;
    final seen = _quickAsksSeen;
    for (final f in snap.friends) {
      if (snap.quickTheirs.contains(f.id) &&
          !snap.quickMine.contains(f.id) &&
          !seen.contains(f.id)) {
        return f;
      }
    }
    return null;
  }

  void dismissQuickAsk(RealProfile f) {
    _seenQuickAsk(f.id);
    state = state.copyWith();
  }

  /// Once: "quick connect" exists (when I have friends and use none).
  bool get showQuickIntro {
    final snap = state.snapshot;
    return snap != null &&
        snap.friends.isNotEmpty &&
        snap.quickMine.isEmpty &&
        _store.getString(_quickIntroKey) == null;
  }

  void dismissQuickIntro() {
    _store.setString(_quickIntroKey, 'seen');
    state = state.copyWith();
  }

  static const _keepInactiveKey = 'real.keepInactive.v1';

  /// A friend who hasn't opened the app for a week (maybe removed it):
  /// suggest removing them, once per friend.
  RealProfile? get inactiveFriend {
    final snap = state.snapshot;
    if (snap == null) return null;
    final kept = _keptInactive;
    for (final f in snap.friends) {
      if ((snap.inactiveDays[f.id] ?? 0) >= 7 && !kept.contains(f.id)) {
        return f;
      }
    }
    return null;
  }

  Set<String> get _keptInactive {
    try {
      return {
        ...(jsonDecode(_store.getString(_keepInactiveKey) ?? '[]') as List)
            .cast<String>(),
      };
    } catch (_) {
      return {};
    }
  }

  /// "Keep them" on the inactive card.
  void keepInactive(RealProfile f) {
    _store.setString(_keepInactiveKey, jsonEncode([..._keptInactive, f.id]));
    state = state.copyWith();
  }

  /// "Send feedback" (settings): a short note to the owner.
  Future<bool> sendFeedback(String text) async {
    if (text.trim().isEmpty) return false;
    final ok = await _run(
      () =>
          _backend.sendFeedback(text.trim(), build: ref.read(appBuildProvider)),
    );
    if (ok) _notify(RealNoticeKind.feedbackThanks);
    return ok;
  }

  /// Owner only: feedback and reports (null = couldn't load / not owner).
  Future<List<OwnerNote>?> ownerNotes({required bool reports}) async {
    try {
      return reports
          ? await _backend.ownerReports()
          : await _backend.ownerFeedback();
    } on RealBackendException catch (e) {
      _notOwner(e);
      return null;
    }
  }

  /// The server doesn't know this account as the owner (e.g. the code was
  /// entered before the server could check it): lock, so entering the
  /// code again registers it.
  void _notOwner(RealBackendException e) {
    if (e.code == 'not_owner') {
      lockAdmin();
    } else {
      _setError(e.code);
    }
  }

  /// Owner numbers (totals only). null = couldn't load.
  Future<Map<String, num?>?> appStats(int days) async {
    try {
      return await _backend.appStats(days);
    } on RealBackendException catch (e) {
      _notOwner(e);
      return null;
    }
  }

  // ------------------------------------------------- calm & private (D-106)

  /// Tap a free friend: ask them now (my tap is my yes). True if asked.
  Future<bool> askFriend(RealProfile friend) async {
    _stopVoice();
    // My own open question gives way (the server cancels it too).
    final w = waitingOffer(state, _now());
    if (w != null) _markHandled(w.id);
    String? result;
    final ok = await _run(() async {
      result = await _backend.askFriend(friend.id);
    });
    if (ok && result != 'asked' && ref.mounted) {
      _notify(
        RealNoticeKind.askFailed,
        name: friend.name,
        gender: friend.gender,
        code: result,
      );
    }
    if (result == 'asked') _event('ask_friend');
    await refresh();
    return result == 'asked';
  }

  /// While driving: the regular screen for a moment (or back).
  void showNormalView(bool on) {
    final mine = myActiveAvailability(state, _now());
    state = state.copyWith(normalViewFor: on ? mine?.startedAt : null);
  }

  /// During a call: the main screen for a moment (or back to the call).
  void hideCall(bool hide) {
    state = state.copyWith(callHiddenFor: hide ? state.call?.offerId : null);
  }

  /// "Still free" after a question I didn't answer.
  Future<void> stillFree() async {
    await _run(_backend.stillFree);
    await refresh();
  }

  /// "Ready now": the first quiet minutes of an automatic trip end.
  Future<void> readyNow() async {
    await _run(_backend.readyNow);
    await refresh();
  }

  /// After trips with no answer: keep automatic detection (or turn it off).
  Future<void> keepAuto({required bool keep}) async {
    await _run(_backend.keepAuto);
    if (!keep) {
      await disableAutoDriving();
    } else {
      await refresh();
    }
  }

  /// More minutes on my free time.
  Future<void> extendAvailability(int minutes) async {
    await _run(() => _backend.extendAvailability(minutes));
    await refresh();
    if (ref.mounted) unawaited(_watchWhileFree());
  }

  /// "Free without my name" (friends see only how many are free).
  Future<void> setAnonymous(bool on) async {
    await _run(() => _backend.setSettings(anonymous: on));
    await refresh();
  }

  /// In a call, look simply not free.
  Future<void> setHideInCall(bool on) async {
    await _run(() => _backend.setSettings(hideInCall: on));
    await refresh();
  }

  /// One quiet-hours schedule (minutes after midnight); null = none. [days]:
  /// bit 0 = Sunday … bit 6 = Saturday (127 = every day; null = as before).
  Future<void> setQuietHours(int? from, int? to, {int? days}) async {
    if (from == null || to == null) return setQuietRanges(const []);
    final cur = state.snapshot?.status.quietRanges ?? const <QuietRange>[];
    await setQuietRanges([
      QuietRange(from, to, days ?? cur.firstOrNull?.days),
      ...cur.skip(1),
    ]);
  }

  /// All quiet-hours schedules at once (D-124; up to 4, empty = none).
  Future<void> setQuietRanges(List<QuietRange> ranges) async {
    await _run(
      () => _backend.setQuietRanges(
        ranges.take(4).toList(),
        timeZone: ref.read(timeZoneProvider),
      ),
    );
    await refresh();
  }

  /// Keep a friend who added me from their contacts.
  Future<void> approveFriend(RealProfile f) async {
    _rememberFriends([f.id]);
    final ok = await _run(() => _backend.approveFriend(f.id));
    if (ok && ref.mounted) {
      _notify(RealNoticeKind.friendKept, name: f.name, gender: f.gender);
    }
    await refresh();
  }

  /// Owner only: crash notes (null = couldn't load / not owner).
  Future<List<OwnerNote>?> ownerCrashes() async {
    try {
      return await _backend.ownerCrashes();
    } on RealBackendException catch (e) {
      _notOwner(e);
      return null;
    }
  }

  static const _crashesKey = 'real.crashes.v1';

  /// A crash: a short technical note to the owner (no personal data).
  /// Kept on the phone until it reaches the server.
  Future<void> reportCrash(String kind, Object error, StackTrace? stack) async {
    final note = {
      'kind': kind,
      'message': _short('$error', 500),
      'stack': _short('${stack ?? ''}', 4000),
    };
    final queue = _crashQueue()..add(note);
    await _store.setString(
      _crashesKey,
      jsonEncode(queue.length > 5 ? queue.sublist(queue.length - 5) : queue),
    );
    await flushCrashes();
  }

  List<Map<String, dynamic>> _crashQueue() {
    try {
      return [
        for (final x
            in jsonDecode(_store.getString(_crashesKey) ?? '[]') as List)
          Map<String, dynamic>.from(x as Map),
      ];
    } catch (_) {
      return [];
    }
  }

  var _flushing = false;

  /// Send crash notes waiting on the phone (after a restart too).
  Future<void> flushCrashes() async {
    if (_flushing || _backend.userId == null) return;
    final queue = _crashQueue();
    if (queue.isEmpty) return;
    _flushing = true;
    try {
      for (final c in queue) {
        await _backend.reportCrash(
          build: '${ref.read(appBuildProvider) ?? ''}',
          kind: '${c['kind']}',
          message: _scrub('${c['message']}'),
          stack: _scrub('${c['stack']}'),
        );
      }
      await _store.setString(_crashesKey, null);
    } catch (_) {
      // Next start.
    } finally {
      _flushing = false;
    }
  }

  static String _short(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  /// A crash note never carries ids, numbers or emails (an error's text can
  /// include the input or a web address): replaced before sending. Also
  /// covers notes the Android side wrote.
  @visibleForTesting
  static String scrubCrashText(String s) => s
      .replaceAll(
        RegExp(
          r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
          r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
        ),
        '<id>',
      )
      .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '<email>')
      .replaceAll(RegExp(r'\+?\d[\d\s-]{6,}\d'), '<number>');

  static String _scrub(String s) => scrubCrashText(s);

  /// Hide my status from friends (and theirs from me). Offers go on.
  Future<void> setHideStatus(bool hide) async {
    await _run(() => _backend.setHideStatus(hide));
    await refresh();
  }

  Future<void> _maybeSyncContacts() async {
    final last = DateTime.tryParse(_store.getString(_contactsSyncKey) ?? '');
    // Permission taken away since the last sync: remove what was uploaded.
    if (last != null &&
        !await ref.read(contactsReaderProvider).hasPermission()) {
      try {
        await _backend.clearContactHashes();
        await _store.setString(_contactsSyncKey, null);
        await _store.setString(_localNamesKey, null);
      } on RealBackendException {
        // Next time.
      }
      return;
    }
    if (last != null && _now().difference(last) < const Duration(hours: 12)) {
      return;
    }
    if (_store.getString(_contactsOffKey) != null) return;
    await syncContacts(ask: false, auto: true);
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

  // ------------------------------------------------------------ who sees me

  static const _presetsKey = 'real.presetCircles.v1';
  static const _addNumberKey = 'real.addNumberLater.v1';
  static const _knownFriendsKey = 'real.knownFriends.v1';
  var _joiningInvite = false;

  Set<String>? get _knownFriends {
    final raw = _store.getString(_knownFriendsKey);
    if (raw == null) return null;
    try {
      return {for (final x in jsonDecode(raw) as List) x as String};
    } catch (_) {
      return null;
    }
  }

  void _rememberFriends(Iterable<String> ids) {
    final all = {...?_knownFriends, ...ids}.toList();
    final keep = all.length > 1000 ? all.sublist(all.length - 1000) : all;
    _store.setString(_knownFriendsKey, jsonEncode(keep));
  }

  /// Pending "keep?" questions already checked against my contacts.
  final _pendingChecked = <String>{};

  /// Someone added me and the server doesn't know I have their number
  /// (e.g. they joined after my last contacts search): look again first,
  /// so I'm not asked about someone I do have saved.
  Future<void> _checkPending(RealSnapshot snap) async {
    final fresh = snap.status.pending.difference(_pendingChecked);
    if (fresh.isEmpty) return;
    _pendingChecked.addAll(fresh);
    final synced = _store.getString(_contactsSyncKey) != null;
    if (synced &&
        _store.getString(_contactsOffKey) == null &&
        await ref.read(contactsReaderProvider).hasPermission()) {
      await syncContacts(ask: false, quiet: true, auto: true);
    }
    if (ref.mounted) state = state.copyWith();
  }

  /// Someone who added me from their contacts and waits for my "keep"
  /// (after my contacts were checked again).
  RealProfile? get pendingFriend {
    final snap = state.snapshot;
    if (snap == null) return null;
    for (final id in snap.status.pending) {
      if (!_pendingChecked.contains(id)) continue;
      if (snap.friend(id) case final f?) return f;
    }
    return null;
  }

  /// A friend who appeared without me adding them on this phone: they
  /// found me in their contacts, or used my invitation. One card each.
  RealProfile? get newFriend {
    final known = _knownFriends;
    if (known == null || _joiningInvite) return null;
    final pending = state.snapshot?.status.pending ?? const {};
    return state.snapshot?.friends
        .where((f) => !known.contains(f.id) && !pending.contains(f.id))
        .firstOrNull;
  }

  void dismissNewFriend(RealProfile f) {
    _rememberFriends([f.id]);
    state = state.copyWith();
  }

  /// Whether my number was read from the server (so "no number" is real,
  /// not just "not loaded yet").
  var _phoneKnown = false;

  /// "Add your number so friends find you" — when I have none (again a
  /// week after "not now").
  bool get showAddNumber {
    if (!_phoneKnown || state.myPhone != null) return false;
    final later = DateTime.tryParse(_store.getString(_addNumberKey) ?? '');
    return later == null || _now().difference(later) > const Duration(days: 7);
  }

  void addNumberLater() {
    _store.setString(_addNumberKey, _now().toIso8601String());
    state = state.copyWith();
  }

  static const _permIntroKey = 'real.permIntro.v1';

  /// The first "I have time" on a phone that will ask questions (Android):
  /// one short note about them first.
  bool get needsPermissionIntro =>
      state.driving.supported && _store.getString(_permIntroKey) == null;

  void markPermissionIntroShown() => _store.setString(_permIntroKey, 'shown');

  /// Family / friends / work, once (empty; the server remembers it too).
  Future<void> _ensurePresets({bool thenRefresh = false}) async {
    if (_store.getString(_presetsKey) != null) return;
    try {
      await _backend.ensurePresetCircles([
        _l.circleFamily,
        _l.circleFriends,
        _l.circleWork,
      ]);
      await _store.setString(_presetsKey, 'done');
      if (thenRefresh && ref.mounted) await refresh();
    } on RealBackendException {
      // Next start.
    }
  }

  /// Who in this circle sees that I'm free (always / never / some modes).
  Future<bool> setCircleRule(RealCircle circle, ShowRule rule) =>
      saveCircle(circle.copyWith(show: rule));

  /// "Everyone else" (friends in none of my circles).
  Future<void> setOthersRule(ShowRule rule) async {
    await _run(() async {
      await _backend.setOthersVisibility(rule.modes);
      _notify(RealNoticeKind.saved);
    });
    _lastNudge = null; // who can be asked may have changed: look now
    await refresh();
  }

  /// Put a friend in exactly these circles of mine.
  Future<void> setFriendCircles(RealProfile f, Set<String> circleIds) async {
    final circles = state.snapshot?.circles ?? const <RealCircle>[];
    await _run(() async {
      for (final c in circles) {
        final inIt = c.memberIds.contains(f.id);
        final want = circleIds.contains(c.id);
        if (inIt == want) continue;
        await _backend.saveCircle(
          c.copyWith(
            memberIds: {
              for (final m in c.memberIds)
                if (m != f.id) m,
              if (want) f.id,
            },
          ),
        );
      }
    });
    _lastNudge = null;
    await refresh();
  }

  Future<bool> saveCircle(RealCircle circle) async {
    final ok = await _run(() async {
      await _backend.saveCircle(circle);
      _notify(RealNoticeKind.saved);
    });
    _lastNudge = null;
    await refresh();
    return ok;
  }

  Future<void> deleteCircle(RealCircle circle) async {
    final mine = myActiveAvailability(state, _now());
    final ok = await _run(() => _backend.deleteCircle(circle.id));
    if (ok) {
      // Routines for that group go back to "everyone" (else they'd fail).
      final routines = state.routines;
      if (routines.any((r) => r.circleId == circle.id)) {
        await _storeRoutines([
          for (final r in routines)
            r.circleId == circle.id ? r.withoutCircle() : r,
        ]);
      }
      // The server ends free time that was only for that group: the
      // background watcher stops too.
      if (mine != null && mine.circleId == circle.id) {
        await ref.read(drivingDetectorProvider).stopAvailable();
      }
    }
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
  /// The phone's own state (and log), fresh — before copying the test info.
  Future<void> reloadDriving() => _loadDriving();

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
      'DriveBond — test info',
      'version: ${ref.read(appVersionProvider)}',
      'mode: real',
      'server: ${BackendConfig.backendHost}',
      'configured: ${_backend.isConfigured}',
      'server schema: ${state.serverSchema ?? '?'} (app needs $kRequiredSchema)',
      'phase: ${s.phase.name}',
      'user: ${short(_backend.userId)}',
      'live: ${s.live.name}',
      'realtime tables: ${_backend.realtimeTables.isEmpty ? '—' : [for (final e in _backend.realtimeTables.entries) '${e.key}=${e.value ? 'ok' : 'FAILED'}'].join(', ')}',
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
      'my phone in a call now: ${s.driving.inCallNow ? 'yes' : 'no'}',
      'friends in a call: ${_busyLine(s, now, time)}',
      'last refresh: ${time(snap?.fetchedAt)}',
      if (_refreshing) 'refreshing since: ${time(_refreshStarted)}',
      'last error: ${s.lastError ?? '—'}${s.lastErrorAt == null ? '' : ' at ${time(s.lastErrorAt)}'}',
      'now: ${now.toIso8601String()}',
      if (s.driving.log.isNotEmpty) ...['phone log:', s.driving.log],
    ].join('\n');
  }

  /// Who looks "in a call", and why: their phone said so, or a call
  /// through the app (agreed, not finished yet).
  String _busyLine(RealState s, DateTime now, String Function(DateTime?) time) {
    final busy = busyFriends(s, now);
    if (busy.isEmpty) return '—';
    return [
      for (final (p, a) in busy)
        '${p.name} '
            '(${a.phoneUntil != null && now.isBefore(a.phoneUntil!) ? 'phone' : 'app call'}'
            ' until ${time(a.busyUntil)})',
    ].join(', ');
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

/// Gender-neutral texts for everyone (D-073).
String _genderKey(Gender g) => 'other';

/// The share text. With an invite site: message + link. Without: message +
/// download link + code to type in the app.
/// [store]: sent from the Google Play app — the invite page then offers the
/// store (not the test APK), so the friend installs from Google Play too.
String inviteMessageFor(
  AppLocalizations l, {
  required String token,
  required String baseUrl,
  required String apkUrl,
  bool store = false,
}) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  if (base.isNotEmpty) {
    return '${l.realInviteMessage}\n$base/i/$token${store ? '?p=1' : ''}';
  }
  return '${l.realInviteMessage}\n${l.realInviteMessageNoSite(apkUrl, token)}';
}
