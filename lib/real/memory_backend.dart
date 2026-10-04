import 'dart:async';
import 'dart:math';

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

  void _createOffersFor(String user) {
    if (!_activeAvail(user)) return;
    final mine = availability[user]!;
    for (final other in availability.keys.toList()) {
      if (other == user || !_activeAvail(other)) continue;
      if (!connected(user, other) || blockedBetween(user, other)) continue;
      final theirs = availability[other]!;
      if (!inAudience(mine.circleId, other) ||
          !inAudience(theirs.circleId, user)) {
        continue;
      }
      final pair = _pair(user, other).split('|');
      bool samePair(_Offer o) => o.a == pair[0] && o.b == pair[1];
      final since = now();
      final blocking = offers.values.any(
        (o) =>
            samePair(o) &&
            (o.status == OfferStatus.pending ||
                (o.status == OfferStatus.declined &&
                    since.difference(o.updatedAt) <
                        const Duration(minutes: 2)) ||
                (o.status == OfferStatus.accepted &&
                    since.difference(o.updatedAt) <
                        const Duration(minutes: 30))),
      );
      if (blocking) continue;
      final quick =
          _isQuick(user, other) &&
          _isQuick(other, user) &&
          !offers.values.any(
            (o) =>
                samePair(o) &&
                o.quick &&
                since.difference(o.createdAt) < const Duration(days: 1),
          );
      final id = _newId('offer');
      offers[id] = _Offer(
        id: id,
        a: pair[0],
        b: pair[1],
        createdAt: since,
        updatedAt: since,
        expiresAt: mine.expiresAt.isBefore(theirs.expiresAt)
            ? mine.expiresAt
            : theirs.expiresAt,
        quick: quick,
      );
      if (quick) {
        offers[id]!
          ..status = OfferStatus.accepted
          ..aAccepted = true
          ..bAccepted = true;
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
    availability[me] = RealAvailability(
      userId: me,
      mode: AvailabilityMode.driving,
      startedAt: now(),
      expiresAt: now().add(Duration(minutes: minutes.clamp(15, 180))),
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
    final p = RealProfile(id: me, name: trimmed, gender: gender);
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
                      server.inAudience(e.value.circleId, me))))
            e.key: e.value,
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
          if (o.status == OfferStatus.accepted && (o.a == me || o.b == me))
            (o.a == me ? o.b : o.a, o.updatedAt),
      ],
      lastTalk: {
        for (final o
            in server.offers.values.toList()
              ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt)))
          if (o.status == OfferStatus.accepted && (o.a == me || o.b == me))
            o.a == me ? o.b : o.a: o.updatedAt,
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
    server.connections.add(MemoryServer._pair(me, inv.inviter));
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
  Future<OfferStatus> respondOffer(
    String offerId, {
    required bool accept,
  }) async {
    final me = _uid;
    final o = server.offers[offerId];
    if (o == null || (o.a != me && o.b != me)) {
      throw const RealBackendException('not_found');
    }
    if (o.status != OfferStatus.pending) return o.status;
    if (!server.now().isBefore(o.expiresAt) ||
        !server._activeAvail(o.a) ||
        !server._activeAvail(o.b)) {
      o
        ..status = OfferStatus.expired
        ..updatedAt = server.now();
      server._changed();
      return o.status;
    }
    if (me == o.a) {
      o.aAccepted = accept;
    } else {
      o.bAccepted = accept;
    }
    if (!accept) {
      o.status = OfferStatus.declined;
    } else if (o.aAccepted == true && o.bAccepted == true) {
      o.status = OfferStatus.accepted;
    }
    o.updatedAt = server.now();
    server._changed();
    return o.status;
  }

  @override
  Future<void> sendFeedback({
    required String? offerId,
    required bool talked,
    FeedbackRating? rating,
    bool? wantAgain,
  }) async {
    server.feedback.add({
      'user': _uid,
      'offer': offerId,
      'talked': talked,
      'rating': rating?.name,
      'wantAgain': wantAgain,
    });
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
  Future<CallDetails> callDetails(String offerId) async {
    final me = _uid;
    final o = server.offers[offerId];
    if (o == null ||
        (o.a != me && o.b != me) ||
        o.status != OfferStatus.accepted) {
      return const CallDetails();
    }
    final other = o.a == me ? o.b : o.a;
    if (server.blockedBetween(me, other)) return const CallDetails();
    return CallDetails(
      otherPhone: server.phones[other],
      iShare: server.phones.containsKey(me),
    );
  }

  @override
  Future<List<String>> syncContacts(List<String> hashes) async {
    final me = _uid;
    server.contactHashes[me] = {...hashes};
    final myPhone = server.phones[me];
    if (myPhone == null) return const [];
    final myHash = hashPhone(myPhone);
    final names = <String>[];
    for (final e in server.phones.entries) {
      final other = e.key;
      if (other == me) continue;
      if (!hashes.contains(hashPhone(e.value))) continue;
      if (!(server.contactHashes[other]?.contains(myHash) ?? false)) continue;
      if (server.blockedBetween(me, other) || server.connected(me, other)) {
        continue;
      }
      server.connections.add(MemoryServer._pair(me, other));
      names.add(server.profiles[other]!.name);
    }
    server._createOffersFor(me);
    server._changed();
    return names;
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
      server.connections.add(MemoryServer._pair(me, userId));
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
  Future<void> block(String userId) async {
    final me = _uid;
    if (userId == me) return;
    if (server.connected(me, userId)) server.wasConnected.add('$me|$userId');
    for (final c in server.circles.values) {
      if (c.$1 == me) c.$2.memberIds.remove(userId);
    }
    server.blocks.add('$me|$userId');
    server.connections.remove(MemoryServer._pair(me, userId));
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
    server.connections.remove(MemoryServer._pair(me, userId));
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
