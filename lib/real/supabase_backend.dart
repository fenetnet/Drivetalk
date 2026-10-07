import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import 'backend_config.dart';
import 'real_backend.dart';
import 'real_models.dart';

/// The real backend: Supabase (Postgres + Row Level Security + Realtime).
///
/// The app holds only the public URL and anon/publishable key. Everything a
/// user may read or change is enforced by the database (see
/// supabase/migrations), not by this code.
class SupabaseRealBackend implements RealBackend {
  /// [client] is for tests against a real server (several users per process).
  SupabaseRealBackend({SupabaseClient? client})
    : _client = client,
      _injected = client != null;

  SupabaseClient? _client;
  final bool _injected;
  final _channels = <String, RealtimeChannel>{};

  /// Realtime per table: subscribed or not (a failing table never breaks the
  /// others). For the test tab / diagnostics.
  @override
  final realtimeTables = <String, bool>{};
  final _changes = StreamController<void>.broadcast();
  final _live = StreamController<LiveStatus>.broadcast();

  @override
  bool get isConfigured => _injected || BackendConfig.isConfigured;

  SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const RealBackendException('not_configured');
    return c;
  }

  @override
  String? get userId => _client?.auth.currentUser?.id;

  @override
  Future<void> start() async {
    if (!isConfigured) return;
    if (_client == null) {
      await _guard(() async {
        await Supabase.initialize(
          url: BackendConfig.supabaseUrl,
          publishableKey: BackendConfig.supabaseAnonKey,
          debug: false,
        );
      });
      _client = Supabase.instance.client;
    }
    if (userId != null) _subscribe();
  }

  @override
  Future<RealProfile> signIn(String name, Gender gender) => _guard(() async {
    if (_c.auth.currentUser == null) {
      await _c.auth.signInAnonymously();
    }
    final p = await updateProfile(name, gender);
    _subscribe();
    return p;
  });

  @override
  Future<RealProfile> updateProfile(String name, Gender gender) =>
      _guard(() async {
        final row = await _c.rpc(
          'ensure_profile',
          params: {'p_name': name.trim(), 'p_gender': genderToKey(gender)},
        );
        return _profile(Map<String, dynamic>.from(row as Map));
      });

  @override
  Future<void> signOut() async {
    await _unsubscribe();
    try {
      await _client?.auth.signOut();
    } catch (_) {
      // Signing out locally is enough.
    }
  }

  @override
  Future<RealSnapshot> fetchSnapshot() => _guard(() async {
    final me = userId;
    if (me == null) throw const RealBackendException('not_authenticated');
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 12))
        .toIso8601String();
    final results = await Future.wait([
      _c
          .from('profiles')
          .select('id, display_name, gender, photo_version')
          .then<List<Map<String, dynamic>>>(
            (r) => r,
            // Older server (before photos).
            onError: (Object _) =>
                _c.from('profiles').select('id, display_name, gender'),
          ),
      _c
          .from('availability')
          .select('user_id, mode, started_at, expires_at, circle_id, source')
          .then<List<Map<String, dynamic>>>(
            (r) => r,
            // Older server (before circles): the basic columns only.
            onError: (Object _) => _c
                .from('availability')
                .select('user_id, mode, started_at, expires_at'),
          ),
      _c
          .from('match_offers')
          .select()
          .gt('updated_at', since)
          .order('updated_at', ascending: false)
          .limit(50),
      // Talk history: only real talks (someone said "we talked").
      _c
          .from('match_offers')
          .select('user_a, user_b, updated_at')
          .eq('status', 'accepted')
          .eq('talked', true)
          .order('updated_at', ascending: false)
          .limit(300)
          .then<List<Map<String, dynamic>>>(
            (r) => r,
            // Older server (no "talked" yet): both said yes.
            onError: (Object _) => _c
                .from('match_offers')
                .select('user_a, user_b, updated_at')
                .eq('status', 'accepted')
                .order('updated_at', ascending: false)
                .limit(300),
          ),
      // "I'd like to talk" (mine only); optional on an older server.
      _c
          .from('talk_intents')
          .select('to_user, expires_at')
          .then<List<Map<String, dynamic>>>(
            (r) => r,
            onError: (Object _) => <Map<String, dynamic>>[],
          ),
      // Circles are optional: an older server without them still works.
      _c
          .from('circles')
          .select('id, name, quick, circle_members(member)')
          .then<List<Map<String, dynamic>>>(
            (r) => r,
            onError: (Object _) => <Map<String, dynamic>>[],
          ),
      // My ratings (optional on an older server).
      _c
          .from('friend_ratings')
          .select('friend, rating')
          .then<List<Map<String, dynamic>>>(
            (r) => r,
            onError: (Object _) => <Map<String, dynamic>>[],
          ),
      // Do I hide my status? (optional on an older server)
      _c
          .from('profiles')
          .select('hide_status')
          .eq('id', me)
          .then<List<Map<String, dynamic>>>(
            (r) => r,
            onError: (Object _) => <Map<String, dynamic>>[],
          ),
    ]);
    final profiles = [
      for (final r in results[0]) _profile(Map<String, dynamic>.from(r)),
    ];
    final mine = profiles.where((p) => p.id == me).firstOrNull;
    if (mine == null) throw const RealBackendException('no_profile');
    return RealSnapshot(
      me: mine,
      friends: [
        for (final p in profiles)
          if (p.id != me) p,
      ]..sort((a, b) => a.name.compareTo(b.name)),
      availability: {
        for (final r in results[1])
          r['user_id'] as String: RealAvailability(
            userId: r['user_id'] as String,
            mode: modeFromKey(r['mode'] as String?),
            startedAt: _time(r['started_at']),
            expiresAt: _time(r['expires_at']),
            circleId: r['circle_id'] as String?,
            auto: r['source'] == 'auto',
          ),
      },
      offers: [for (final r in results[2]) _offer(r)],
      lastTalk: _lastTalk(results[3], me),
      talks: [
        for (final r in results[3])
          (
            (r['user_a'] == me ? r['user_b'] : r['user_a']) as String,
            _time(r['updated_at']),
          ),
      ],
      intents: {
        for (final r in results[4])
          if (r['expires_at'] == null ||
              _time(r['expires_at']).isAfter(DateTime.now()))
            r['to_user'] as String: TalkIntent(
              friendId: r['to_user'] as String,
              until: r['expires_at'] == null ? null : _time(r['expires_at']),
            ),
      },
      circles: [
        for (final r in results[5])
          RealCircle(
            id: r['id'] as String,
            name: r['name'] as String,
            quick: r['quick'] == true,
            memberIds: {
              for (final m in (r['circle_members'] as List? ?? const []))
                (m as Map)['member'] as String,
            },
          ),
      ]..sort((a, b) => a.name.compareTo(b.name)),
      ratings: {
        for (final r in results[6])
          r['friend'] as String: (r['rating'] as num).toInt(),
      },
      hidden: results[7].firstOrNull?['hide_status'] == true,
      fetchedAt: DateTime.now(),
    );
  });

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Stream<LiveStatus> get liveStatus => _live.stream;

  @override
  Future<CreatedInvitation> createInvitation() => _guard(() async {
    final rows = await _c.rpc('create_invitation') as List;
    final r = Map<String, dynamic>.from(rows.single as Map);
    return CreatedInvitation(r['token'] as String, _time(r['expires_at']));
  });

  @override
  Future<InviteInfo> getInvitation(String token) => _guard(() async {
    final rows = await _c.rpc('get_invitation', params: {'p_token': token});
    final r = Map<String, dynamic>.from((rows as List).single as Map);
    final g = r['inviter_gender'] as String?;
    return InviteInfo(
      inviteStatusFromKey(r['status'] as String?),
      inviterName: r['inviter_name'] as String?,
      inviterGender: g == null ? null : genderFromKey(g),
    );
  });

  @override
  Future<AcceptResult> acceptInvitation(String token) => _guard(() async {
    final r = await _c.rpc('accept_invitation', params: {'p_token': token});
    return acceptResultFromKey(r as String?);
  });

  @override
  Future<void> setAvailability(
    AvailabilityMode mode,
    int minutes, {
    String? circleId,
  }) => _guard(() async {
    await _c.rpc(
      'set_availability',
      params: {'p_mode': mode.name, 'p_minutes': minutes, 'p_circle': circleId},
    );
  });

  @override
  Future<void> nudgeOffers() => _guard(() async => _c.rpc('nudge_offers'));

  @override
  Future<List<RealProfile>> blockedPeople() => _guard(() async {
    final rows = await _c.rpc('my_blocks') as List;
    return [
      for (final r in rows)
        RealProfile(
          id: (r as Map)['user_id'] as String,
          name: r['display_name'] as String,
          gender: genderFromKey(r['gender'] as String?),
        ),
    ];
  });

  @override
  Future<bool> unblock(String userId) => _guard(
    () async =>
        await _c.rpc('unblock_user', params: {'p_user': userId}) ==
        'reconnected',
  );

  @override
  Future<RealCircle> saveCircle(RealCircle circle) => _guard(() async {
    String id;
    try {
      // All or nothing, in one step.
      id = await _c.rpc(
        'save_circle',
        params: {
          'p_id': circle.id.isEmpty ? null : circle.id,
          'p_name': circle.name.trim(),
          'p_quick': circle.quick,
          'p_members': circle.memberIds.toList(),
        },
      ) as String;
    } on PostgrestException catch (e) {
      if (!_missingFunction(e)) rethrow;
      id = await _saveCircleOld(circle);
    }
    return RealCircle(
      id: id,
      name: circle.name.trim(),
      quick: circle.quick,
      memberIds: circle.memberIds,
    );
  });

  /// Older server: the same in three steps.
  Future<String> _saveCircleOld(RealCircle circle) async {
    final values = {'name': circle.name.trim(), 'quick': circle.quick};
    final row = circle.id.isEmpty
        ? await _c.from('circles').insert(values).select('id').single()
        : await _c
              .from('circles')
              .update(values)
              .eq('id', circle.id)
              .select('id')
              .single();
    final id = row['id'] as String;
    await _c.from('circle_members').delete().eq('circle_id', id);
    if (circle.memberIds.isNotEmpty) {
      await _c.from('circle_members').insert([
        for (final m in circle.memberIds) {'circle_id': id, 'member': m},
      ]);
    }
    return id;
  }

  @override
  Future<void> deleteCircle(String circleId) =>
      _guard(() async => _c.from('circles').delete().eq('id', circleId));

  @override
  Future<void> clearAvailability() =>
      _guard(() async => _c.rpc('clear_availability'));

  @override
  Future<OfferAnswer> declineLater(String offerId) => _guard(() async {
    try {
      final r = Map<String, dynamic>.from(
        await _c.rpc('decline_later', params: {'p_offer': offerId}) as Map,
      );
      return OfferAnswer(_status(r['status'] as String?));
    } on PostgrestException catch (e) {
      // Older server: a plain "not now".
      if (!_missingFunction(e)) rethrow;
      return answerOffer(offerId, accept: false);
    }
  });

  @override
  Future<Map<String, num?>> appStats(int days) => _guard(() async {
    final r = Map<String, dynamic>.from(
      await _c.rpc('app_stats', params: {'p_days': days}) as Map,
    );
    return {for (final e in r.entries) e.key: e.value as num?};
  });

  @override
  Future<OfferAnswer> answerOffer(String offerId, {required bool accept}) =>
      _guard(() async {
        final params = {'p_offer': offerId, 'p_accept': accept};
        Object? r;
        try {
          r = await _c.rpc('answer_offer', params: params);
        } on PostgrestException catch (e) {
          if (!_missingFunction(e)) rethrow;
          // Server not updated yet: the older two-step way.
          final status = _status(
            await _c.rpc('respond_offer', params: params) as String?,
          );
          if (status != OfferStatus.accepted) return OfferAnswer(status);
          final rows = await _c.rpc(
            'call_details',
            params: {'p_offer': offerId},
          );
          final d = Map<String, dynamic>.from((rows as List).single as Map);
          final phone = d['other_phone'] as String?;
          return OfferAnswer(status, iCall: phone != null, phone: phone);
        }
        final m = Map<String, dynamic>.from(r as Map);
        if (m['status'] == 'not_found') {
          throw const RealBackendException('not_found');
        }
        return OfferAnswer(
          _status(m['status'] as String?),
          iCall: m['i_call'] == true,
          phone: m['phone'] as String?,
        );
      });

  @override
  Future<void> seenCall(String offerId) => _guard(() async {
    try {
      await _c.rpc('seen_call', params: {'p_offer': offerId});
    } on PostgrestException catch (e) {
      if (!_missingFunction(e)) rethrow;
    }
  });

  @override
  Future<bool> cancelCall(String offerId) => _guard(() async {
    try {
      return await _c.rpc('cancel_call', params: {'p_offer': offerId}) == true;
    } on PostgrestException catch (e) {
      if (!_missingFunction(e)) rethrow;
      return true; // Older server: the countdown was only on the phone.
    }
  });

  @override
  Future<CallStart> startCall(String offerId) => _guard(() async {
    try {
      final m = Map<String, dynamic>.from(
        await _c.rpc('start_call', params: {'p_offer': offerId}) as Map,
      );
      return CallStart(
        switch (m['state']) {
          'ready' => CallStartState.ready,
          'wait' => CallStartState.wait,
          'cancelled' => CallStartState.cancelled,
          _ => CallStartState.gone,
        },
        iCall: m['i_call'] == true,
        phone: m['phone'] as String?,
        waitMs: (m['wait_ms'] as num?)?.toInt(),
      );
    } on PostgrestException catch (e) {
      if (!_missingFunction(e)) rethrow;
      final rows = await _c.rpc('call_details', params: {'p_offer': offerId});
      final d = Map<String, dynamic>.from((rows as List).single as Map);
      final phone = d['other_phone'] as String?;
      return CallStart(
        CallStartState.ready,
        iCall: phone != null,
        phone: phone,
      );
    }
  });

  @override
  Future<void> endCall(String offerId) => _guard(() async {
    try {
      await _c.rpc('end_call', params: {'p_offer': offerId});
    } on PostgrestException catch (e) {
      if (!_missingFunction(e)) rethrow;
    }
  });

  /// The server doesn't have this function yet (an update wasn't pasted).
  static bool _missingFunction(PostgrestException e) =>
      e.code == 'PGRST202' ||
      e.message.toLowerCase().contains('could not find the function');

  @override
  Future<void> sendCallOutcome(String offerId, CallOutcome outcome) =>
      _guard(() async {
        final key = switch (outcome) {
          CallOutcome.good => 'good',
          CallOutcome.notSoon => 'not_soon',
          CallOutcome.noTalk => 'no_talk',
        };
        try {
          await _c.rpc(
            'call_feedback',
            params: {'p_offer': offerId, 'p_result': key},
          );
        } on PostgrestException catch (e) {
          if (!_missingFunction(e)) rethrow;
          // Older server: the plain feedback row.
          await _c.from('feedback').insert({
            'offer_id': offerId,
            'talked': outcome != CallOutcome.noTalk,
            if (outcome == CallOutcome.good) 'rating': 'good',
            if (outcome == CallOutcome.notSoon) 'rating': 'notReally',
          });
        }
      });

  @override
  Future<String?> getMyPhone() => _guard(() async {
    final rows = await _c.from('phone_numbers').select('phone');
    return rows.isEmpty ? null : rows.first['phone'] as String?;
  });

  @override
  Future<void> setMyPhone(String? phone) => _guard(() async {
    final me = userId;
    if (me == null) throw const RealBackendException('not_authenticated');
    if (phone == null) {
      await _c.from('phone_numbers').delete().eq('user_id', me);
      return;
    }
    final n = normalizePhone(phone);
    if (n == null) throw const RealBackendException('invalid_phone');
    await _c.from('phone_numbers').upsert({
      'user_id': me,
      'phone': n,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  });

  @override
  Future<List<ContactMatch>> syncContacts(List<String> hashes) =>
      _guard(() async {
        final rows =
            await _c.rpc('find_friends', params: {'p_hashes': hashes}) as List;
        return [
          for (final r in rows)
            if ((r as Map)['user_id'] != null)
              ContactMatch(r['user_id'] as String, r['display_name'] as String),
        ];
      });

  @override
  Future<List<String>> addContacts(List<String> userIds) => _guard(() async {
    final rows =
        await _c.rpc('add_contacts', params: {'p_users': userIds}) as List;
    return [for (final r in rows) (r as Map)['display_name'] as String];
  });

  @override
  Future<void> setRating(String friendId, int rating) => _guard(
    () => _c.rpc(
      'set_rating',
      params: {'p_friend': friendId, 'p_rating': rating},
    ),
  );

  @override
  Future<void> setHideStatus(bool hide) =>
      _guard(() => _c.rpc('set_hide_status', params: {'p_hide': hide}));

  @override
  Future<String> createDeviceToken() =>
      _guard(() async => await _c.rpc('create_device_token') as String);

  @override
  Future<void> revokeDeviceTokens() =>
      _guard(() async => _c.rpc('revoke_device_tokens'));

  @override
  Future<void> setPhoto(Uint8List? jpeg) => _guard(() async {
    final me = userId;
    if (me == null) throw const RealBackendException('not_authenticated');
    final bucket = _c.storage.from('avatars');
    try {
      if (jpeg == null) {
        await bucket.remove(['$me.jpg']);
      } else {
        await bucket.uploadBinary(
          '$me.jpg',
          jpeg,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
      }
    } on StorageException catch (e) {
      // No "avatars" storage yet = the photos server update wasn't added.
      final m = e.message.toLowerCase();
      throw RealBackendException(
        m.contains('bucket') || e.statusCode == '404'
            ? 'schema_missing'
            : 'unknown',
      );
    }
    await _c.rpc('set_photo', params: {'p_has': jpeg != null});
  }, limit: const Duration(seconds: 60));

  @override
  Future<Uint8List?> downloadPhoto(String userId) async {
    try {
      return await _c.storage.from('avatars').download('$userId.jpg');
    } catch (_) {
      return null; // No photo, not allowed, or offline — show the letter.
    }
  }

  @override
  Future<void> setTalkIntent(String userId, DateTime? until) => _guard(
    () => _c.rpc(
      'set_talk_intent',
      params: {'p_user': userId, 'p_until': until?.toUtc().toIso8601String()},
    ),
  );

  @override
  Future<void> clearTalkIntent(String userId) =>
      _guard(() => _c.rpc('clear_talk_intent', params: {'p_user': userId}));

  @override
  Future<int> schemaVersion() => _guard(() async {
    try {
      return (await _c.rpc('schema_version') as num).toInt();
    } on PostgrestException catch (e) {
      if (_missingFunction(e)) return 0;
      rethrow;
    }
  });

  @override
  Future<void> clearContactHashes() =>
      _guard(() => _c.rpc('clear_contact_hashes'));

  @override
  Future<void> deleteAccount() => _guard(() async {
    final me = userId;
    if (me == null) throw const RealBackendException('not_authenticated');
    try {
      await _c.storage.from('avatars').remove(['$me.jpg']);
    } catch (_) {
      // No photo (or no storage): nothing to remove.
    }
    await _c.rpc('delete_my_account');
    await signOut();
  });

  @override
  Future<void> logEvent(String name, {int? ms}) async {
    try {
      await _c.rpc('log_event', params: {'p_name': name, 'p_ms': ms});
    } catch (_) {
      // Measurements never get in the way.
    }
  }

  @override
  Future<void> block(String userId) =>
      _guard(() async => _c.rpc('block_user', params: {'p_user': userId}));

  @override
  Future<void> unmatch(String userId) => _guard(() async {
    final me = this.userId!;
    final a = me.compareTo(userId) < 0 ? me : userId;
    final b = a == me ? userId : me;
    await _c.from('connections').delete().eq('user_a', a).eq('user_b', b);
  });

  @override
  Future<void> report(String userId, ReportReason reason) => _guard(() async {
    await _c.from('reports').insert({
      'reported': userId,
      'reason': reason.name,
    });
  });

  // ------------------------------------------------------------ realtime

  /// The core tables: without them, "instant updates" really don't work.
  static const _coreTables = {'availability', 'match_offers'};

  void _subscribe() {
    if (_channels.isNotEmpty || _client == null) return;
    _live.add(LiveStatus.connecting);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final table in const [
      'availability',
      'match_offers',
      'connections',
      'profiles',
      'circles',
      'circle_members',
      'friend_ratings',
    ]) {
      // One channel per table: if one table can't be watched (e.g. not
      // enabled for Realtime on the server), the others still work.
      final ch = _c
          .channel('drivetalk-$table-$stamp')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) => _changes.add(null),
          );
      _channels[table] = ch;
      ch.subscribe((status, [error]) {
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            realtimeTables[table] = true;
            // Catch up on anything missed while (re)connecting.
            _changes.add(null);
          case RealtimeSubscribeStatus.closed:
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            realtimeTables[table] = false;
        }
        _reportLive();
      });
    }
  }

  void _reportLive() {
    final core = [for (final t in _coreTables) realtimeTables[t]];
    if (core.every((v) => v == true)) {
      _live.add(LiveStatus.connected);
    } else if (core.any((v) => v == false)) {
      _live.add(LiveStatus.error);
    }
  }

  Future<void> _unsubscribe() async {
    final all = [..._channels.values];
    _channels.clear();
    realtimeTables.clear();
    for (final ch in all) {
      try {
        await _c.removeChannel(ch);
      } catch (_) {}
    }
    _live.add(LiveStatus.disconnected);
  }

  // ------------------------------------------------------------- helpers

  /// Turns any failure into a short, secret-free code.
  /// A request that hangs (network switch, tunnel) must not block the app
  /// forever: after [limit] it counts as "offline" and is retried later.
  Future<T> _guard<T>(
    Future<T> Function() body, {
    Duration limit = const Duration(seconds: 20),
  }) async {
    try {
      return await body().timeout(limit);
    } on RealBackendException {
      rethrow;
    } on PostgrestException catch (e) {
      throw RealBackendException(_codeFrom(e.message));
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      throw RealBackendException(
        m.contains('anonymous') && m.contains('disabled')
            ? 'anonymous_disabled'
            : m.contains('rate') || e.statusCode == '429'
            ? 'rate_limited'
            : m.contains('api key') || m.contains('apikey')
            ? 'bad_key'
            : 'auth ${e.statusCode ?? ''} ${_short(e.message)}'.trim(),
      );
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('socket') ||
          s.contains('failed host lookup') ||
          s.contains('clientexception') ||
          s.contains('timeout') ||
          s.contains('connection')) {
        throw const RealBackendException('offline');
      }
      throw const RealBackendException('unknown');
    }
  }

  /// A short, readable reason for the test screen (long token-like runs
  /// removed, just in case).
  static String _short(String message) {
    final clean = message
        .replaceAll(RegExp(r'[A-Za-z0-9_\-.]{24,}'), '…')
        .replaceAll(RegExp(r'\s+'), ' ');
    return clean.length > 80 ? '${clean.substring(0, 80)}…' : clean;
  }

  static String _codeFrom(String message) {
    const known = [
      'invalid_minutes',
      'not_authenticated',
      'no_profile',
      'too_many_open_invitations',
      'invalid_circle',
    ];
    for (final k in known) {
      if (message.contains(k)) return k;
    }
    if (message.contains('display_name')) return 'invalid_name';
    if (message.contains('phone')) return 'invalid_phone';
    if (message.contains('permission denied') ||
        message.contains('row-level security')) {
      return 'not_allowed';
    }
    if (message.contains('does not exist') ||
        message.contains('Could not find')) {
      return 'schema_missing';
    }
    return 'server';
  }

  static Map<String, DateTime> _lastTalk(
    List<Map<String, dynamic>> rows,
    String me,
  ) {
    final out = <String, DateTime>{};
    for (final r in rows) {
      final other = r['user_a'] == me ? r['user_b'] : r['user_a'];
      final t = _time(r['updated_at']);
      final prev = out[other as String];
      if (prev == null || t.isAfter(prev)) out[other] = t;
    }
    return out;
  }

  static RealProfile _profile(Map<String, dynamic> r) => RealProfile(
    id: r['id'] as String,
    name: r['display_name'] as String,
    gender: genderFromKey(r['gender'] as String?),
    photoVersion: (r['photo_version'] as num?)?.toInt() ?? 0,
  );

  static RealOffer _offer(Map<String, dynamic> r) => RealOffer(
    id: r['id'] as String,
    userA: r['user_a'] as String,
    userB: r['user_b'] as String,
    status: _status(r['status'] as String?),
    createdAt: _time(r['created_at']),
    updatedAt: _time(r['updated_at']),
    expiresAt: _time(r['expires_at']),
    aAccepted: _answer(r['a_response']),
    bAccepted: _answer(r['b_response']),
    quick: r['quick'] == true,
    caller: r['caller'] as String?,
    notBefore: r['not_before'] == null ? null : _time(r['not_before']),
    laterFrom: r['later_from'] as String?,
  );

  static bool? _answer(Object? v) => switch (v) {
    'accept' => true,
    'decline' => false,
    _ => null,
  };

  static OfferStatus _status(String? s) => switch (s) {
    'accepted' => OfferStatus.accepted,
    'declined' => OfferStatus.declined,
    'expired' => OfferStatus.expired,
    'cancelled' => OfferStatus.cancelled,
    _ => OfferStatus.pending,
  };

  static DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();
}
