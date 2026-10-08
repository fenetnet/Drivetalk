import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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

/// "Is there a newer version?" (version.json next to the APK).
final updateCheckerProvider = Provider<UpdateChecker>(
  // Google Play updates the store build by itself.
  (ref) => BackendConfig.store ? FakeUpdateChecker() : HttpUpdateChecker(),
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
enum FirstRunStep { contacts, result, routine, magic }

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
  noAnswer,
  later,
  quickCancelled,
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
  const RealPrefs({
    this.voice = true,
    this.testTab = true,
    this.speakNames = true,
  });
  final bool voice;
  final bool testTab;

  /// Read friends' names aloud (off: "a friend is free — talk?").
  final bool speakNames;

  RealPrefs copyWith({bool? voice, bool? testTab, bool? speakNames}) =>
      RealPrefs(
        voice: voice ?? this.voice,
        testTab: testTab ?? this.testTab,
        speakNames: speakNames ?? this.speakNames,
      );

  Map<String, Object?> toJson() => {
    'voice': voice,
    'testTab': testTab,
    'speakNames': speakNames,
  };
  static RealPrefs fromJson(Map<String, Object?> j) => RealPrefs(
    voice: j['voice'] as bool? ?? true,
    testTab: j['testTab'] as bool? ?? true,
    speakNames: j['speakNames'] as bool? ?? true,
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
  });

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

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

final realProvider = NotifierProvider<RealController, RealState>(
  RealController.new,
);

const _prefsKey = 'real.prefs.v1';

/// The server version this app needs (supabase/migrations, schema_version()).
const kRequiredSchema = 23;
const _firstRunKey = 'real.firstRun.v1';
const _adminKey = 'real.admin.v1';

/// SHA-256 of "drivetalk-admin:<code>" — the code itself is not in the app.
/// It only hides the owner's tools from friends; it protects no data.
const _adminCodeHash =
    '5b054ffe210bfa737ef580c8bbcce8ffac40785b71306fc8cac11a89cb851d73';
const _handledKey = 'real.handledOffers.v1';

class RealController extends Notifier<RealState> {
  late RealBackend _backend;
  late LocalStore _store;
  late PhotoCache _photoCache;
  late DateTime Function() _now;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _debounce;
  Timer? _ticker;
  AppLifecycleListener? _lifecycle;
  var _noticeSeq = 0;
  var _voiceSeq = 0;
  var _tick = 0;
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
    try {
      _lifecycle = AppLifecycleListener(onResume: _onResume);
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
    if (state.serverSchema == null) unawaited(_checkSchema());
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
    checkWaiting();
  }

  /// How long I wait for the other side after my "yes" before giving up.
  static const waitLimit = Duration(seconds: 25);

  /// Runs every 5 seconds (public for tests).
  @visibleForTesting
  void checkWaiting() {
    final now = _now();
    final w = waitingOffer(state, now);
    if (w == null) return;
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
      if (answer.status != OfferStatus.accepted) {
        _markHandled(offer.id);
        _event('wait_timeout');
        _notify(RealNoticeKind.noAnswer);
        if (_driving(_now())) _speak(_l.realNoAnswer);
      }
    } on RealBackendException catch (e) {
      _setError(e.code);
    } finally {
      _givingUp.remove(offer.id);
    }
    await refresh();
  }

  void _onResume() {
    unawaited(checkForUpdate());
    if (state.phase != RealPhase.ready) return;
    // Back from the phone call → ask how it went.
    if (state.callStage == CallStage.dialed) {
      state = state.copyWith(callStage: CallStage.feedback);
    }
    refresh();
    unawaited(_backend.touchSeen());
    unawaited(_loadDriving());
    unawaited(_handleLaunchAction());
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

  /// Is a newer version published? (At start, and on return after 3 hours.)
  Future<void> checkForUpdate({bool force = false}) async {
    final mine = ref.read(appBuildProvider);
    if (mine == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastUpdateCheck != null &&
        now.difference(_lastUpdateCheck!) < const Duration(hours: 3)) {
      return;
    }
    _lastUpdateCheck = now;
    final latest = await ref.read(updateCheckerProvider).latestBuild();
    if (!ref.mounted || latest == null) return;
    if (latest > mine) state = state.copyWith(newBuild: latest);
  }

  // ------------------------------------------------------------ admin

  /// The owner's code opens the test tab and the other tools on this phone.
  bool unlockAdmin(String code) {
    final hash = sha256
        .convert(utf8.encode('drivetalk-admin:${code.trim()}'))
        .toString();
    if (hash != _adminCodeHash) return false;
    _store.setString(_adminKey, 'on');
    state = state.copyWith(admin: true);
    // Also on the server: only then can this account read feedback/reports.
    unawaited(_backend.claimOwner(code.trim()));
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

  void firstRunNext() => _setFirstRun(switch (state.firstRun) {
    FirstRunStep.contacts => FirstRunStep.result,
    FirstRunStep.result => FirstRunStep.routine,
    FirstRunStep.routine => FirstRunStep.magic,
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
    'offerTitle': _l.realOfferTitle('{name}', 'other'),
    'offerBody': _l.realOfferNote,
    'talk': _l.realTalkNow,
    'notNow': _l.realNotNow,
    'voiceOffer': state.prefs.speakNames
        ? _l.realVoiceOffer('{name}', 'other')
        : _l.realVoiceOfferAnon,
    'quickTitle': _l.realQuickConnecting('{name}'),
    'quickBody': _l.realQuickConnectingBody,
    'cancel': _l.cancel,
    'publicOffer': _l.realNotifPublic,
    'bgFailedTitle': _l.realBgFailedTitle,
    'bgFailedBody': _l.realBgFailedBody,
    'voiceQuick': state.prefs.speakNames
        ? _l.realVoiceQuick('{name}')
        : _l.realVoiceQuickAnon,
    'manualTitle': _l.realNotifManualTitle,
    'quickOff': _l.realQuickOff,
    'quickOn': _l.realQuickOn,
    'tileLabel': 'DriveBond',
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
        // Joining is complete only with the number saved (friends find
        // each other by it). On failure: stay here and try again.
        await _backend.setMyPhone(phone);
        state = state.copyWith(myPhone: normalizePhone(phone));
      }
      if (!ref.mounted) return;
      await _store.setString(_firstRunKey, FirstRunStep.contacts.name);
      _event('onboarding_started');
      state = state.copyWith(
        phase: RealPhase.ready,
        busy: false,
        firstRun: FirstRunStep.contacts,
      );
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
    _photos.clear();
    await _photoCache.clear();
    if (!ref.mounted) return;
    state = RealState(phase: RealPhase.signedOut, prefs: state.prefs);
  }

  /// "Delete my account and my information": on the server (everything,
  /// photo included) and on this phone. Returns an error code or null.
  Future<String?> deleteAccount() async {
    state = state.copyWith(busy: true);
    try {
      await ref.read(drivingDetectorProvider).setRoutines('[]');
      await ref.read(drivingDetectorProvider).forget();
      await _backend.deleteAccount();
    } on RealBackendException catch (e) {
      if (ref.mounted) state = state.copyWith(busy: false);
      return e.code;
    }
    _photos.clear();
    await _photoCache.clear();
    for (final k in [
      _firstRunKey,
      _handledKey,
      _routinesKey,
      _contactsSyncKey,
      _localNamesKey,
    ]) {
      await _store.setString(k, null);
    }
    _handled.clear();
    if (!ref.mounted) return null;
    state = RealState(phase: RealPhase.signedOut, prefs: state.prefs);
    return null;
  }

  /// A measurement (never content, numbers or names).
  void _event(String name, {int? ms}) =>
      unawaited(_backend.logEvent(name, ms: ms));

  void setPrefs(RealPrefs prefs) {
    final namesChanged = prefs.speakNames != state.prefs.speakNames;
    state = state.copyWith(prefs: prefs);
    _store.setString(_prefsKey, jsonEncode(prefs.toJson()));
    if (namesChanged && state.driving.configured) {
      unawaited(ref.read(drivingDetectorProvider).updateTexts(_nativeTexts()));
    }
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
        lastError: prev.lastError == 'offline' ? null : prev.lastError,
      );
      _react(snap);
      unawaited(_loadPhotos(snap));
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
      // The other side cancelled the quick connect during the 5 seconds.
      if (o.status == OfferStatus.cancelled &&
          state.call?.offerId == o.id &&
          state.callStage == CallStage.connecting) {
        _endQuick(cancelledByOther: true);
      }
      if (_handled.contains(o.id)) continue;
      if (_givingUp.contains(o.id) && o.status != OfferStatus.accepted) {
        continue;
      }
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
    if (offer != null && offer.id != _shownOfferId) {
      _shownOfferId = offer.id;
      _event('offer_shown');
    }
    final hasFriends = snap.friends.isNotEmpty;
    if (hasFriends && !_hadFriends) _event('first_friend_connected');
    _hadFriends = hasFriends;
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
    await _maybeAskDirectCall();
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
        if (other != null) {
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
    _markHandled(offer.id);
    await _run(() => _backend.answerOffer(offer.id, accept: false));
    await refresh();
  }

  Future<void> _askByVoice(RealOffer offer, RealProfile p) async {
    final seq = ++_voiceSeq;
    final voice = ref.read(voiceServiceProvider);
    await voice.speak(
      state.prefs.speakNames
          ? _l.realVoiceOffer(p.name, _genderKey(p.gender))
          : _l.realVoiceOfferAnon,
    );
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

  /// An agreed call I learned about from the server (not from my own
  /// "yes"): they dial me, or — after a restart — I still have to dial.
  Future<void> _beginCall(RealOffer offer, RealProfile other) async {
    if (!_callIdle(state)) return;
    if (offer.quick && offer.caller == null) {
      await _beginQuick(offer, other);
      return;
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
    switch (role) {
      case CallRole.iCall:
        unawaited(_dial());
        if (_driving(_now())) {
          _speak(
            state.prefs.speakNames
                ? _l.realVoiceCalling(other.name)
                : _l.realVoiceCallingAnon,
          );
        }
      case CallRole.theyCall:
        state = state.copyWith(callStage: CallStage.waitingForTheirCall);
        if (_driving(_now())) {
          _speak(
            state.prefs.speakNames
                ? _l.realVoiceTheyCall(other.name, _genderKey(other.gender))
                : _l.realVoiceTheyCallAnon,
          );
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
    _speak(
      state.prefs.speakNames
          ? _l.realVoiceQuick(other.name)
          : _l.realVoiceQuickAnon,
    );
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
      switch (r.state) {
        case CallStartState.ready:
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
      _endQuick(cancelledByOther: false);
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
    if (r == DialResult.failed || r == DialResult.unsupported) {
      // Couldn't open the phone: fall back to the in-app (simulated) call.
      _notify(RealNoticeKind.dialFailed);
      state = state.copyWith(callStage: CallStage.inApp);
    }
  }

  /// Quick connect: cancel during the 5 seconds (reaches the other side).
  Future<void> cancelCall() async {
    final call = state.call;
    if (call == null || state.callStage != CallStage.connecting) return;
    _stopVoice();
    state = state.copyWith(callStage: CallStage.none, call: null);
    await _quietly(() async {
      await _backend.cancelCall(call.offerId);
      await _backend.endCall(call.offerId);
    });
  }

  void finishCall() {
    _stopVoice();
    state = state.copyWith(callStage: CallStage.feedback);
  }

  /// After the call: it was good / not again soon / we didn't talk.
  Future<void> sendOutcome(CallOutcome outcome) async {
    final call = state.call;
    state = state.copyWith(callStage: CallStage.none, call: null);
    if (call == null) return;
    try {
      await _backend.sendCallOutcome(call.offerId, outcome);
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
                'circle': r.circleId ?? '',
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
  /// [quiet]: no pop-up about the result (the first-run screen shows it).
  Future<void> syncContacts({bool ask = true, bool quiet = false}) async {
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
    await _run(() async {
      final found = await _backend.syncContacts(saved.keys.toList());
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
    });
    if (ref.mounted) await refresh();
  }

  static const _seenMatchesKey = 'real.contactsSeen.v1';
  static const _localNamesKey = 'real.localNames.v1';

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
      'last refresh: ${time(snap?.fetchedAt)}',
      if (_refreshing) 'refreshing since: ${time(_refreshStarted)}',
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

/// Gender-neutral texts for everyone (D-073).
String _genderKey(Gender g) => 'other';

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
