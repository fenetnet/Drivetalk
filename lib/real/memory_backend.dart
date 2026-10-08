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

  /// Connect a pair (any way) — clears a past removal.
  void connect(String x, String y) {
    connections.add(_pair(x, y));
    removed.remove(_pair(x, y));
    removedBy.remove(_pair(x, y));
  }

  /// [x] disconnects from [y] (remove, block) — remembered, with who did it.
  void disconnect(String x, String y) {
    if (connections.remove(_pair(x, y))) {
      removed.add(_pair(x, y));
      removedBy[_pair(x, y)] = x;
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

  bool _activeAvail(String user) {
    final a = availability[user];
    return a != null && now().isBefore(a.expiresAt);
  }

  /// Circles: id → (owner, circle).
  final circles = <String, (String, RealCircle)>{};

  bool _isQuick(String x, String y) => circles.values.any(
    (c) => c.$1 == x && c.$2.quick && c.$2.memberIds.contains(y),
  );

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

  /// The phone says "in a call" (true) / "call ended" (false).
  void phoneCall(String u, bool on) {
    if (on && availability.containsKey(u)) {
      phoneUntil[u] = now().add(const Duration(minutes: 3));
    } else {
      phoneUntil.remove(u);
    }
    _changed();
  }

  /// What friends see: in a call until then (null = not in a call).
  DateTime? busyUntil(String u) {
    DateTime? until = _onPhone(u) ? phoneUntil[u] : null;
    for (final o in offers.values) {
      if (o.status == OfferStatus.accepted &&
          o.acceptedAt != null &&
          ((o.a == u && !o.endedA) || (o.b == u && !o.endedB))) {
        final end = o.acceptedAt!.add(const Duration(minutes: 20));
        if (end.isAfter(now()) && (until == null || end.isAfter(until))) {
          until = end;
        }
      }
    }
    return until;
  }

  /// In a call: agreed, not finished, not older than 20 minutes.
  bool _inCall(String u, [String? except]) => offers.values.any(
    (o) =>
        o.status == OfferStatus.accepted &&
        o.id != except &&
        o.acceptedAt != null &&
        now().difference(o.acceptedAt!) < const Duration(minutes: 20) &&
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
      }
    }
    if (!_activeAvail(user)) return;
    if (_hasOpenOffer(user) || _inCall(user) || _onPhone(user)) return;
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
            !_snoozed(user, other) &&
            ratingOf(user, other) > 0 &&
            ratingOf(other, user) > 0)
          other,
    ];
    // Quietly: quick-connect friends first, then least recently talked.
    candidates.sort((x, y) {
      final q = (mutualQuick(y) ? 1 : 0) - (mutualQuick(x) ? 1 : 0);
      if (q != 0) return q;
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
          _hasOpenOffer(other) ||
          _inCall(other) ||
          _onPhone(other) ||
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
      final id = _newId('offer');
      var until = mine.expiresAt.isBefore(theirs.expiresAt)
          ? mine.expiresAt
          : theirs.expiresAt;
      // A question waits 2 minutes for answers, then it's over.
      final answerBy = since.add(const Duration(minutes: 2));
      if (!quick && answerBy.isBefore(until)) until = answerBy;
      offers[id] = _Offer(
        id: id,
        a: pair[0],
        b: pair[1],
        createdAt: since,
        updatedAt: since,
        expiresAt: until,
        quick: quick,
      );
      if (quick) {
        offers[id]!
          ..status = OfferStatus.accepted
          ..aAccepted = true
          ..bAccepted = true
          ..acceptedAt = since;
      }
      return;
    }
  }

  static bool _endedWithoutCall(_Offer o) =>
      o.status == OfferStatus.declined ||
      o.status == OfferStatus.expired ||
      o.status == OfferStatus.cancelled;

  bool _askedEnough(String user, DateTime since) =>
      offers.values
          .where(
            (o) =>
                (o.a == user || o.b == user) &&
                !o.quick &&
                !o.createdAt.isBefore(since) &&
                _endedWithoutCall(o),
          )
          .length >=
      3;

  bool _quietGap(String user) => offers.values.any(
    (o) =>
        (o.a == user || o.b == user) &&
        _endedWithoutCall(o) &&
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
    _changed();
    return true;
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
    final start = renewing ? cur.startedAt : now();
    var until = now().add(Duration(minutes: minutes.clamp(15, 180)));
    final cap = start.add(const Duration(hours: 3));
    if (until.isAfter(cap)) until = cap;
    availability[me] = RealAvailability(
      userId: me,
      mode: AvailabilityMode.driving,
      startedAt: start,
      expiresAt: until,
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
    for (final o in offers.values) {
      if (o.status == OfferStatus.pending && (o.a == me || o.b == me)) {
        o
          ..status = OfferStatus.cancelled
          ..updatedAt = now();
      }
    }
    _changed();
    return 'stopped';
  }

  /// Users whose availability came from the driving detection.
  final autoSet = <String>{};

  /// Like the server's scheduled job.
  void expireStale() {
    availability.removeWhere((_, a) => !now().isBefore(a.expiresAt));
    for (final o in offers.values) {
      if (o.status == OfferStatus.pending && !now().isBefore(o.expiresAt)) {
        o
          ..status = OfferStatus.expired
          ..updatedAt = now();
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
  _Invitation(this.token, this.inviter, this.expiresAt);
  final String token;
  final String inviter;
  final DateTime expiresAt;
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
  bool endedA = false;
  bool endedB = false;
  bool? talked;

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
                  (now.isBefore(e.value.expiresAt) &&
                      server.inAudience(e.value.circleId, me) &&
                      !server.hidden.contains(e.key) &&
                      !server.hidden.contains(me))))
            e.key: e.value.withBusy(server.busyUntil(e.key)),
      },
      offers: [
        for (final o in server.offers.values)
          if (o.a == me || o.b == me) o.toReal(),
      ],
      circles: [
        for (final c in server.circles.values)
          if (c.$1 == me) c.$2,
      ],
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

  @override
  Future<CreatedInvitation> createInvitation() async {
    final me = _uid;
    final token = server._token();
    final inv = _Invitation(
      token,
      me,
      server.now().add(const Duration(days: 7)),
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
    for (final o in server.offers.values) {
      if (o.status == OfferStatus.pending && (o.a == me || o.b == me)) {
        o
          ..status = OfferStatus.cancelled
          ..updatedAt = server.now();
      }
    }
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
      server._changed();
      return OfferAnswer(o.status);
    }
    if (me == o.a) {
      o.aAccepted = accept;
    } else {
      o.bAccepted = accept;
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
  Future<bool> cancelCall(String offerId) async {
    if (offline) throw const RealBackendException('offline');
    return server.cancelCallFor(offerId, _uid);
  }

  @override
  Future<CallStart> startCall(String offerId) async {
    final me = _uid;
    if (offline) throw const RealBackendException('offline');
    final o = server.offers[offerId];
    if (o == null || (o.a != me && o.b != me)) {
      return const CallStart(CallStartState.gone);
    }
    if (o.status == OfferStatus.cancelled) {
      return const CallStart(CallStartState.cancelled);
    }
    if (o.status != OfferStatus.accepted || server.blockedBetween(o.a, o.b)) {
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
    if (o.caller == null) {
      o
        ..caller = me
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
  Future<void> sendCallOutcome(String offerId, CallOutcome outcome) async {
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
      'talked': outcome != CallOutcome.noTalk,
      'outcome': outcome.name,
    });
    if (outcome != CallOutcome.noTalk) {
      o.talked = true;
    } else {
      o.talked ??= false;
    }
    if (o.a == me) o.endedA = true;
    if (o.b == me) o.endedB = true;
    if (outcome == CallOutcome.notSoon) {
      server.snoozes['$me|$other'] = server.now().add(const Duration(days: 7));
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
  Future<void> setHideStatus(bool hide) async {
    final me = _uid;
    hide ? server.hidden.add(me) : server.hidden.remove(me);
    server._changed();
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
    final saved = RealCircle(
      id: id,
      name: name,
      quick: circle.quick,
      memberIds: {...circle.memberIds},
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
      for (final e in server.availability.entries.toList()) {
        if (e.value.circleId == circleId) {
          final a = e.value;
          server.availability[e.key] = RealAvailability(
            userId: a.userId,
            mode: a.mode,
            startedAt: a.startedAt,
            expiresAt: a.expiresAt,
            auto: a.auto,
          );
        }
      }
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
  int schema = 24;

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
    final ok = code.trim() == '97869786';
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
