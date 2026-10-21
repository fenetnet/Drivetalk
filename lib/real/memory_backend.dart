import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../domain/models.dart';
import 'contacts_hash.dart';
import 'real_backend.dart';
import 'real_models.dart';

/// In-memory stand-in for the Supabase backend, mirroring the SQL rules in
/// supabase/migrations (visibility, mutual acceptance, 15-minute cooldown
/// after a decline, blocks). Used by tests to run "two phones" in one process.
class MemoryServer {
  MemoryServer({DateTime Function()? now, Random? random})
    : now = now ?? DateTime.now,
      _random = random ?? Random.secure();

  DateTime Function() now;
  final Random _random;
  var _ids = 0;

  final profiles = <String, RealProfile>{};
  final invitations = <String, _Invitation>{};
  final connections = <String>{}; // "a|b" with a < b
  final availability = <String, RealAvailability>{};
  final offers = <String, _Offer>{};
  final blocks = <String>{}; // "blocker|blocked"
  final phones = <String, String>{};
  final deviceTokens = <String, String>{}; // token → user
  final wasConnected = <String>{}; // "blocker|blocked"
  final contactHashes = <String, Set<String>>{};

  /// Pairs one side removed: never suggested/added again from contacts.
  final removed = <String>{};

  /// Who removed each removed pair.
  final removedBy = <String, String>{};

  /// "owner|friend" → 0–5 (not set = 3).
  final ratings = <String, int>{};
  int ratingOf(String x, String y) => ratings['$x|$y'] ?? 3;

  /// Users who hide their status.
  final hidden = <String>{};

  /// When each user last opened the app; feedback notes to the owner.
  final lastSeen = <String, DateTime>{};
  final feedbackNotes = <String>[];
  final owners = <String>{};

  /// The owner's code on this test server (the real one lives only in the
  /// real server's database).
  String ownerCode = 'test-owner-code';

  /// Owner-code tries per account (the last hour's count).
  final ownerClaims = <String, List<DateTime>>{};

  /// Connect a pair (any way) — clears a past removal.
  void connect(String x, String y) {
    connections.add(_pair(x, y));
    removed.remove(_pair(x, y));
    removedBy.remove(_pair(x, y));
  }

  /// When each removed pair was removed.
  final removedAt = <String, DateTime>{};

  /// [x] disconnects from [y] (remove, block) — remembered, with who did it.
  void disconnect(String x, String y) {
    pendingFor.remove(_pair(x, y));
    quickPicks
      ..remove('$x|$y')
      ..remove('$y|$x');
    if (connections.remove(_pair(x, y))) {
      removed.add(_pair(x, y));
      removedBy[_pair(x, y)] = x;
      removedAt[_pair(x, y)] = now();
      // Like the server: out of each other's groups, open questions end.
      for (final e in circles.entries.toList()) {
        final (owner, c) = e.value;
        final other = owner == x ? y : (owner == y ? x : null);
        if (other == null || !c.memberIds.contains(other)) continue;
        circles[e.key] = (
          owner,
          RealCircle(
            id: c.id,
            name: c.name,
            quick: c.quick,
            memberIds: {...c.memberIds}..remove(other),
            showModes: c.showModes,
          ),
        );
      }
      final pair = _pair(x, y).split('|');
      _endOpen((o) => o.a == pair[0] && o.b == pair[1]);
    }
  }

  /// A quick connect that ends before it began: no pause, not a talk
  /// (like mark_app_call).
  void _undoQuick(_Offer o) {
    o.talked = null;
    final limit = (o.acceptedAt ?? now()).add(
      const Duration(days: 3, minutes: 1),
    );
    for (final k in ['${o.a}|${o.b}', '${o.b}|${o.a}']) {
      if (snoozes[k] case final u? when !u.isAfter(limit)) snoozes.remove(k);
    }
  }

  /// Open questions — and quick connects that haven't started — end
  /// (when availability ends, when friends part).
  void _endOpen(bool Function(_Offer o) which) {
    for (final o in offers.values) {
      if (!which(o)) continue;
      if (o.status == OfferStatus.pending) {
        o
          ..status = OfferStatus.cancelled
          ..updatedAt = now();
      } else if (o.status == OfferStatus.accepted &&
          o.quick &&
          o.caller == null) {
        o
          ..status = OfferStatus.cancelled
          ..updatedAt = now();
        _undoQuick(o);
      }
    }
  }

  final photos = <String, Uint8List>{};

  /// Measurements: (name, ms).
  final events = <(String, int?)>[];

  /// "Not again soon" after a call: "from|to" → until.
  final snoozes = <String, DateTime>{};

  bool _snoozed(String x, String y) => [
    snoozes['$x|$y'],
    snoozes['$y|$x'],
  ].any((u) => u != null && now().isBefore(u));

  /// Pauses someone chose after a call ("from|to"); the rest are automatic.
  final chosenSnoozes = <String>{};

  /// Quick-connect friends: only a chosen pause stops them (D-113).
  bool _snoozedForOffers(String x, String y, {required bool quick}) => !quick
      ? _snoozed(x, y)
      : ['$x|$y', '$y|$x'].any(
          (k) =>
              chosenSnoozes.contains(k) &&
              snoozes[k] != null &&
              now().isBefore(snoozes[k]!),
        );

  /// "from|to" → (created, until or null).
  final intents = <String, (DateTime, DateTime?)>{};

  bool _wantsToTalk(String x, String y) {
    bool one(String from, String to) {
      final i = intents['$from|$to'];
      if (i == null) return false;
      if (i.$2 != null && !now().isBefore(i.$2!)) return false;
      final last = _lastTalk(x, y);
      return last == null || !last.isAfter(i.$1);
    }

    return one(x, y) || one(y, x);
  }

  final feedback = <Map<String, Object?>>[];
  final reports = <Map<String, Object?>>[];

  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  void _changed() => _changes.add(null);

  String _newId(String prefix) =>
      '$prefix-${(++_ids).toString().padLeft(8, '0')}';

  static String _pair(String x, String y) =>
      x.compareTo(y) < 0 ? '$x|$y' : '$y|$x';

  bool connected(String x, String y) => connections.contains(_pair(x, y));
  bool blockedBetween(String x, String y) =>
      blocks.contains('$x|$y') || blocks.contains('$y|$x');

  // D-103…D-106: private settings (like the new profile columns).
  final anonymous = <String>{};
  final hideInCall = <String>{};

  /// Quiet-hours schedules (D-121, D-124).
  final quietRanges = <String, List<QuietRange>>{};
  final autoMissed = <String, int>{};

  /// Pair → the one who must decide (added from contacts).
  final pendingFor = <String, String>{};
  final crashes = <Map<String, String>>[];

  bool inQuietHours(String u) =>
      quietRanges[u]?.any((r) => r.covers(now())) ?? false;

  bool awaitsApproval(String owner, String viewer) =>
      pendingFor[_pair(owner, viewer)] == owner;
  bool pairPending(String x, String y) => pendingFor.containsKey(_pair(x, y));

  /// Can [u] get a question right now (their own side)?
  bool canBeAsked(String u) {
    final a = availability[u];
    if (a == null || !now().isBefore(a.expiresAt)) return false;
    if (a.missed || a.quietAt(now())) return false;
    if (autoSet.contains(u) && inQuietHours(u)) return false;
    return !_hasOpenOffer(u) && !_inCall(u) && !_onPhone(u);
  }

  /// Does [viewer] see [owner] free (apart from "without my name")?
  bool seesFree(String viewer, String owner) {
    final a = availability[owner];
    if (a == null || !now().isBefore(a.expiresAt) || a.missed) return false;
    final busy = busyUntil(owner);
    return connected(viewer, owner) &&
        !blockedBetween(viewer, owner) &&
        inAudience(a.circleId, viewer) &&
        canSee(viewer, owner, a.mode) &&
        !hidden.contains(owner) &&
        !hidden.contains(viewer) &&
        !awaitsApproval(owner, viewer) &&
        // Hiding in a call works both ways (D-114).
        !((hideInCall.contains(owner) || hideInCall.contains(viewer)) &&
            busy != null &&
            now().isBefore(busy));
  }

  /// Why [me] can't ask [user] right now ('ok' = can; like ask_check).
  String askCheck(String me, String user, {required bool meFree}) {
    final t = now();
    final mine = availability[me];
    if (meFree && (mine == null || !t.isBefore(mine.expiresAt))) {
      return 'me_not_free';
    }
    final theirs = availability[user];
    if (theirs == null ||
        user == me ||
        !seesFree(me, user) ||
        anonymous.contains(user) ||
        anonymous.contains(me) ||
        pairPending(me, user) ||
        ratingOf(user, me) == 0) {
      return 'not_free';
    }
    // My own settings never stop me tapping them (D-117).
    if (phones[me] == null && phones[user] == null) return 'no_number';
    if (!canBeAsked(user) || _askedEnough(user, theirs.startedAt)) {
      return 'busy';
    }
    final pair = _pair(me, user).split('|');
    final saidNo = offers.values.any(
      (o) =>
          o.a == pair[0] &&
          o.b == pair[1] &&
          ((o.status == OfferStatus.accepted &&
                  o.acceptedAt != null &&
                  !(o.endedA && o.endedB) &&
                  t.difference(o.acceptedAt!) < const Duration(minutes: 30)) ||
              // They already said no to us this time.
              (o.status == OfferStatus.declined &&
                  _answerOf(o, user) == false &&
                  !o.createdAt.isBefore(theirs.startedAt))),
    );
    return saidNo ? 'not_now' : 'ok';
  }

  /// A question ended without an answer from someone (after 30 seconds):
  /// they get no more questions and look not free until "still free".
  void _ended(_Offer o) {
    if (o.quick) return;
    if (o.updatedAt.difference(o.createdAt) < const Duration(seconds: 25)) {
      return;
    }
    for (final (u, answer) in [(o.a, o.aAccepted), (o.b, o.bAccepted)]) {
      if (answer != null) continue;
      final a = availability[u];
      if (a == null || a.missed || !now().isBefore(a.expiresAt)) continue;
      if (autoSet.contains(u)) autoMissed[u] = (autoMissed[u] ?? 0) + 1;
      availability[u] = a.withMarks(missedAt: now(), quietUntil: a.quietUntil);
    }
  }

  bool _activeAvail(String user) {
    final a = availability[user];
    return a != null && now().isBefore(a.expiresAt);
  }

  /// Circles: id → (owner, circle).
  final circles = <String, (String, RealCircle)>{};

  /// Quick connect is per person only (D-116).
  bool _isQuick(String x, String y) => quickPicks.contains('$x|$y');

  /// Push addresses (D-119): token → user.
  final pushTokens = <String, String>{};

  /// Turned off "tell my quick-connect friends when I'm on the way".
  final tripNotifyOff = <String>{};

  /// "owner|member" → when told.
  final tripPushes = <String, DateTime>{};

  /// Who is told "[owner] is on the way" now (like trip_push_claim); they
  /// are marked as told.
  List<String> tripPushClaim(String owner) {
    final mine = availability[owner];
    final t = now();
    if (mine == null ||
        !t.isBefore(mine.expiresAt) ||
        mine.mode != AvailabilityMode.driving ||
        mine.missed ||
        mine.quietAt(t) ||
        tripNotifyOff.contains(owner) ||
        anonymous.contains(owner) ||
        hidden.contains(owner)) {
      return const [];
    }
    final told = <String>[];
    for (final f in profiles.keys) {
      if (f == owner) continue;
      final last = tripPushes['$owner|$f'];
      final theirs = availability[f];
      if (_isQuick(owner, f) &&
          _isQuick(f, owner) &&
          seesFree(f, owner) &&
          !anonymous.contains(f) &&
          !inQuietHours(f) &&
          ratingOf(f, owner) != 0 &&
          !(theirs != null && t.isBefore(theirs.expiresAt)) &&
          !['$owner|$f', '$f|$owner'].any(
            (k) =>
                chosenSnoozes.contains(k) &&
                snoozes[k] != null &&
                t.isBefore(snoozes[k]!),
          ) &&
          (last == null || t.difference(last) > const Duration(hours: 20)) &&
          pushTokens.values.contains(f)) {
        tripPushes['$owner|$f'] = t;
        told.add(f);
      }
    }
    return told;
  }

  /// Quick connect per friend: "owner|member" (D-112).
  final quickPicks = <String>{};

  /// "Everyone else" rule per user (null / missing = always).
  final othersModes = <String, Set<AvailabilityMode>?>{};
  final presetsDone = <String>{};

  /// Does [viewer] see [owner] free in [mode]? (Like can_see on the server.)
  bool canSee(String viewer, String owner, AvailabilityMode mode) {
    final mine = [
      for (final c in circles.values)
        if (c.$1 == owner && c.$2.memberIds.contains(viewer)) c.$2,
    ];
    if (mine.isEmpty) {
      final o = othersModes[owner];
      return o == null || o.contains(mode);
    }
    return mine.every(
      (c) => c.showModes == null || c.showModes!.contains(mode),
    );
  }

  bool inAudience(String? circleId, String viewer) =>
      circleId == null ||
      (circles[circleId]?.$2.memberIds.contains(viewer) ?? false);

  bool _hasOpenOffer(String u) => offers.values.any(
    (o) =>
        o.status == OfferStatus.pending &&
        now().isBefore(o.expiresAt) &&
        (o.a == u || o.b == u),
  );

  /// Another phone call (the phone's background service says so).
  final phoneUntil = <String, DateTime>{};
  bool _onPhone(String u) => phoneUntil[u]?.isAfter(now()) ?? false;

  /// The phone says "in a call" (true) / "call ended" (false). A call
  /// closes my open questions (D-121).
  void phoneCall(String u, bool on) {
    // The phone call is over: so is my side of an agreed app call (D-131).
    if (!on && phoneUntil.containsKey(u)) {
      for (final o in offers.values) {
        if (o.status != OfferStatus.accepted || o.acceptedAt == null) continue;
        if (o.quick && (o.notBefore == null || o.notBefore!.isAfter(now()))) {
          continue;
        }
        if (o.a == u) o.endedA = true;
        if (o.b == u) o.endedB = true;
      }
    }
    if (on && availability.containsKey(u)) {
      phoneUntil[u] = now().add(const Duration(minutes: 3));
    } else {
      phoneUntil.remove(u);
    }
    if (on) {
      for (final o in offers.values) {
        if (o.status == OfferStatus.pending && (o.a == u || o.b == u)) {
          o
            ..status = OfferStatus.cancelled
            ..updatedAt = now();
        }
      }
    }
    _changed();
  }

  /// What friends see: in a call until then (null = not in a call).
  /// Like the server: a quick connect nobody saw counts 2 minutes; once
  /// both saw it, 20 minutes from then.
  DateTime? busyUntil(String u) {
    DateTime? until = _onPhone(u) ? phoneUntil[u] : null;
    for (final o in offers.values) {
      if (o.status == OfferStatus.accepted &&
          o.acceptedAt != null &&
          ((o.a == u && !o.endedA) || (o.b == u && !o.endedB))) {
        final end = o.quick && o.notBefore == null
            ? o.acceptedAt!.add(const Duration(minutes: 2))
            : (o.quick ? o.notBefore! : o.acceptedAt!).add(
                const Duration(minutes: 20),
              );
        if (end.isAfter(now()) && (until == null || end.isAfter(until))) {
          until = end;
        }
      }
    }
    return until;
  }

  /// In a call: agreed, not finished, not older than 20 minutes — and not
  /// a quick connect nobody saw (2 minutes) or nobody started (2 minutes
  /// after its countdown). Like the server's in_call.
  bool _inCall(String u, [String? except]) => offers.values.any(
    (o) =>
        o.status == OfferStatus.accepted &&
        o.id != except &&
        o.acceptedAt != null &&
        now().difference(o.acceptedAt!) < const Duration(minutes: 20) &&
        !(o.quick &&
            o.notBefore == null &&
            now().difference(o.acceptedAt!) > const Duration(minutes: 2)) &&
        !(o.quick &&
            o.caller == null &&
            o.notBefore != null &&
            now().difference(o.notBefore!) > const Duration(minutes: 2)) &&
        ((o.a == u && !o.endedA) || (o.b == u && !o.endedB)),
  );

  DateTime? _lastTalk(String x, String y) {
    final pair = _pair(x, y).split('|');
    DateTime? last;
    for (final o in offers.values) {
      if (o.a != pair[0] || o.b != pair[1]) continue;
      if (o.status != OfferStatus.accepted || o.acceptedAt == null) continue;
      if (o.talked != true) continue;
      if (last == null || o.acceptedAt!.isAfter(last)) last = o.acceptedAt;
    }
    return last;
  }

  /// ONE offer for this user (the best friend for now), like the server.
  void _createOffersFor(String user) {
    // A question nobody answered in time is over.
    for (final o in offers.values) {
      if (o.status == OfferStatus.pending && !now().isBefore(o.expiresAt)) {
        o
          ..status = OfferStatus.expired
          ..updatedAt = o.expiresAt;
        _ended(o);
      }
    }
    if (!_activeAvail(user)) return;
    if (!canBeAsked(user)) return;
    final mine = availability[user]!;
    // 5 quiet minutes after a question that didn't become a call; after 3
    // such questions in this window, no more.
    if (_quietGap(user) || _askedEnough(user, mine.startedAt)) return;
    bool mutualQuick(String o) => _isQuick(user, o) && _isQuick(o, user);
    final candidates = [
      for (final other in availability.keys)
        if (other != user &&
            _activeAvail(other) &&
            connected(user, other) &&
            !blockedBetween(user, other) &&
            !_snoozedForOffers(user, other, quick: mutualQuick(other)) &&
            !pairPending(user, other) &&
            ratingOf(user, other) > 0 &&
            ratingOf(other, user) > 0)
          other,
    ];
    // Quietly: quick-connect friends first, then least recently talked.
    candidates.sort((x, y) {
      final q = (mutualQuick(y) ? 1 : 0) - (mutualQuick(x) ? 1 : 0);
      if (q != 0) return q;
      // Friends who show their name first (D-103).
      final n =
          (anonymous.contains(x) ? 1 : 0) - (anonymous.contains(y) ? 1 : 0);
      if (n != 0) return n;
      final w =
          (_wantsToTalk(user, y) ? 1 : 0) - (_wantsToTalk(user, x) ? 1 : 0);
      if (w != 0) return w;
      // How much both want to talk (0–5 each, 3 when not set).
      final r =
          (ratingOf(user, y) + ratingOf(y, user)) -
          (ratingOf(user, x) + ratingOf(x, user));
      if (r != 0) return r;
      final tx = _lastTalk(user, x);
      final ty = _lastTalk(user, y);
      if (tx == null && ty != null) return -1;
      if (ty == null && tx != null) return 1;
      if (tx != null && ty != null && tx != ty) return tx.compareTo(ty);
      return x.compareTo(y);
    });
    for (final other in candidates) {
      final theirs = availability[other]!;
      if (!inAudience(mine.circleId, other) ||
          !inAudience(theirs.circleId, user) ||
          // Both must see each other; and someone must be able to dial.
          !canSee(other, user, mine.mode) ||
          !canSee(user, other, theirs.mode) ||
          (phones[user] == null && phones[other] == null) ||
          !canBeAsked(other) ||
          _quietGap(other) ||
          _askedEnough(other, theirs.startedAt)) {
        continue;
      }
      final pair = _pair(user, other).split('|');
      bool samePair(_Offer o) => o.a == pair[0] && o.b == pair[1];
      final since = now();
      final windowStart = mine.startedAt.isAfter(theirs.startedAt)
          ? mine.startedAt
          : theirs.startedAt;
      final blocking = offers.values.any(
        (o) =>
            samePair(o) &&
            ((o.status == OfferStatus.declined &&
                    since.difference(o.updatedAt) <
                        const Duration(minutes: 2)) ||
                (o.status == OfferStatus.accepted &&
                    o.acceptedAt != null &&
                    since.difference(o.acceptedAt!) <
                        const Duration(minutes: 30)) ||
                // Once per trip / free window for the same pair.
                (_endedWithoutCall(o) && !o.createdAt.isBefore(windowStart))),
      );
      if (blocking) continue;
      bool quickInWindow(String u, DateTime from) => offers.values.any(
        (o) => o.quick && (o.a == u || o.b == u) && !o.createdAt.isBefore(from),
      );
      final quick =
          mutualQuick(other) &&
          !offers.values.any(
            (o) =>
                samePair(o) &&
                o.quick &&
                since.difference(o.createdAt) < const Duration(days: 1),
          ) &&
          !quickInWindow(user, mine.startedAt) &&
          !quickInWindow(other, theirs.startedAt);
      // The automatic pause lets only quick connect through (D-113).
      if (!quick && _snoozed(user, other)) continue;
      final id = _newId('offer');
      var until = mine.expiresAt.isBefore(theirs.expiresAt)
          ? mine.expiresAt
          : theirs.expiresAt;
      // A question waits 30 seconds for answers, then it's over (D-139;
      // 5 more on the server, so the asker's own "no answer" comes first).
      final answerBy = since.add(const Duration(seconds: 35));
      if (!quick && answerBy.isBefore(until)) until = answerBy;
      offers[id] =
          _Offer(
              id: id,
              a: pair[0],
              b: pair[1],
              createdAt: since,
              updatedAt: since,
              expiresAt: until,
              quick: quick,
            )
            ..lastTalk = _lastTalk(user, other)
            ..sharedUntil = _sharedUntil(user, other);
      if (quick) {
        offers[id]!
          ..status = OfferStatus.accepted
          ..aAccepted = true
          ..bAccepted = true
          ..acceptedAt = since;
        _accepted(offers[id]!);
      }
      return;
    }
  }

  /// Both free until (automatic trips don't count: their end isn't known).
  DateTime? _sharedUntil(String x, String y) {
    final times = [
      for (final u in [x, y])
        if (!autoSet.contains(u) && availability[u] != null)
          availability[u]!.expiresAt,
    ];
    if (times.isEmpty) return null;
    return times.reduce((p, q) => p.isBefore(q) ? p : q);
  }

  static bool? _answerOf(_Offer o, String u) =>
      u == o.a ? o.aAccepted : o.bAccepted;

  static bool _endedWithoutCall(_Offer o) =>
      o.status == OfferStatus.declined ||
      o.status == OfferStatus.expired ||
      o.status == OfferStatus.cancelled;

  /// 3 questions for a free time; on an automatic trip one I didn't say
  /// yes to is enough.
  bool _askedEnough(String user, DateTime since) {
    final ended = offers.values.where(
      (o) =>
          (o.a == user || o.b == user) &&
          !o.quick &&
          !o.createdAt.isBefore(since) &&
          _endedWithoutCall(o),
    );
    if (autoSet.contains(user)) {
      return ended.any((o) => _answerOf(o, user) != true);
    }
    return ended.length >= 3;
  }

  /// 5 quiet minutes — only for whoever didn't say yes (D-104).
  bool _quietGap(String user) => offers.values.any(
    (o) =>
        (o.a == user || o.b == user) &&
        _endedWithoutCall(o) &&
        _answerOf(o, user) != true &&
        now().difference(o.updatedAt) < const Duration(minutes: 5),
  );

  /// Quick connect: a phone shows it. The 5 seconds start once both did.
  void markSeen(String offerId, String user) {
    final o = offers[offerId];
    if (o == null || !o.quick || o.status != OfferStatus.accepted) return;
    if (o.notBefore != null) return;
    if (user == o.a) o.seenA ??= now();
    if (user == o.b) o.seenB ??= now();
    if (o.seenA != null && o.seenB != null) {
      final last = o.seenA!.isAfter(o.seenB!) ? o.seenA! : o.seenB!;
      o.notBefore = last.add(const Duration(seconds: 5));
    }
    o.updatedAt = now();
    _changed();
  }

  bool cancelCallFor(String offerId, String user) {
    final o = offers[offerId];
    if (o == null || (o.a != user && o.b != user)) return false;
    if (!o.quick || o.status != OfferStatus.accepted) return false;
    if (o.notBefore != null && !now().isBefore(o.notBefore!)) return false;
    o
      ..status = OfferStatus.cancelled
      ..updatedAt = now();
    // Cancelled before it began: no pause (a longer one stays, as on the
    // server), and not a talk.
    _undoQuick(o);
    _changed();
    return true;
  }

  /// A call happened: a talk, and 3 quiet days for the pair (D-108).
  void _accepted(_Offer o) {
    o.talked ??= true;
    final until = now().add(const Duration(days: 3));
    for (final k in ['${o.a}|${o.b}', '${o.b}|${o.a}']) {
      final cur = snoozes[k];
      if (cur == null || cur.isBefore(until)) {
        snoozes[k] = until;
        chosenSnoozes.remove(k);
      }
    }
  }

  /// The background calls of the driving service (device token only).
  String autoStart(String token, {int minutes = 120}) {
    final me = deviceTokens[token];
    if (me == null) return 'bad_token';
    final cur = availability[me];
    if (cur != null && now().isBefore(cur.expiresAt) && !autoSet.contains(me)) {
      return 'already_available';
    }
    // A renewal extends the same trip (its start stays).
    final renewing =
        cur != null &&
        now().isBefore(cur.expiresAt) &&
        autoSet.contains(me) &&
        now().difference(cur.startedAt) < const Duration(minutes: 170);
    if (!renewing && inQuietHours(me)) return 'quiet_hours';
    final start = renewing ? cur.startedAt : now();
    var until = now().add(Duration(minutes: minutes.clamp(15, 180)));
    final cap = start.add(const Duration(hours: 3));
    if (until.isAfter(cap)) until = cap;
    availability[me] = RealAvailability(
      userId: me,
      mode: AvailabilityMode.driving,
      startedAt: start,
      expiresAt: until,
      auto: true,
      // A new trip: 5 quiet minutes first (D-106).
      missedAt: renewing ? cur.missedAt : null,
      quietUntil: renewing
          ? cur.quietUntil
          : now().add(const Duration(minutes: 5)),
    );
    autoSet.add(me);
    _createOffersFor(me);
    _changed();
    return 'available';
  }

  String autoStop(String token) {
    final me = deviceTokens[token];
    if (me == null) return 'bad_token';
    if (!autoSet.remove(me)) return 'nothing';
    availability.remove(me);
    _endOpen((o) => o.a == me || o.b == me);
    _changed();
    return 'stopped';
  }

  /// Users whose availability came from the driving detection.
  final autoSet = <String>{};

  /// Like the server's scheduled job.
  void expireStale() {
    final gone = {
      for (final e in availability.entries)
        if (!now().isBefore(e.value.expiresAt)) e.key,
    };
    availability.removeWhere((u, _) => gone.contains(u));
    _endOpen((o) => gone.contains(o.a) || gone.contains(o.b));
    for (final o in offers.values) {
      if (o.status == OfferStatus.pending && !now().isBefore(o.expiresAt)) {
        o
          ..status = OfferStatus.expired
          ..updatedAt = now();
        _ended(o);
      }
    }
    _changed();
  }

  String _token() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    return List.generate(22, (_) => chars[_random.nextInt(64)]).join();
  }
}

class _Invitation {
  _Invitation(this.token, this.inviter, this.expiresAt, this.createdAt);
  final String token;
  final String inviter;
  final DateTime expiresAt;
  final DateTime createdAt;
  String? acceptedBy;
}

class _Offer {
  _Offer({
    required this.id,
    required this.a,
    required this.b,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.quick = false,
  });
  final bool quick;
  final String id;
  final String a;
  final String b;
  final DateTime createdAt;
  DateTime updatedAt;
  final DateTime expiresAt;
  bool? aAccepted;
  bool? bAccepted;
  OfferStatus status = OfferStatus.pending;
  String? caller;
  DateTime? acceptedAt;
  DateTime? notBefore;
  String? laterFrom;
  DateTime? seenA;
  DateTime? seenB;
  DateTime? shownA;
  DateTime? shownB;
  bool endedA = false;
  bool endedB = false;
  bool? talked;
  DateTime? sharedUntil;
  DateTime? lastTalk;
  bool direct = false;

  RealOffer toReal() => RealOffer(
    id: id,
    userA: a,
    userB: b,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    expiresAt: expiresAt,
    aAccepted: aAccepted,
    bAccepted: bAccepted,
    caller: caller,
    notBefore: notBefore,
    laterFrom: laterFrom,
    quick: quick,
    sharedUntil: sharedUntil,
    lastTalk: lastTalk,
    direct: direct,
    acceptedAt: acceptedAt,
    endedA: endedA,
    endedB: endedB,
    shownA: shownA,
    shownB: shownB,
  );
}

/// One "phone" talking to a [MemoryServer].
class MemoryRealBackend implements RealBackend {
  MemoryRealBackend(this.server);
  final MemoryServer server;
  String? _me;

  /// Tests can make calls fail like a network error.
  bool offline = false;

  final _live = StreamController<LiveStatus>.broadcast();

  @override
  bool get isConfigured => true;

  @override
  String? get userId => _me;

  String get _uid {
    if (offline) throw const RealBackendException('offline');
    final me = _me;
    if (me == null) throw const RealBackendException('not_authenticated');
    return me;
  }

  @override
  Future<void> start() async {
    if (_me != null) _live.add(LiveStatus.connected);
  }

  @override
  Future<RealProfile> signIn(String name, Gender gender) async {
    if (offline) throw const RealBackendException('offline');
    _me ??= server._newId('user');
    return updateProfile(name, gender);
  }

  @override
  Future<RealProfile> updateProfile(String name, Gender gender) async {
    final me = _uid;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw const RealBackendException('invalid_name');
    }
    final p = RealProfile(
      id: me,
      name: trimmed,
      gender: gender,
      photoVersion: server.profiles[me]?.photoVersion ?? 0,
    );
    server.profiles[me] = p;
    server._changed();
    _live.add(LiveStatus.connected);
    return p;
  }

  @override
  Future<void> signOut() async {
    _me = null;
    _live.add(LiveStatus.disconnected);
  }

  @override
  Future<RealSnapshot> fetchSnapshot() async {
    final me = _uid;
    final now = server.now();
    final friends = [
      for (final p in server.profiles.values)
        if (p.id != me &&
            server.connected(me, p.id) &&
            !server.blockedBetween(me, p.id))
          p,
    ];
    final visible = {me, for (final f in friends) f.id};
    return RealSnapshot(
      me: server.profiles[me]!,
      friends: friends,
      availability: {
        for (final e in server.availability.entries)
          if (visible.contains(e.key) &&
              (e.key == me ||
                  (server.seesFree(me, e.key) &&
                      !server.anonymous.contains(e.key) &&
                      !server.anonymous.contains(me))))
            e.key: e.value.withBusy(
              server.busyUntil(e.key),
              phone: server._onPhone(e.key) ? server.phoneUntil[e.key] : null,
            ),
      },
      offers: [
        for (final o in server.offers.values)
          if (o.a == me || o.b == me) o.toReal(),
      ],
      circles: [
        for (final c in server.circles.values)
          if (c.$1 == me) c.$2,
      ],
      quickMine: {
        for (final f in friends)
          if (server._isQuick(me, f.id)) f.id,
      },
      quickTheirs: {
        for (final f in friends)
          if (server._isQuick(f.id, me)) f.id,
      },
      pauses: {
        for (final f in friends)
          if (server.snoozes['$me|${f.id}'] case final u?
              when server.now().isBefore(u))
            f.id: (
              until: u,
              chosen: server.chosenSnoozes.contains('$me|${f.id}'),
            ),
      },
      talks: [
        for (final o
            in server.offers.values.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
          if (o.status == OfferStatus.accepted &&
              o.talked == true &&
              (o.a == me || o.b == me))
            (o.a == me ? o.b : o.a, o.updatedAt),
      ],
      lastTalk: {
        for (final o
            in server.offers.values.toList()
              ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt)))
          if (o.status == OfferStatus.accepted &&
              o.talked == true &&
              (o.a == me || o.b == me))
            o.a == me ? o.b : o.a: o.updatedAt,
      },
      intents: {
        for (final e in server.intents.entries)
          if (e.key.startsWith('$me|') &&
              (e.value.$2 == null || now.isBefore(e.value.$2!)))
            e.key.split('|')[1]: TalkIntent(
              friendId: e.key.split('|')[1],
              until: e.value.$2,
            ),
      },
      ratings: {
        for (final f in friends)
          if (server.ratings.containsKey('$me|${f.id}'))
            f.id: server.ratingOf(me, f.id),
      },
      hidden: server.hidden.contains(me),
      othersModes: server.othersModes[me],
      askable: {
        for (final f in friends)
          if (server.askCheck(me, f.id, meFree: false) == 'ok') f.id,
      },
      status: MyStatus(
        anonymous: server.anonymous.contains(me),
        hideInCall: server.hideInCall.contains(me),
        tripNotify: !server.tripNotifyOff.contains(me),
        quietFrom: server.quietRanges[me]?.firstOrNull?.from,
        quietTo: server.quietRanges[me]?.firstOrNull?.to,
        quietDays: server.quietRanges[me]?.firstOrNull?.days,
        quietRanges: server.quietRanges[me] ?? const [],
        autoMissed: server.autoMissed[me] ?? 0,
        hiddenFree: [
          for (final f in friends)
            if (server.seesFree(me, f.id) &&
                (server.anonymous.contains(f.id) ||
                    server.anonymous.contains(me)) &&
                !(server.busyUntil(f.id)?.isAfter(now) ?? false))
              f,
        ].length,
        pending: {
          for (final e in server.pendingFor.entries)
            if (e.value == me) e.key.split('|').firstWhere((x) => x != me),
        },
      ),
      inactiveDays: {
        for (final f in friends)
          if (server.lastSeen[f.id] case final t?)
            f.id: now.difference(t).inDays,
      },
      fetchedAt: now,
    );
  }

  @override
  Stream<void> get changes => server.changes;

  @override
  Stream<LiveStatus> get liveStatus => _live.stream;

  /// How many times the app asked to reconnect (tests).
  var reconnects = 0;

  /// Instant updates stop (tests).
  void dropLive() => _live.add(LiveStatus.error);

  @override
  Future<void> reconnectLive() async {
    reconnects++;
    if (_me != null) _live.add(LiveStatus.connected);
  }

  @override
  Future<CreatedInvitation> createInvitation() async {
    final me = _uid;
    final token = server._token();
    final inv = _Invitation(
      token,
      me,
      server.now().add(const Duration(days: 7)),
      server.now(),
    );
    server.invitations[token] = inv;
    return CreatedInvitation(token, inv.expiresAt);
  }

  @override
  Future<InviteInfo> getInvitation(String token) async {
    if (offline) throw const RealBackendException('offline');
    final me = _me;
    final inv = server.invitations[token];
    if (inv == null) return const InviteInfo(InviteStatus.notFound);
    final p = server.profiles[inv.inviter]!;
    if (me == inv.inviter) {
      return InviteInfo(
        InviteStatus.own,
        inviterName: p.name,
        inviterGender: p.gender,
      );
    }
    if (me != null && server.connected(me, inv.inviter)) {
      return InviteInfo(
        InviteStatus.alreadyConnected,
        inviterName: p.name,
        inviterGender: p.gender,
      );
    }
    if (inv.acceptedBy != null) return const InviteInfo(InviteStatus.used);
    if (!server.now().isBefore(inv.expiresAt)) {
      return const InviteInfo(InviteStatus.expired);
    }
    return InviteInfo(
      InviteStatus.valid,
      inviterName: p.name,
      inviterGender: p.gender,
    );
  }

  @override
  Future<AcceptResult> acceptInvitation(String token) async {
    final me = _uid;
    final inv = server.invitations[token];
    if (inv == null) return AcceptResult.notFound;
    if (inv.inviter == me) return AcceptResult.own;
    if (server.connected(me, inv.inviter)) return AcceptResult.alreadyConnected;
    if (inv.acceptedBy != null) return AcceptResult.used;
    if (!server.now().isBefore(inv.expiresAt)) return AcceptResult.expired;
    if (server.blockedBetween(me, inv.inviter)) return AcceptResult.notFound;
    // They removed me after making this link: it doesn't bring me back.
    final pair = MemoryServer._pair(me, inv.inviter);
    if (server.removedBy[pair] == inv.inviter &&
        (server.removedAt[pair]?.isAfter(inv.createdAt) ?? false)) {
      return AcceptResult.expired;
    }
    server.connect(me, inv.inviter);
    inv.acceptedBy = me;
    server._createOffersFor(me);
    server._changed();
    return AcceptResult.accepted;
  }

  @override
  Future<void> setAvailability(
    AvailabilityMode mode,
    int minutes, {
    String? circleId,
  }) async {
    final me = _uid;
    if (circleId != null && server.circles[circleId]?.$1 != me) {
      throw const RealBackendException('invalid_circle');
    }
    if (minutes < 1 || minutes > 180) {
      throw const RealBackendException('invalid_minutes');
    }
    final now = server.now();
    server.autoSet.remove(me);
    server.availability[me] = RealAvailability(
      userId: me,
      mode: mode,
      startedAt: now,
      expiresAt: now.add(Duration(minutes: minutes)),
      circleId: circleId,
    );
    server._createOffersFor(me);
    server._changed();
  }

  @override
  Future<void> clearAvailability() async {
    final me = _uid;
    server.availability.remove(me);
    server.phoneUntil.remove(me);
    server._endOpen((o) => o.a == me || o.b == me);
    server._changed();
  }

  @override
  Future<OfferAnswer> declineLater(String offerId) async {
    final r = await answerOffer(offerId, accept: false);
    if (r.status == OfferStatus.declined) {
      server.offers[offerId]!
        ..laterFrom = _uid
        ..updatedAt = server.now();
      server._changed();
    }
    return r;
  }

  @override
  Future<Map<String, num?>> appStats(int days) async {
    if (!server.owners.contains(_uid)) {
      throw const RealBackendException('not_owner');
    }
    final since = server.now().subtract(Duration(days: days));
    final recent = [
      for (final o in server.offers.values)
        if (!o.createdAt.isBefore(since)) o,
    ];
    int count(bool Function(_Offer) f) => recent.where(f).length;
    return {
      'users': server.profiles.length,
      'friendships': server.connections.length,
      'offers': count((o) => !o.quick),
      'quick': count((o) => o.quick),
      'both_yes': count((o) => o.status == OfferStatus.accepted),
      'talked': count((o) => o.talked == true),
      'declined': count((o) => o.status == OfferStatus.declined),
      'later': count((o) => o.laterFrom != null),
      'no_answer': count((o) => o.status == OfferStatus.expired),
      'crashes': server.crashes.length,
    };
  }

  @override
  Future<OfferAnswer> answerOffer(
    String offerId, {
    required bool accept,
  }) async {
    final me = _uid;
    if (offline) throw const RealBackendException('offline');
    final o = server.offers[offerId];
    if (o == null || (o.a != me && o.b != me)) {
      throw const RealBackendException('not_found');
    }
    String? phoneOfOther() => server.phones[o.a == me ? o.b : o.a];
    if (o.status != OfferStatus.pending) {
      final ready =
          o.status == OfferStatus.accepted &&
          o.caller == me &&
          o.notBefore != null &&
          !server.now().isBefore(o.notBefore!);
      return OfferAnswer(
        o.status,
        iCall: o.caller == me,
        phone: ready ? phoneOfOther() : null,
      );
    }
    if (!server.now().isBefore(o.expiresAt) ||
        !server._activeAvail(o.a) ||
        !server._activeAvail(o.b)) {
      o
        ..status = OfferStatus.expired
        ..updatedAt = server.now();
      server._ended(o);
      server._changed();
      return OfferAnswer(o.status);
    }
    server.autoMissed.remove(me);
    // Withdrawing my yes (I stopped waiting) keeps it a yes (D-104).
    final withdrawn = !accept && MemoryServer._answerOf(o, me) == true;
    if (!withdrawn) {
      if (me == o.a) {
        o.aAccepted = accept;
      } else {
        o.bAccepted = accept;
      }
    }
    if (!accept) {
      o.status = OfferStatus.declined;
    } else if (o.aAccepted == true && o.bAccepted == true) {
      if (server._inCall(o.a, o.id) || server._inCall(o.b, o.id)) {
        o
          ..status = OfferStatus.expired
          ..updatedAt = server.now();
        server._changed();
        return OfferAnswer(o.status);
      }
      final other = o.a == me ? o.b : o.a;
      final onlyIShare =
          !server.phones.containsKey(other) && server.phones.containsKey(me);
      o
        ..status = OfferStatus.accepted
        ..caller = onlyIShare ? other : me
        ..acceptedAt = server.now()
        ..notBefore = server.now();
      server._accepted(o);
      for (final x in server.offers.values) {
        if (x.id != o.id &&
            x.status == OfferStatus.pending &&
            {x.a, x.b}.intersection({o.a, o.b}).isNotEmpty) {
          x
            ..status = OfferStatus.cancelled
            ..updatedAt = server.now();
        }
      }
    }
    o.updatedAt = server.now();
    if (o.status == OfferStatus.declined) server._ended(o);
    server._changed();
    final iCall = o.status == OfferStatus.accepted && o.caller == me;
    return OfferAnswer(
      o.status,
      iCall: iCall,
      phone: iCall ? phoneOfOther() : null,
    );
  }

  @override
  Future<void> seenCall(String offerId) async => server.markSeen(offerId, _uid);

  @override
  Future<void> offerShown(String offerId) async {
    final o = server.offers[offerId];
    if (o == null || o.status != OfferStatus.pending) return;
    if (o.a == _uid) o.shownA ??= server.now();
    if (o.b == _uid) o.shownB ??= server.now();
    o.updatedAt = server.now();
    server._changed();
  }

  @override
  Future<bool> cancelCall(String offerId) async {
    if (offline) throw const RealBackendException('offline');
    return server.cancelCallFor(offerId, _uid);
  }

  /// Tests: the next [failStartCalls] call starts fail like a network error.
  int failStartCalls = 0;

  @override
  Future<CallStart> startCall(String offerId) async {
    final me = _uid;
    if (offline) throw const RealBackendException('offline');
    if (failStartCalls > 0) {
      failStartCalls--;
      throw const RealBackendException('offline');
    }
    final o = server.offers[offerId];
    if (o == null || (o.a != me && o.b != me)) {
      return const CallStart(CallStartState.gone);
    }
    if (o.status == OfferStatus.cancelled) {
      return const CallStart(CallStartState.cancelled);
    }
    if (o.status != OfferStatus.accepted ||
        server.blockedBetween(o.a, o.b) ||
        !server.connected(o.a, o.b)) {
      return const CallStart(CallStartState.gone);
    }
    if (o.notBefore == null) server.markSeen(o.id, me);
    final now = server.now();
    if (o.notBefore == null || now.isBefore(o.notBefore!)) {
      final wait = o.notBefore == null
          ? 1000
          : o.notBefore!.difference(now).inMilliseconds.clamp(100, 60000);
      return CallStart(CallStartState.wait, waitMs: wait);
    }
    // Nobody started it while its countdown was fresh: it just ends.
    if (o.quick &&
        o.caller == null &&
        now.difference(o.notBefore!) > const Duration(minutes: 2)) {
      o
        ..status = OfferStatus.cancelled
        ..updatedAt = now;
      server._undoQuick(o);
      server._changed();
      return const CallStart(CallStartState.gone);
    }
    if (o.caller == null) {
      // Like the server: the caller needs the other's number — if only I
      // shared one, they call me.
      final other = o.a == me ? o.b : o.a;
      o
        ..caller = server.phones[other] == null && server.phones[me] != null
            ? other
            : me
        ..updatedAt = now;
      server._changed();
    }
    final iCall = o.caller == me;
    return CallStart(
      CallStartState.ready,
      iCall: iCall,
      phone: iCall ? server.phones[o.a == me ? o.b : o.a] : null,
    );
  }

  @override
  Future<void> endCall(String offerId) async {
    final me = _uid;
    final o = server.offers[offerId];
    if (o == null) return;
    if (o.a == me) o.endedA = true;
    if (o.b == me) o.endedB = true;
    o.updatedAt = server.now();
    server._changed();
  }

  @override
  Future<void> afterCall(
    String offerId, {
    required int days,
    required bool talked,
  }) async {
    final me = _uid;
    if (offline) throw const RealBackendException('offline');
    final o = server.offers[offerId];
    if (o == null ||
        (o.a != me && o.b != me) ||
        o.status != OfferStatus.accepted) {
      throw const RealBackendException('not_found');
    }
    final other = o.a == me ? o.b : o.a;
    server.feedback.removeWhere((f) => f['user'] == me && f['offer'] == o.id);
    server.feedback.add({
      'user': me,
      'offer': o.id,
      'talked': talked,
      'days': days,
    });
    o.talked = talked;
    if (o.a == me) o.endedA = true;
    if (o.b == me) o.endedB = true;
    if (days == 0) {
      server.snoozes.remove('$me|$other');
      server.chosenSnoozes.remove('$me|$other');
      // "Any time": the automatic pause on their side goes too.
      if (!server.chosenSnoozes.contains('$other|$me')) {
        server.snoozes.remove('$other|$me');
      }
    } else {
      server.snoozes['$me|$other'] = server.now().add(Duration(days: days));
      server.chosenSnoozes.add('$me|$other');
    }
    o.updatedAt = server.now();
    server._changed();
  }

  @override
  Future<String?> getMyPhone() async => server.phones[_uid];

  @override
  Future<void> setMyPhone(String? phone) async {
    final me = _uid;
    if (phone == null) {
      server.phones.remove(me);
    } else {
      final n = normalizePhone(phone);
      if (n == null) throw const RealBackendException('invalid_phone');
      server.phones[me] = n;
    }
  }

  @override
  Future<String> contactCheck(String hash) async {
    final me = _uid;
    if (hashPhone(server.phones[me] ?? '') == hash) return 'me';
    final other = server.phones.entries
        .where((e) => e.key != me && hashPhone(e.value) == hash)
        .map((e) => e.key)
        .lastOrNull;
    if (other == null) return 'not_user';
    if (server.blockedBetween(me, other)) return 'blocked';
    if (server.connected(me, other)) return 'friend';
    if (server.removed.contains(MemoryServer._pair(me, other))) {
      return 'removed';
    }
    return 'user';
  }

  @override
  Future<List<ContactMatch>> syncContacts(List<String> hashes) async {
    final me = _uid;
    // Only numbers of DriveTalk users are kept; the rest is dropped.
    final users = {
      for (final e in server.phones.entries)
        if (e.key != me) hashPhone(e.value),
    };
    server.contactHashes[me] = {
      for (final h in hashes)
        if (users.contains(h)) h,
    };
    // Whoever added me and is in my contacts: kept (I know them).
    server.pendingFor.removeWhere((pair, who) {
      if (who != me) return false;
      final other = pair.split('|').firstWhere((x) => x != me);
      final phone = server.phones[other];
      return phone != null &&
          server.contactHashes[me]!.contains(hashPhone(phone));
    });
    return _rows(me);
  }

  /// My contacts who use DriveTalk: one account per number (a friend
  /// first, else the most recently joined). Connects nobody.
  List<ContactMatch> _rows(String me) {
    final mine = server.contactHashes[me] ?? const <String>{};
    final byHash = <String, ContactMatch>{};
    for (final e in server.phones.entries) {
      final h = hashPhone(e.value);
      if (e.key == me || h == null || !mine.contains(h)) continue;
      if (server.blockedBetween(me, e.key)) continue;
      final friend = server.connected(me, e.key);
      final row = ContactMatch(
        e.key,
        server.profiles[e.key]!.name,
        hash: h,
        isFriend: friend,
      );
      // A friend wins; otherwise the newer account (later in the map).
      if (byHash[h]?.isFriend != true) byHash[h] = row;
    }
    return [
      for (final r in byHash.values)
        if (r.isFriend ||
            !server.removed.contains(MemoryServer._pair(me, r.id)))
          r,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ContactMatch> _matches(String me) => [
    for (final r in _rows(me))
      if (!r.isFriend) r,
  ];

  @override
  Future<List<String>> addContacts(List<String> userIds) async {
    final me = _uid;
    final names = <String>[];
    for (final m in _matches(me)) {
      if (!userIds.contains(m.id)) continue;
      server.connect(me, m.id);
      // They don't have my number saved (as far as we know): they decide.
      final mine = server.phones[me];
      if (mine == null ||
          !(server.contactHashes[m.id]?.contains(hashPhone(mine)) ?? false)) {
        server.pendingFor[MemoryServer._pair(me, m.id)] = m.id;
      }
      names.add(m.name);
    }
    server._createOffersFor(me);
    server._changed();
    return names;
  }

  @override
  Future<List<ContactMatch>> removedFriends() async {
    final me = _uid;
    return [
      for (final pair in server.removed)
        if (pair.split('|').contains(me) && server.removedBy[pair] == me)
          if (pair.split('|').firstWhere((u) => u != me) case final other
              when !server.blockedBetween(me, other) &&
                  server.profiles.containsKey(other))
            ContactMatch(other, server.profiles[other]!.name),
    ];
  }

  @override
  Future<bool> restoreFriend(String userId) async {
    final me = _uid;
    final pair = MemoryServer._pair(me, userId);
    if (server.removedBy[pair] != me || server.blockedBetween(me, userId)) {
      return false;
    }
    server.connect(me, userId);
    server._createOffersFor(me);
    server._changed();
    return true;
  }

  @override
  Future<void> setRating(String friendId, int rating) async {
    final me = _uid;
    if (rating < 0 || rating > 5) throw const RealBackendException('unknown');
    if (!server.connected(me, friendId)) {
      throw const RealBackendException('not_connected');
    }
    server.ratings['$me|$friendId'] = rating;
    server._createOffersFor(me);
    server._changed();
  }

  @override
  Future<void> clearPause(String userId) async {
    final me = _uid;
    server.snoozes.remove('$me|$userId');
    server.chosenSnoozes.remove('$me|$userId');
    if (!server.chosenSnoozes.contains('$userId|$me')) {
      server.snoozes.remove('$userId|$me');
    }
    server._createOffersFor(me);
    server._changed();
  }

  @override
  Future<void> setQuick(String userId, bool on) async {
    final me = _uid;
    if (on) {
      if (!server.connected(me, userId) || server.blockedBetween(me, userId)) {
        throw const RealBackendException('not_found');
      }
      server.quickPicks.add('$me|$userId');
      server._createOffersFor(me);
    } else {
      server.quickPicks.remove('$me|$userId');
    }
    server._changed();
  }

  @override
  Future<void> setOthersVisibility(Set<AvailabilityMode>? modes) async {
    if (offline) throw const RealBackendException('offline');
    server.othersModes[_uid] = modes == null ? null : {...modes};
    server._changed();
  }

  @override
  Future<void> ensurePresetCircles(List<String> names) async {
    final me = _uid;
    if (!server.presetsDone.add(me)) return;
    for (final n in names.take(5)) {
      final name = n.trim();
      if (name.isEmpty || name.length > 30) continue;
      if (server.circles.values.any((c) => c.$1 == me && c.$2.name == name)) {
        continue;
      }
      final id = server._newId('circle');
      server.circles[id] = (me, RealCircle(id: id, name: name, memberIds: {}));
    }
    server._changed();
  }

  @override
  Future<void> setHideStatus(bool hide) async {
    final me = _uid;
    hide ? server.hidden.add(me) : server.hidden.remove(me);
    server._changed();
  }

  @override
  Future<void> savePushToken(String token, {int? build}) async {
    server.pushTokens[token] = _uid;
  }

  @override
  Future<void> forgetPushToken(String token) async {
    if (server.pushTokens[token] == _uid) server.pushTokens.remove(token);
  }

  @override
  Future<void> setTripNotify(bool on) async {
    on ? server.tripNotifyOff.remove(_uid) : server.tripNotifyOff.add(_uid);
    server._changed();
  }

  /// Who was told by my last [notifyTrip] (tests).
  List<String> lastTripTold = const [];

  @override
  Future<String> testPush() async =>
      server.pushTokens.values.contains(_uid) ? 'sent' : 'no_token';

  @override
  Future<void> notifyTrip() async {
    lastTripTold = server.tripPushClaim(_uid);
  }

  @override
  Future<String> createDeviceToken() async {
    final me = _uid;
    server.deviceTokens.removeWhere((_, u) => u == me);
    final t = '${server._token()}${server._token()}';
    server.deviceTokens[t] = me;
    return t;
  }

  @override
  Future<void> revokeDeviceTokens() async {
    final me = _uid;
    server.deviceTokens.removeWhere((_, u) => u == me);
  }

  @override
  Future<void> nudgeOffers() async {
    server._createOffersFor(_uid);
    server._changed();
  }

  @override
  Future<List<RealProfile>> blockedPeople() async {
    final me = _uid;
    return [
      for (final b in server.blocks)
        if (b.startsWith('$me|')) server.profiles[b.split('|')[1]]!,
    ];
  }

  @override
  Future<bool> unblock(String userId) async {
    final me = _uid;
    if (!server.blocks.remove('$me|$userId')) return false;
    final was = server.wasConnected.remove('$me|$userId');
    if (was && !server.blockedBetween(me, userId)) {
      server.connect(me, userId);
      server._changed();
      return true;
    }
    server._changed();
    return false;
  }

  @override
  Future<RealCircle> saveCircle(RealCircle circle) async {
    final me = _uid;
    final name = circle.name.trim();
    if (name.isEmpty || name.length > 30) {
      throw const RealBackendException('invalid_name');
    }
    if (circle.id.isNotEmpty && server.circles[circle.id]?.$1 != me) {
      throw const RealBackendException('not_allowed');
    }
    if (circle.memberIds.any((m) => !server.connected(me, m))) {
      throw const RealBackendException('not_allowed');
    }
    final id = circle.id.isEmpty ? server._newId('circle') : circle.id;
    // Like the server (D-116): a group isn't "quick" — an older app's
    // "quick group" turns into the per-person switch for its members.
    if (circle.quick) {
      for (final m in circle.memberIds) {
        server.quickPicks.add('$me|$m');
      }
    }
    final saved = RealCircle(
      id: id,
      name: name,
      memberIds: {...circle.memberIds},
      showModes: circle.showModes,
    );
    server.circles[id] = (me, saved);
    server._changed();
    return saved;
  }

  @override
  Future<void> deleteCircle(String circleId) async {
    final me = _uid;
    if (server.circles[circleId]?.$1 == me) {
      server.circles.remove(circleId);
      // Like the server: free time only for that group ends with it.
      final gone = {
        for (final e in server.availability.entries)
          if (e.value.circleId == circleId) e.key,
      };
      server.availability.removeWhere((u, _) => gone.contains(u));
      server._endOpen((o) => gone.contains(o.a) || gone.contains(o.b));
      server._changed();
    }
  }

  @override
  Future<void> setPhoto(Uint8List? jpeg) async {
    final me = _uid;
    if (offline) throw const RealBackendException('offline');
    final p = server.profiles[me]!;
    if (jpeg == null) {
      server.photos.remove(me);
    } else {
      server.photos[me] = jpeg;
    }
    server.profiles[me] = RealProfile(
      id: me,
      name: p.name,
      gender: p.gender,
      photoVersion: jpeg == null ? 0 : p.photoVersion + 1,
    );
    server._changed();
  }

  @override
  Future<Uint8List?> downloadPhoto(String userId) async {
    final me = _uid;
    if (offline) return null;
    final allowed =
        userId == me ||
        (server.connected(me, userId) && !server.blockedBetween(me, userId));
    return allowed ? server.photos[userId] : null;
  }

  @override
  Future<void> setTalkIntent(String userId, DateTime? until) async {
    final me = _uid;
    if (!server.connected(me, userId)) {
      throw const RealBackendException('not_connected');
    }
    server.intents['$me|$userId'] = (server.now(), until);
    server._changed();
  }

  @override
  Future<void> clearTalkIntent(String userId) async {
    server.intents.remove('$_uid|$userId');
    server._changed();
  }

  @override
  Map<String, bool> get realtimeTables => const {};

  /// Tests can pretend the server is older.
  int schema = 27;

  @override
  Future<int> schemaVersion() async => schema;

  @override
  Future<void> clearContactHashes() async {
    server.contactHashes.remove(_uid);
  }

  @override
  Future<void> deleteAccount() async {
    final me = _uid;
    if (offline) throw const RealBackendException('offline');
    server.profiles.remove(me);
    server.phones.remove(me);
    server.photos.remove(me);
    server.availability.remove(me);
    server.contactHashes.remove(me);
    server.removed.removeWhere((k) => k.split('|').contains(me));
    server.ratings.removeWhere((k, _) => k.split('|').contains(me));
    server.hidden.remove(me);
    server.othersModes.remove(me);
    server.presetsDone.remove(me);
    server.deviceTokens.removeWhere((_, u) => u == me);
    server.connections.removeWhere((c) => c.split('|').contains(me));
    server.offers.removeWhere((_, o) => o.a == me || o.b == me);
    server.circles.removeWhere((_, c) => c.$1 == me);
    for (final e in server.circles.entries.toList()) {
      if (e.value.$2.memberIds.contains(me)) {
        final c = e.value.$2;
        server.circles[e.key] = (
          e.value.$1,
          RealCircle(
            id: c.id,
            name: c.name,
            quick: c.quick,
            memberIds: {...c.memberIds}..remove(me),
          ),
        );
      }
    }
    server.intents.removeWhere((k, _) => k.split('|').contains(me));
    server._changed();
    _me = null;
  }

  @override
  Future<bool> claimOwner(String code) async {
    // Like the server: 5 tries an hour per account (D-110).
    final since = server.now().subtract(const Duration(hours: 1));
    final tries = server.ownerClaims.putIfAbsent(_uid, () => [])
      ..removeWhere((t) => t.isBefore(since));
    if (tries.length >= 5) throw const RealBackendException('rate_limited');
    tries.add(server.now());
    final ok = code.trim() == server.ownerCode;
    if (ok) server.owners.add(_uid);
    return ok;
  }

  @override
  Future<List<OwnerNote>> ownerFeedback() async {
    if (!server.owners.contains(_uid)) {
      throw const RealBackendException('not_owner');
    }
    return [
      for (final n in server.feedbackNotes.reversed)
        OwnerNote(server.now(), '—', n),
    ];
  }

  @override
  Future<List<OwnerNote>> ownerReports() async {
    if (!server.owners.contains(_uid)) {
      throw const RealBackendException('not_owner');
    }
    String name(Object? id) => server.profiles[id]?.name ?? '—';
    return [
      for (final r in server.reports.reversed)
        OwnerNote(
          server.now(),
          '${name(r['reporter'])} → ${name(r['reported'])}',
          '${r['reason']}',
        ),
    ];
  }

  @override
  Future<List<OwnerNote>> ownerCrashes() async {
    if (!server.owners.contains(_uid)) {
      throw const RealBackendException('not_owner');
    }
    return [
      for (final c in server.crashes.reversed)
        OwnerNote(
          server.now(),
          '${c['kind']} · ${c['build']}',
          '${c['message']}',
        ),
    ];
  }

  @override
  Future<void> reportCrash({
    required String build,
    required String kind,
    required String message,
    required String stack,
  }) async {
    _uid;
    server.crashes.add({
      'build': build,
      'kind': kind,
      'message': message,
      'stack': stack,
    });
  }

  @override
  Future<String> askFriend(String userId) async {
    final me = _uid;
    final now = server.now();
    final why = server.askCheck(me, userId, meFree: true);
    if (why != 'ok') return why;
    final mine = server.availability[me]!;
    final theirs = server.availability[userId]!;
    final pair = MemoryServer._pair(me, userId).split('|');
    for (final o in server.offers.values) {
      if (o.status == OfferStatus.pending && (o.a == me || o.b == me)) {
        o
          ..status = OfferStatus.cancelled
          ..updatedAt = now;
      }
    }
    final id = server._newId('offer');
    var until = mine.expiresAt.isBefore(theirs.expiresAt)
        ? mine.expiresAt
        : theirs.expiresAt;
    final answerBy = now.add(const Duration(seconds: 35));
    if (answerBy.isBefore(until)) until = answerBy;
    server.offers[id] =
        _Offer(
            id: id,
            a: pair[0],
            b: pair[1],
            createdAt: now,
            updatedAt: now,
            expiresAt: until,
          )
          ..direct = true
          ..lastTalk = server._lastTalk(me, userId)
          ..sharedUntil = server._sharedUntil(me, userId);
    if (me == pair[0]) {
      server.offers[id]!.aAccepted = true;
    } else {
      server.offers[id]!.bAccepted = true;
    }
    server._changed();
    return 'asked';
  }

  @override
  Future<bool> stillFree() async {
    final me = _uid;
    final a = server.availability[me];
    if (a == null || !a.missed || !server.now().isBefore(a.expiresAt)) {
      return false;
    }
    server.availability[me] = a.withMarks(
      missedAt: null,
      quietUntil: a.quietUntil,
    );
    server._createOffersFor(me);
    server._changed();
    return true;
  }

  @override
  Future<bool> readyNow() async {
    final me = _uid;
    final a = server.availability[me];
    if (a == null || !a.quietAt(server.now())) return false;
    server.availability[me] = a.withMarks(
      missedAt: a.missedAt,
      quietUntil: null,
    );
    server._createOffersFor(me);
    server._changed();
    return true;
  }

  @override
  Future<void> keepAuto() async => server.autoMissed.remove(_uid);

  @override
  Future<DateTime?> extendAvailability(int minutes) async {
    final me = _uid;
    if (minutes < 1 || minutes > 180) {
      throw const RealBackendException('invalid_minutes');
    }
    final a = server.availability[me];
    if (a == null ||
        server.autoSet.contains(me) ||
        !server.now().isBefore(a.expiresAt)) {
      return null;
    }
    var until = a.expiresAt.add(Duration(minutes: minutes));
    final cap = a.startedAt.add(const Duration(hours: 3));
    if (until.isAfter(cap)) until = cap;
    server.availability[me] = a.withMarks(
      missedAt: a.missedAt,
      quietUntil: a.quietUntil,
      expiresAt: until,
    );
    server._changed();
    return until;
  }

  @override
  Future<void> setSettings({
    bool? anonymous,
    bool? hideInCall,
    int? quietFrom,
    int? quietTo,
    int? quietDays,
    bool clearQuiet = false,
    String? timeZone,
  }) async {
    final me = _uid;
    void flag(Set<String> s, bool? on) {
      if (on == true) s.add(me);
      if (on == false) s.remove(me);
    }

    flag(server.anonymous, anonymous);
    flag(server.hideInCall, hideInCall);
    // Like an older app: one range, which replaces the list.
    if (clearQuiet) {
      server.quietRanges.remove(me);
    } else if (quietFrom != null || quietTo != null || quietDays != null) {
      final cur = server.quietRanges[me]?.firstOrNull;
      final days = quietDays ?? cur?.days;
      server.quietRanges[me] = [
        QuietRange(
          quietFrom ?? cur?.from ?? 0,
          quietTo ?? cur?.to ?? 0,
          days == null || days <= 0 || days >= 127 ? null : days,
        ),
      ];
    }
    server._changed();
  }

  @override
  Future<void> setQuietRanges(
    List<QuietRange> ranges, {
    String? timeZone,
  }) async {
    if (ranges.length > 4) throw RealBackendException('bad');
    final me = _uid;
    if (ranges.isEmpty) {
      server.quietRanges.remove(me);
    } else {
      server.quietRanges[me] = [
        for (final r in ranges)
          QuietRange(r.from, r.to, r.everyDay ? null : r.days),
      ];
    }
    server._changed();
  }

  @override
  Future<bool> approveFriend(String userId) async {
    final me = _uid;
    final pair = MemoryServer._pair(me, userId);
    if (server.pendingFor[pair] != me) return false;
    server.pendingFor.remove(pair);
    server._createOffersFor(me);
    server._changed();
    return true;
  }

  @override
  Future<void> touchSeen() async => server.lastSeen[_uid] = server.now();

  @override
  Future<void> sendFeedback(String text, {int? build}) async =>
      server.feedbackNotes.add(text);

  @override
  Future<void> logEvent(String name, {int? ms}) async =>
      server.events.add((name, ms));

  @override
  Future<void> block(String userId) async {
    final me = _uid;
    if (userId == me) return;
    if (server.connected(me, userId)) server.wasConnected.add('$me|$userId');
    for (final c in server.circles.values) {
      if (c.$1 == me) c.$2.memberIds.remove(userId);
    }
    server.blocks.add('$me|$userId');
    server.disconnect(me, userId);
    for (final o in server.offers.values) {
      if (o.status == OfferStatus.pending &&
          {o.a, o.b}.containsAll([me, userId])) {
        o
          ..status = OfferStatus.cancelled
          ..updatedAt = server.now();
      }
    }
    server._changed();
  }

  @override
  Future<void> unmatch(String userId) async {
    final me = _uid;
    server.disconnect(me, userId);
    server._changed();
  }

  @override
  Future<void> report(String userId, ReportReason reason) async {
    server.reports.add({
      'reporter': _uid,
      'reported': userId,
      'reason': reason.name,
    });
  }
}
