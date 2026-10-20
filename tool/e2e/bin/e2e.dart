// End-to-end check of the DriveTalk backend with real Supabase clients.
//
//   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=... dart run bin/e2e.dart
//
// Simulates two phones (Netanel & Yoni) and a stranger (Eve) and verifies:
// invitations, connections, RLS isolation, availability + realtime,
// mutual acceptance, gentle decline, expiry and blocking.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase/supabase.dart';

final url = Platform.environment['SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
final anonKey = Platform.environment['SUPABASE_ANON_KEY']!;
final dbUrl =
    Platform.environment['SUPABASE_DB_URL'] ??
    'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

/// A number from the local test database (checks what the server keeps).
Future<int> dbCount(String sql) async {
  final r = await Process.run('psql', [dbUrl, '-tAc', sql]);
  if (r.exitCode != 0) throw StateError('psql: ${r.stderr}');
  return int.parse((r.stdout as String).trim());
}

/// One value from the local test database (e.g. an id it just made).
Future<String> dbScalar(String sql) async {
  final r = await Process.run('psql', [dbUrl, '-tAqc', sql]);
  if (r.exitCode != 0) throw StateError('psql: ${r.stderr}');
  return (r.stdout as String).trim().split('\n').first.trim();
}

/// Run SQL on the local test database (sets up rare situations).
Future<void> dbExec(String sql) async {
  final r = await Process.run('psql', [
    dbUrl,
    '-v',
    'ON_ERROR_STOP=1',
    '-qc',
    sql,
  ]);
  if (r.exitCode != 0) throw StateError('psql: ${r.stderr}');
}

/// The 5 quiet minutes after a question that didn't become a call (D-069):
/// make finished questions look 6 minutes old (local test database only).
Future<void> skipQuietGap() async {
  final r = await Process.run('psql', [
    dbUrl,
    '-c',
    "update match_offers set updated_at = updated_at - interval '6 minutes' "
        "where status in ('declined', 'expired', 'cancelled')",
  ]);
  if (r.exitCode != 0) throw StateError('psql: ${r.stderr}');
}

var failures = 0;
void check(bool ok, String what) {
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $what');
  if (!ok) failures++;
}

var _autoPhone = 0;

/// A new person. Everyone gets a number (an offer needs at least one of
/// the two to have one — D-095); tests that need "no number" delete it.
Future<SupabaseClient> newUser(String name, String gender) async {
  final c = SupabaseClient(url, anonKey);
  await c.auth.signInAnonymously();
  await c.rpc('ensure_profile', params: {'p_name': name, 'p_gender': gender});
  await c.from('phone_numbers').upsert({
    'user_id': c.auth.currentUser!.id,
    'phone': '+97254${(1000000 + _autoPhone++ * 7919 % 9000000)}',
  });
  return c;
}

String uid(SupabaseClient c) => c.auth.currentUser!.id;

Future<List<Map<String, dynamic>>> rows(SupabaseClient c, String table) async =>
    List<Map<String, dynamic>>.from(
      await c
          .from(table)
          // Profiles: only the columns the app may read (D-094).
          .select(
            table == 'profiles'
                ? 'id, display_name, gender, photo_version, hide_status'
                // Availability: only what friends may read (D-118).
                : table == 'availability'
                ? 'user_id, mode, expires_at, source, call_until, phone_until, '
                      'missed_at, quiet_until'
                : '*',
          ),
    );

Future<void> main() async {
  final me = await newUser('נתנאל', 'male');
  // I share my number later in the story (who calls whom depends on it).
  await me.from('phone_numbers').delete().eq('user_id', uid(me));
  final yoni = await newUser('יוני', 'male');
  final eve = await newUser('איב', 'female');

  // --- profiles are private until connected
  check(
    (await rows(yoni, 'profiles')).length == 1,
    'before connecting, Yoni sees only himself',
  );

  // --- invitation
  final inv = List<Map<String, dynamic>>.from(
    await me.rpc('create_invitation'),
  ).single;
  final token = inv['token'] as String;
  check(
    token.length >= 22,
    'invitation token is long and random (${token.length} chars)',
  );

  final peek = List<Map<String, dynamic>>.from(
    await yoni.rpc('get_invitation', params: {'p_token': token}),
  ).single;
  check(
    peek['status'] == 'valid' && peek['inviter_name'] == 'נתנאל',
    'Yoni sees "Netanel invited you" before accepting',
  );

  final bad = List<Map<String, dynamic>>.from(
    await yoni.rpc('get_invitation', params: {'p_token': '${token}x'}),
  ).single;
  check(bad['status'] == 'not_found', 'a mistyped invitation is "not found"');

  check(
    await me.rpc('accept_invitation', params: {'p_token': token}) == 'own',
    'I cannot accept my own invitation',
  );
  check(
    await yoni.rpc('accept_invitation', params: {'p_token': token}) ==
        'accepted',
    'Yoni accepts the invitation',
  );
  check(
    await yoni.rpc('accept_invitation', params: {'p_token': token}) ==
        'already_connected',
    'opening the invitation twice is harmless',
  );
  check(
    await eve.rpc('accept_invitation', params: {'p_token': token}) == 'used',
    'a used invitation cannot be reused by someone else',
  );

  // --- connections & RLS isolation
  final myPeople = await rows(me, 'profiles');
  check(
    myPeople.any((p) => p['display_name'] == 'יוני'),
    'I see Yoni in my people',
  );
  check(
    (await rows(yoni, 'profiles')).any((p) => p['display_name'] == 'נתנאל'),
    'Yoni sees me',
  );
  check(
    (await rows(eve, 'profiles')).length == 1,
    'a stranger sees nobody else',
  );
  check(
    (await rows(eve, 'connections')).isEmpty,
    'a stranger sees no connections',
  );
  check(
    (await rows(eve, 'invitations')).isEmpty,
    "a stranger can't list invitations",
  );

  // Direct writes are not allowed — only through functions.
  try {
    await eve.from('connections').insert({
      'user_a': uid(eve),
      'user_b': uid(me),
    });
    check(false, 'a stranger cannot insert a connection directly');
  } on PostgrestException {
    check(true, 'a stranger cannot insert a connection directly');
  }
  try {
    await eve.from('availability').insert({
      'user_id': uid(eve),
      'mode': 'free',
      'expires_at': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });
    check(false, 'availability cannot be written directly');
  } on PostgrestException {
    check(true, 'availability cannot be written directly');
  }

  // --- realtime: Yoni hears when I become available
  final heard = Completer<void>();
  final channel = yoni
      .channel('e2e-availability')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'availability',
        callback: (_) {
          if (!heard.isCompleted) heard.complete();
        },
      );
  final subscribed = Completer<void>();
  channel.subscribe((status, [err]) {
    if (status == RealtimeSubscribeStatus.subscribed &&
        !subscribed.isCompleted) {
      subscribed.complete();
    }
  });
  await subscribed.future.timeout(const Duration(seconds: 15));
  // The server needs a moment after "subscribed" before changes flow.
  await Future<void>.delayed(const Duration(seconds: 2));

  await me.rpc(
    'set_availability',
    params: {'p_mode': 'driving', 'p_minutes': 30},
  );
  try {
    await heard.future.timeout(const Duration(seconds: 10));
    check(true, 'Yoni gets a realtime update when I become available');
  } on TimeoutException {
    check(false, 'Yoni gets a realtime update when I become available');
  }
  final yoniSees = await rows(yoni, 'availability');
  check(
    yoniSees.any((a) => a['user_id'] == uid(me) && a['mode'] == 'driving'),
    'Yoni sees: Netanel is free, driving',
  );
  check(
    (await rows(
      eve,
      'availability',
    )).where((a) => a['user_id'] == uid(me)).isEmpty,
    "a stranger can't see my availability",
  );
  check(
    (await rows(me, 'match_offers')).isEmpty,
    'only I am free → no offer yet',
  );

  // --- both free → offer for both (a call needs at least one number)
  await yoni.from('phone_numbers').upsert({
    'user_id': uid(yoni),
    'phone': '+972501234567',
  });
  await yoni.rpc(
    'set_availability',
    params: {'p_mode': 'walking', 'p_minutes': 20},
  );
  final offersMe = await rows(me, 'match_offers');
  final offersYoni = await rows(yoni, 'match_offers');
  check(
    offersMe.length == 1 && offersYoni.length == 1,
    'both free → one offer, both see it',
  );
  check(
    (await rows(eve, 'match_offers')).isEmpty,
    "a stranger can't see the offer",
  );
  final offerId = offersMe.single['id'] as String;

  // --- mutual acceptance
  check(
    await me.rpc(
          'respond_offer',
          params: {'p_offer': offerId, 'p_accept': true},
        ) ==
        'pending',
    'I accept → still waiting for Yoni',
  );
  check(
    await eve.rpc(
          'respond_offer',
          params: {'p_offer': offerId, 'p_accept': true},
        ) ==
        'not_found',
    "a stranger can't answer our offer",
  );
  // Phone numbers: private, revealed only after both accepted.
  await yoni.from('phone_numbers').upsert({
    'user_id': uid(yoni),
    'phone': '+972501234567',
  });
  check(
    (await rows(
      me,
      'phone_numbers',
    )).where((r) => r['user_id'] == uid(yoni)).isEmpty,
    "I can't read Yoni's number directly",
  );
  final early = List<Map<String, dynamic>>.from(
    await me.rpc('call_details', params: {'p_offer': offerId}),
  ).single;
  check(early['other_phone'] == null, 'no number before both accepted');
  try {
    await eve.from('phone_numbers').insert({
      'user_id': uid(yoni),
      'phone': '+972500000000',
    });
    check(false, "a stranger can't set someone else's number");
  } on PostgrestException {
    check(true, "a stranger can't set someone else's number");
  }

  check(
    await yoni.rpc(
          'respond_offer',
          params: {'p_offer': offerId, 'p_accept': true},
        ) ==
        'accepted',
    'Yoni accepts → match accepted',
  );
  // Only Yoni shared a number → I am the caller (only one side dials).
  final details = List<Map<String, dynamic>>.from(
    await me.rpc('call_details', params: {'p_offer': offerId}),
  ).single;
  check(
    details['other_phone'] == '+972501234567' && details['i_share'] == false,
    'after both accepted the caller (me) gets the number Yoni shared',
  );
  final yoniDetails = List<Map<String, dynamic>>.from(
    await yoni.rpc('call_details', params: {'p_offer': offerId}),
  ).single;
  check(
    yoniDetails['other_phone'] == null,
    'the side that is called gets no number',
  );
  final agreed = (await rows(
    me,
    'match_offers',
  )).firstWhere((o) => o['id'] == offerId);
  check(agreed['caller'] == uid(me), 'the server chose exactly one caller');
  Future<Map<String, dynamic>?> seenBy(
    SupabaseClient who,
    String whose,
  ) async => (await rows(
    who,
    'availability',
  )).where((a) => a['user_id'] == whose).firstOrNull;
  check(
    (await seenBy(me, uid(yoni)))?['call_until'] != null,
    'both said yes → friends see Yoni "in a call"',
  );
  final eveDetails = List<Map<String, dynamic>>.from(
    await eve.rpc('call_details', params: {'p_offer': offerId}),
  ).single;
  check(
    eveDetails['other_phone'] == null,
    "a stranger can't get numbers from our offer",
  );

  // The call is over for both (after the feedback question).
  await me.rpc('end_call', params: {'p_offer': offerId});
  await yoni.rpc('end_call', params: {'p_offer': offerId});
  check(
    (await seenBy(me, uid(yoni)))?['call_until'] == null,
    'call ended → no longer "in a call"',
  );

  // --- right after a call: not the same pair again (30-minute pause)
  await me.rpc('clear_availability');
  await yoni.rpc('clear_availability');
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  await yoni.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 15},
  );
  check(
    (await rows(
      me,
      'match_offers',
    )).where((o) => o['status'] == 'pending').isEmpty,
    'no new offer for the same pair right after a call',
  );

  // --- a round where a friend declines (Tal)
  final tal = await newUser('טל', 'male');
  final invTal = List<Map<String, dynamic>>.from(
    await me.rpc('create_invitation'),
  ).single;
  await tal.rpc('accept_invitation', params: {'p_token': invTal['token']});
  await tal.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 15},
  );
  final second = (await rows(
    me,
    'match_offers',
  )).firstWhere((o) => o['status'] == 'pending');
  await me.rpc(
    'respond_offer',
    params: {'p_offer': second['id'], 'p_accept': true},
  );
  check(
    await tal.rpc(
          'respond_offer',
          params: {'p_offer': second['id'], 'p_accept': false},
        ) ==
        'declined',
    'Tal declines',
  );
  final seenByMe = (await rows(
    me,
    'match_offers',
  )).firstWhere((o) => o['id'] == second['id']);
  check(
    seenByMe['status'] == 'declined',
    'I see only "declined" (the app shows a gentle message)',
  );
  // No immediate re-offer after a decline (cooldown).
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  check(
    (await rows(
      me,
      'match_offers',
    )).where((o) => o['status'] == 'pending').isEmpty,
    'no new offer right after a decline (cooldown)',
  );
  // That was a new window of mine → after the quiet minutes Tal may be
  // asked once more; after a second "no", not again in this window.
  await skipQuietGap();
  await me.rpc('nudge_offers');
  final talAgain = (await rows(
    me,
    'match_offers',
  )).where((o) => o['status'] == 'pending').toList();
  check(
    talAgain.length == 1,
    'a new window: after the quiet minutes, one more question',
  );
  await tal.rpc(
    'respond_offer',
    params: {'p_offer': talAgain.single['id'], 'p_accept': false},
  );
  await skipQuietGap();
  await me.rpc('nudge_offers');
  check(
    (await rows(
      me,
      'match_offers',
    )).where((o) => o['status'] == 'pending').isEmpty,
    'the same friend only once per window',
  );
  await tal.rpc('clear_availability');
  await tal.dispose();

  // --- instant call, one at a time (D-060)
  await skipQuietGap();
  await me.rpc('clear_availability');
  await yoni.rpc('clear_availability');
  final x1 = await newUser('איתי', 'male');
  final x2 = await newUser('נוי', 'female');
  var xPhone = 0;
  for (final x in [x1, x2]) {
    final inv = List<Map<String, dynamic>>.from(
      await me.rpc('create_invitation'),
    ).single;
    await x.rpc('accept_invitation', params: {'p_token': inv['token']});
    await x.from('phone_numbers').upsert({
      'user_id': uid(x),
      'phone': '+97253000000${xPhone++}',
    });
    await x.rpc(
      'set_availability',
      params: {'p_mode': 'free', 'p_minutes': 15},
    );
  }
  await me.from('phone_numbers').upsert({
    'user_id': uid(me),
    'phone': '+972509876543',
  });
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  final myOpen = (await rows(
    me,
    'match_offers',
  )).where((o) => o['status'] == 'pending').toList();
  check(
    myOpen.length == 1,
    'two friends free → still only ONE offer at a time',
  );
  final oneId = myOpen.single['id'] as String;
  final who = myOpen.single['user_a'] == uid(me)
      ? myOpen.single['user_b']
      : myOpen.single['user_a'];
  final picked = who == uid(x1) ? x1 : x2;
  final waiting = who == uid(x1) ? x2 : x1;
  final firstYes = Map<String, dynamic>.from(
    await picked.rpc(
      'answer_offer',
      params: {'p_offer': oneId, 'p_accept': true},
    ),
  );
  check(
    firstYes['status'] == 'pending' && firstYes['phone'] == null,
    'first "yes" → no number yet',
  );
  final t0 = DateTime.now();
  final secondYes = Map<String, dynamic>.from(
    await me.rpc('answer_offer', params: {'p_offer': oneId, 'p_accept': true}),
  );
  final ms = DateTime.now().difference(t0).inMilliseconds;
  check(
    secondYes['status'] == 'accepted' &&
        secondYes['i_call'] == true &&
        (secondYes['phone'] as String).startsWith('+97253'),
    'second "yes" → I am the caller, in the same reply ($ms ms)',
  );
  final pickedSees = (await rows(
    picked,
    'match_offers',
  )).firstWhere((o) => o['id'] == oneId);
  check(
    pickedSees['caller'] == uid(me),
    'the other side sees that I am calling',
  );
  check(
    await waiting.rpc('nudge_offers') == 0 &&
        (await rows(
          waiting,
          'match_offers',
        )).where((o) => o['status'] == 'pending').isEmpty,
    'while I am in a call, nobody gets an offer with me',
  );
  // After the call: "we didn't actually talk" → not counted as a talk.
  await me.rpc(
    'call_feedback',
    params: {'p_offer': oneId, 'p_result': 'no_talk'},
  );
  check(
    (await rows(
          me,
          'match_offers',
        )).firstWhere((o) => o['id'] == oneId)['talked'] ==
        false,
    '"we didn\'t talk" → not counted as a talk (accepted ≠ talked)',
  );
  await waiting.rpc('nudge_offers');
  check(
    (await rows(
          waiting,
          'match_offers',
        )).where((o) => o['status'] == 'pending').length ==
        1,
    'after my call ends, the next friend is offered',
  );
  // Number only to the caller: the picked friend dials me in the next case.
  final nextId = (await rows(
    me,
    'match_offers',
  )).firstWhere((o) => o['status'] == 'pending')['id'];
  await me.rpc('answer_offer', params: {'p_offer': nextId, 'p_accept': true});
  final callerReply = Map<String, dynamic>.from(
    await waiting.rpc(
      'answer_offer',
      params: {'p_offer': nextId, 'p_accept': true},
    ),
  );
  check(
    callerReply['i_call'] == true && callerReply['phone'] == '+972509876543',
    'the caller gets my number in the same reply',
  );
  await me.rpc(
    'call_feedback',
    params: {'p_offer': nextId, 'p_result': 'not_soon'},
  );
  await waiting.rpc(
    'call_feedback',
    params: {'p_offer': nextId, 'p_result': 'good'},
  );
  await waiting.rpc(
    'call_feedback',
    params: {'p_offer': nextId, 'p_result': 'good'},
  );
  check(
    (await rows(
          me,
          'match_offers',
        )).firstWhere((o) => o['id'] == nextId)['talked'] ==
        true,
    '"it was good" → a real talk',
  );
  try {
    await waiting.from('pair_snoozes').select();
    check(false, '"not again soon" is never visible to anyone');
  } on PostgrestException {
    check(true, '"not again soon" is never visible to anyone');
  }
  try {
    await eve.rpc(
      'call_feedback',
      params: {'p_offer': nextId, 'p_result': 'good'},
    );
    check(false, 'a stranger cannot answer for our call');
  } on PostgrestException {
    check(true, 'a stranger cannot answer for our call');
  }
  for (final x in [x1, x2]) {
    await x.rpc('clear_availability');
    await x.dispose();
  }
  await me.from('phone_numbers').delete().eq('user_id', uid(me));

  // --- clearing availability cancels and hides
  await yoni.rpc('clear_availability');
  check(
    (await rows(
      me,
      'availability',
    )).where((a) => a['user_id'] == uid(yoni)).isEmpty,
    'when Yoni stops, I no longer see him as free',
  );

  // --- validation
  try {
    await me.rpc(
      'set_availability',
      params: {'p_mode': 'free', 'p_minutes': 500},
    );
    check(false, 'availability longer than 3 hours is refused');
  } on PostgrestException {
    check(true, 'availability longer than 3 hours is refused');
  }

  // --- automatic driving availability (device token, app closed)
  await me.rpc('clear_availability');
  await yoni.rpc('clear_availability');
  final device = await me.rpc('create_device_token') as String;
  check(device.length >= 40, 'device token is long and random');
  final background = SupabaseClient(
    url,
    anonKey,
  ); // no login, like the phone in the background
  check(
    await background.rpc('auto_start', params: {'p_token': 'x' * 43}) ==
        'bad_token',
    'a wrong device token is refused',
  );
  check(
    await background.rpc('auto_start', params: {'p_token': device}) ==
        'available',
    'trip detected → I become available (driving), app closed',
  );
  final seen = await rows(yoni, 'availability');
  check(
    seen.any((a) => a['user_id'] == uid(me) && a['mode'] == 'driving'),
    'Yoni sees me free (driving)',
  );
  // Another phone call (the background service notices it): yes/no only.
  check(
    await background.rpc(
          'device_phone_call',
          params: {'p_token': 'x' * 43, 'p_on': true},
        ) ==
        'bad_token',
    'a wrong device token can\'t say "in a call"',
  );
  await background.rpc(
    'device_phone_call',
    params: {'p_token': device, 'p_on': true},
  );
  check(
    (await rows(
      yoni,
      'availability',
    )).any((a) => a['user_id'] == uid(me) && a['phone_until'] != null),
    'on another call → Yoni sees me "in a call"',
  );
  check(
    await dbCount(
          "select count(*) from availability where phone_until > now() + interval '4 minutes'",
        ) ==
        0,
    '"in a call" ends by itself within 3 minutes',
  );
  await background.rpc(
    'device_phone_call',
    params: {'p_token': device, 'p_on': false},
  );
  check(
    (await rows(
      yoni,
      'availability',
    )).any((a) => a['user_id'] == uid(me) && a['phone_until'] == null),
    'call ended → free again',
  );
  // (Friends no longer receive the start time, D-118: read it directly.)
  Future<String> tripStartNow() => dbScalar(
    "select started_at from availability where user_id = '${uid(me)}'",
  );
  final tripStart = await tripStartNow();
  await Future<void>.delayed(const Duration(milliseconds: 1100));
  await background.rpc('auto_start', params: {'p_token': device});
  check(
    await tripStartNow() == tripStart,
    'renewing during the drive keeps the same trip',
  );
  // A new friend (Yoni and I are in the 15-minute pause after his "no").
  final dani = await newUser('יוני', 'male');
  final inv2 = List<Map<String, dynamic>>.from(
    await me.rpc('create_invitation'),
  ).single;
  await dani.rpc('accept_invitation', params: {'p_token': inv2['token']});
  await dani.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 30},
  );
  check(
    List.from(
      await background.rpc('auto_offers', params: {'p_token': device}),
    ).isEmpty,
    'the first 5 minutes of a trip: no questions (D-106)',
  );
  // The 5 quiet minutes are over.
  await dbExec(
    "update availability set quiet_until = null where user_id = '${uid(me)}'",
  );
  final pending = List<Map<String, dynamic>>.from(
    await background.rpc('auto_offers', params: {'p_token': device}),
  );
  check(
    pending.length == 1 && pending.single['other_name'] == 'יוני',
    'background check finds "Yoni is free — talk?"',
  );
  check(
    await background.rpc(
          'auto_decline',
          params: {'p_token': device, 'p_offer': pending.single['offer_id']},
        ) ==
        'declined',
    '"not now" from the notification works',
  );
  check(
    List.from(
      await eve.rpc('auto_offers', params: {'p_token': 'y' * 43}),
    ).isEmpty,
    "a stranger's guess sees no offers",
  );
  check(
    await background.rpc('auto_stop', params: {'p_token': device}) == 'stopped',
    'trip ended → automatic availability stops',
  );
  await me.rpc(
    'set_availability',
    params: {'p_mode': 'walking', 'p_minutes': 30},
  );
  check(
    await background.rpc('auto_start', params: {'p_token': device}) ==
        'already_available',
    'a manual "I\'m free" is not overridden by the car',
  );
  check(
    await background.rpc('auto_stop', params: {'p_token': device}) == 'nothing',
    'nor stopped when the trip ends',
  );
  // One-tap button (widget / quick tile), app closed.
  await me.rpc('clear_availability');
  check(
    await background.rpc('device_status', params: {'p_token': device}) == null,
    'button shows "not free"',
  );
  final until = await background.rpc(
    'device_start',
    params: {'p_token': device, 'p_minutes': 30},
  );
  check(until != null, 'one tap → free for 30 minutes');
  check(
    await background.rpc('device_status', params: {'p_token': device}) != null,
    'button shows "free"',
  );
  check(
    await background.rpc('device_start', params: {'p_token': 'z' * 43}) == null,
    'a wrong token cannot make anyone free',
  );
  await background.rpc('device_stop', params: {'p_token': device});
  check(
    await background.rpc('device_status', params: {'p_token': device}) == null,
    'second tap → not free',
  );
  await me.rpc('revoke_device_tokens');
  check(
    await background.rpc('auto_start', params: {'p_token': device}) ==
        'bad_token',
    'turning the feature off revokes the device token',
  );
  try {
    await eve.rpc('device_user', params: {'p_token': device});
    check(false, 'internal token lookup is not callable');
  } on PostgrestException {
    check(true, 'internal token lookup is not callable');
  }
  await background.dispose();

  // --- circles: "available only to family" + mutual quick connect
  await me.rpc('clear_availability');
  await skipQuietGap();
  final ron = await newUser('רון', 'male');
  final inv3 = List<Map<String, dynamic>>.from(
    await me.rpc('create_invitation'),
  ).single;
  await ron.rpc('accept_invitation', params: {'p_token': inv3['token']});
  final family = await me
      .from('circles')
      .insert({'name': 'משפחה'})
      .select()
      .single();
  await me.from('circle_members').insert({
    'circle_id': family['id'],
    'member': uid(dani),
  });
  try {
    await me.from('circle_members').insert({
      'circle_id': family['id'],
      'member': uid(eve),
    });
    check(false, 'only my connections can be added to a circle');
  } on PostgrestException {
    check(true, 'only my connections can be added to a circle');
  }
  check((await rows(dani, 'circles')).isEmpty, "my circles are private");
  await dani.rpc('clear_availability');
  await ron.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 30},
  );
  await me.rpc(
    'set_availability',
    params: {'p_mode': 'walking', 'p_minutes': 30, 'p_circle': family['id']},
  );
  check(
    (await rows(
      ron,
      'availability',
    )).where((a) => a['user_id'] == uid(me)).isEmpty,
    'free only for "family" → Ron (not in it) does not see me',
  );
  check(
    (await rows(
      ron,
      'match_offers',
    )).where((o) => o['status'] == 'pending').isEmpty,
    'and gets no offer',
  );
  // Mom and I turn quick connect on for each other → mutual.
  final mom = await newUser('אמא', 'female');
  final invMom = List<Map<String, dynamic>>.from(
    await me.rpc('create_invitation'),
  ).single;
  await mom.rpc('accept_invitation', params: {'p_token': invMom['token']});
  await me.from('circle_members').insert({
    'circle_id': family['id'],
    'member': uid(mom),
  });
  // Quick connect is per person (D-116): both turn it on for each other.
  await me.rpc('set_quick', params: {'p_user': uid(mom), 'p_on': true});
  await mom.rpc('set_quick', params: {'p_user': uid(me), 'p_on': true});
  await mom.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 30},
  );
  final quickOffer = (await rows(
    me,
    'match_offers',
  )).where((o) => o['quick'] == true).toList();
  check(
    quickOffer.length == 1 && quickOffer.single['status'] == 'accepted',
    'both turned quick connect on for each other → connected at once (no question)',
  );
  final qid = quickOffer.single['id'] as String;
  final qEarly = List<Map<String, dynamic>>.from(
    await me.rpc('call_details', params: {'p_offer': qid}),
  ).single;
  check(
    qEarly['other_phone'] == null,
    'quick connect: no number during the countdown',
  );
  final w1 = Map<String, dynamic>.from(
    await me.rpc('start_call', params: {'p_offer': qid}),
  );
  check(w1['state'] == 'wait', 'quick connect: waits until both phones saw it');
  await mom.rpc('seen_call', params: {'p_offer': qid});
  final w2 = Map<String, dynamic>.from(
    await mom.rpc('start_call', params: {'p_offer': qid}),
  );
  check(
    w2['state'] == 'wait' && (w2['wait_ms'] as int) > 3000,
    'both saw it → 5 seconds to cancel (${w2['wait_ms']} ms left)',
  );
  check(
    await mom.rpc('cancel_call', params: {'p_offer': qid}) == true,
    'either side can cancel',
  );
  final w3 = Map<String, dynamic>.from(
    await me.rpc('start_call', params: {'p_offer': qid}),
  );
  check(
    w3['state'] == 'cancelled',
    'after cancel: no call, the other side knows',
  );
  check(
    await dbCount(
          "select count(*) from availability where user_id = '${uid(me)}' "
          'and call_until is not null',
        ) ==
        0,
    'a cancelled quick connect leaves nobody "in a call" (D-094)',
  );
  await mom.rpc('nudge_offers');
  check(
    (await rows(me, 'match_offers')).where((o) => o['quick'] == true).length ==
        1,
    'quick connect at most once a day per pair',
  );
  check(
    await mom.rpc('nudge_offers') == 0,
    'nudge is harmless when nothing is new',
  );
  // A new quick pair in a NEW availability window: countdown, then one caller.
  await me.rpc('clear_availability');
  await skipQuietGap();
  final shira = await newUser('שירה', 'female');
  final invShira = List<Map<String, dynamic>>.from(
    await me.rpc('create_invitation'),
  ).single;
  await shira.rpc('accept_invitation', params: {'p_token': invShira['token']});
  await me.from('circle_members').insert({
    'circle_id': family['id'],
    'member': uid(shira),
  });
  await me.rpc('set_quick', params: {'p_user': uid(shira), 'p_on': true});
  await shira.rpc('set_quick', params: {'p_user': uid(me), 'p_on': true});
  await mom.rpc('clear_availability');
  await shira.from('phone_numbers').upsert({
    'user_id': uid(shira),
    'phone': '+972521112233',
  });
  await shira.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 30},
  );
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 30});
  final q2 = (await rows(me, 'match_offers'))
      .where(
        (o) =>
            o['quick'] == true &&
            o['status'] == 'accepted' &&
            o['caller'] == null,
      )
      .toList();
  check(q2.length == 1, 'quick connect again in a new availability window');
  final q2id = q2.single['id'] as String;
  await me.rpc('seen_call', params: {'p_offer': q2id});
  await shira.rpc('seen_call', params: {'p_offer': q2id});
  await Future<void>.delayed(const Duration(milliseconds: 5600));
  final r1 = Map<String, dynamic>.from(
    await me.rpc('start_call', params: {'p_offer': q2id}),
  );
  final r2 = Map<String, dynamic>.from(
    await shira.rpc('start_call', params: {'p_offer': q2id}),
  );
  check(
    r1['state'] == 'ready' &&
        r1['i_call'] == true &&
        r1['phone'] == '+972521112233',
    'after 5 seconds the first to ask dials (gets the number)',
  );
  check(
    r2['state'] == 'ready' && r2['i_call'] == false && r2['phone'] == null,
    'the other side is told they will be called (no number)',
  );
  check(
    await shira.rpc('cancel_call', params: {'p_offer': q2id}) == false,
    'no cancel after the 5 seconds',
  );
  await me.rpc('end_call', params: {'p_offer': q2id});
  await shira.rpc('end_call', params: {'p_offer': q2id});
  // An old call can't be replayed to get the number again (D-094).
  await dbExec(
    "update match_offers set accepted_at = now() - interval '31 minutes' "
    "where id = '$q2id'",
  );
  final replay = Map<String, dynamic>.from(
    await me.rpc('answer_offer', params: {'p_offer': q2id, 'p_accept': true}),
  );
  check(
    replay['phone'] == null,
    "an old call can't be replayed to get someone's number",
  );
  // Stopping availability also ends a quick connect that hasn't started.
  await dbExec(
    'insert into match_offers (user_a, user_b, expires_at, status, a_response, '
    'b_response, quick, accepted_at) values ('
    "least('${uid(me)}'::uuid, '${uid(shira)}'::uuid), "
    "greatest('${uid(me)}'::uuid, '${uid(shira)}'::uuid), "
    "now() + interval '5 minutes', 'accepted', 'accept', 'accept', true, now())",
  );
  await shira.rpc('clear_availability');
  check(
    await dbCount(
          "select count(*) from match_offers where quick and status = 'accepted' "
          "and caller is null and '${uid(shira)}' in (user_a, user_b)",
        ) ==
        0,
    'stopping availability also ends a quick connect that has not started',
  );
  await skipQuietGap(); // that cancelled connect starts the 5 quiet minutes
  await shira.dispose();
  await mom.rpc('clear_availability');
  await mom.dispose();
  await dani.dispose();
  await ron.dispose();
  await me.rpc('clear_availability');
  await yoni.rpc('clear_availability');

  // --- blocking (and unblocking)
  await me.rpc('block_user', params: {'p_user': uid(yoni)});
  check(
    (await rows(yoni, 'profiles')).length == 1,
    'after I block Yoni he no longer sees me',
  );
  check(
    (await rows(me, 'connections'))
        .where((c) => c['user_a'] == uid(yoni) || c['user_b'] == uid(yoni))
        .isEmpty,
    'block removes the connection',
  );
  final myBlocks = List<Map<String, dynamic>>.from(await me.rpc('my_blocks'));
  check(myBlocks.single['display_name'] == 'יוני', 'I can see whom I blocked');
  check(
    await me.rpc('unblock_user', params: {'p_user': uid(yoni)}) ==
        'reconnected',
    'unblock brings the connection back',
  );
  check(
    (await rows(yoni, 'profiles')).any((p) => p['display_name'] == 'נתנאל'),
    'after unblocking Yoni sees me again',
  );
  check(
    List.from(await yoni.rpc('my_blocks')).isEmpty,
    "Yoni can't see my block list",
  );

  // --- "I'd like to talk" (D-061): quiet, friend-only priority
  await me.rpc('clear_availability');
  final p1 = await newUser('עומר', 'male');
  final p2 = await newUser('אבא', 'male');
  for (final x in [p1, p2]) {
    final inv = List<Map<String, dynamic>>.from(
      await me.rpc('create_invitation'),
    ).single;
    await x.rpc('accept_invitation', params: {'p_token': inv['token']});
  }
  await me.rpc('set_talk_intent', params: {'p_user': uid(p2), 'p_until': null});
  check(
    (await rows(me, 'talk_intents')).single['to_user'] == uid(p2),
    'I see my own intent',
  );
  check((await rows(p2, 'talk_intents')).isEmpty, 'the friend is never told');
  try {
    await me.rpc(
      'set_talk_intent',
      params: {'p_user': uid(eve), 'p_until': null},
    );
    check(false, 'only for my connections');
  } on PostgrestException {
    check(true, 'only for my connections');
  }
  // The heart no longer reorders offers (D-095): the stars do.
  await me.rpc('set_rating', params: {'p_friend': uid(p2), 'p_rating': 5});
  await p1.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  await p2.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  final withIntent = (await rows(
    me,
    'match_offers',
  )).where((o) => o['status'] == 'pending').toList();
  check(
    withIntent.length == 1 &&
        {
          withIntent.single['user_a'],
          withIntent.single['user_b'],
        }.contains(uid(p2)),
    'Dad has 5 stars → Dad is offered first',
  );
  await me.rpc('clear_talk_intent', params: {'p_user': uid(p2)});
  check((await rows(me, 'talk_intents')).isEmpty, 'I can remove it');
  await me.rpc(
    'answer_offer',
    params: {'p_offer': withIntent.single['id'], 'p_accept': false},
  );
  for (final x in [p1, p2]) {
    await x.rpc('clear_availability');
    await x.dispose();
  }
  await me.rpc('clear_availability');

  // --- circle saved in one step; measurements; delete my account (D-063)
  final temp = await newUser('זמני', 'other');
  final invTemp = List<Map<String, dynamic>>.from(
    await me.rpc('create_invitation'),
  ).single;
  await temp.rpc('accept_invitation', params: {'p_token': invTemp['token']});
  final cid = await me.rpc(
    'save_circle',
    params: {
      'p_id': null,
      'p_name': 'עבודה',
      'p_quick': false,
      'p_members': [uid(temp), uid(eve)],
    },
  );
  final saved = await me
      .from('circle_members')
      .select('member')
      .eq('circle_id', cid as String);
  check(
    saved.length == 1 && saved.single['member'] == uid(temp),
    'a circle is saved in one step, only with my connections',
  );
  try {
    await eve.rpc(
      'save_circle',
      params: {'p_id': cid, 'p_name': 'x', 'p_quick': false, 'p_members': []},
    );
    check(false, "nobody else can change my circle");
  } on PostgrestException {
    check(true, "nobody else can change my circle");
  }
  await temp.rpc('log_event', params: {'p_name': 'dial_started', 'p_ms': 420});
  try {
    final ev = await temp.from('app_events').select();
    check(ev.isEmpty, 'measurements are not readable from the app');
  } on PostgrestException {
    check(true, 'measurements are not readable from the app');
  }
  await temp.rpc('delete_my_account');
  check(
    (await rows(me, 'profiles')).every((p) => p['id'] != uid(temp)),
    'delete my account → gone for my friends too',
  );
  check(
    (await me.from('circle_members').select('member').eq('circle_id', cid))
        .isEmpty,
    '...and from their circles',
  );
  await me.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 15, 'p_circle': cid},
  );
  await me.from('circles').delete().eq('id', cid);
  check(
    await dbCount(
          "select count(*) from availability where user_id = '${uid(me)}'",
        ) ==
        0,
    'deleting a circle ends availability that was only for it',
  );
  await temp.dispose();

  // --- friends from phone contacts: I pick who (D-074)
  String h(String e164) => sha256.convert(utf8.encode(e164)).toString();
  // Fresh numbers each run (earlier runs left users in the local database).
  final n = (DateTime.now().millisecondsSinceEpoch % 9000000) + 1000000;
  final aviPhone = '+97250$n';
  final noaPhone = '+97252$n';
  final avi = await newUser('אבי', 'male');
  final noa = await newUser('נועה', 'female');
  await avi.from('phone_numbers').upsert({
    'user_id': uid(avi),
    'phone': '050$n',
  }); // local form
  await noa.from('phone_numbers').upsert({
    'user_id': uid(noa),
    'phone': noaPhone,
  });
  await noa.rpc(
    'find_friends',
    params: {
      'p_hashes': [h(aviPhone)],
    },
  );
  final listed = List<Map<String, dynamic>>.from(
    await avi.rpc(
      'find_friends',
      params: {
        'p_hashes': [h(noaPhone), h('+972599999998'), h('+972599999997')],
      },
    ),
  );
  check(
    listed.length == 1 && listed.single['display_name'] == 'נועה',
    'a search lists my contacts who use DriveTalk',
  );
  check(
    (await rows(avi, 'profiles')).length == 1,
    'nobody is connected automatically (even when both saved each other)',
  );
  check(
    await dbCount(
          "select count(*) from contact_hashes where owner = '${uid(avi)}'",
        ) ==
        1,
    'the server keeps only numbers of DriveTalk users (not the phone book)',
  );
  try {
    final leaked = await noa.from('contact_hashes').select();
    check(leaked.isEmpty, 'contact hashes are not readable (even my own)');
  } on PostgrestException {
    check(true, 'contact hashes are not readable (even my own)');
  }
  // Reinstalled: a second account with Noa's number → listed once (D-077).
  final noa2 = await newUser('נועה', 'female');
  await noa2.from('phone_numbers').upsert({
    'user_id': uid(noa2),
    'phone': noaPhone,
  });
  final once = List<Map<String, dynamic>>.from(
    await avi.rpc(
      'find_friends',
      params: {
        'p_hashes': [h(noaPhone)],
      },
    ),
  );
  check(
    once.length == 1 && once.single['hash'] == h(noaPhone),
    'two accounts with one number → listed once (with the hash I sent)',
  );
  await noa2.rpc('delete_my_account');
  final gil = await newUser('גיל', 'male');
  final notMine = List.from(
    await avi.rpc(
      'add_contacts',
      params: {
        'p_users': [uid(gil)],
      },
    ),
  );
  check(notMine.isEmpty, "can't add someone who isn't in my contacts");
  final added = List<Map<String, dynamic>>.from(
    await avi.rpc(
      'add_contacts',
      params: {
        'p_users': [uid(noa)],
      },
    ),
  );
  check(
    added.length == 1 &&
        (await rows(noa, 'profiles')).any((p) => p['display_name'] == 'אבי'),
    'I pick Noa → connected at once (no approval)',
  );
  // Noa removes Avi → neither side can add the other from contacts again.
  await noa
      .from('connections')
      .delete()
      .eq(
        'user_a',
        [uid(avi), uid(noa)].reduce((a, b) => a.compareTo(b) < 0 ? a : b),
      )
      .eq(
        'user_b',
        [uid(avi), uid(noa)].reduce((a, b) => a.compareTo(b) > 0 ? a : b),
      );
  final again = List.from(
    await avi.rpc(
      'find_friends',
      params: {
        'p_hashes': [h(noaPhone)],
      },
    ),
  );
  final readd = List.from(
    await avi.rpc(
      'add_contacts',
      params: {
        'p_users': [uid(noa)],
      },
    ),
  );
  check(
    again.isEmpty && readd.isEmpty,
    'removed → not suggested or added again from contacts',
  );
  // Bring back (D-090): only the one who removed can.
  check(
    List.from(await avi.rpc('my_removed')).isEmpty &&
        await avi.rpc('restore_friend', params: {'p_user': uid(noa)}) == false,
    'the removed side cannot force their way back',
  );
  final noaRemoved = List<Map<String, dynamic>>.from(
    await noa.rpc('my_removed'),
  );
  check(
    noaRemoved.length == 1 && noaRemoved.single['display_name'] == 'אבי',
    '"people I removed" lists only my own removals',
  );
  check(
    await noa.rpc('restore_friend', params: {'p_user': uid(avi)}) == true &&
        (await rows(avi, 'profiles')).any((p) => p['display_name'] == 'נועה'),
    'bring back → friends again at once',
  );
  final pairA = [
    uid(avi),
    uid(noa),
  ].reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  final pairB = [
    uid(avi),
    uid(noa),
  ].reduce((a, b) => a.compareTo(b) > 0 ? a : b);
  await noa
      .from('connections')
      .delete()
      .eq('user_a', pairA)
      .eq('user_b', pairB);
  // An invitation link still works (explicit), and clears the removal.
  final invBack = List<Map<String, dynamic>>.from(
    await avi.rpc('create_invitation'),
  ).single;
  await noa.rpc('accept_invitation', params: {'p_token': invBack['token']});
  check(
    (await rows(avi, 'profiles')).any((p) => p['display_name'] == 'נועה'),
    'an invitation connects them again',
  );
  await noa.rpc('clear_contact_hashes');
  check(
    (await rows(avi, 'profiles')).any((p) => p['display_name'] == 'נועה'),
    'deleting synced contacts keeps the friends',
  );

  // Ratings (only mine visible) and "hide my status".
  await avi.rpc('set_rating', params: {'p_friend': uid(noa), 'p_rating': 5});
  final myRatings = await rows(avi, 'friend_ratings');
  check(
    myRatings.length == 1 && myRatings.single['rating'] == 5,
    'I can set and read my rating',
  );
  check(
    (await rows(noa, 'friend_ratings')).isEmpty,
    "nobody sees someone else's rating",
  );
  try {
    await avi.rpc('set_rating', params: {'p_friend': uid(gil), 'p_rating': 4});
    check(false, 'rating only for my friends');
  } on PostgrestException {
    check(true, 'rating only for my friends');
  }
  await avi.rpc('set_rating', params: {'p_friend': uid(noa), 'p_rating': 0});
  await noa.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 15},
  );
  await avi.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 15},
  );
  check(
    (await rows(
      avi,
      'match_offers',
    )).where((o) => o['status'] == 'pending').isEmpty,
    'rating 0 → never offered',
  );
  await avi.rpc('set_rating', params: {'p_friend': uid(noa), 'p_rating': 4});
  await avi.rpc('set_hide_status', params: {'p_hide': true});
  check(
    (await rows(noa, 'availability')).every((a) => a['user_id'] != uid(avi)),
    'hidden → friends do not see that I am free',
  );
  check(
    (await rows(avi, 'availability')).every((a) => a['user_id'] == uid(avi)),
    'hidden → I do not see who is free either',
  );
  check(
    (await rows(
          avi,
          'match_offers',
        )).where((o) => o['status'] == 'pending').length ==
        1,
    'hidden → offers still happen',
  );
  // "Not now — I'll get back to you" (D-076).
  final laterOffer = (await rows(
    noa,
    'match_offers',
  )).firstWhere((o) => o['status'] == 'pending');
  final laterAnswer = Map<String, dynamic>.from(
    await noa.rpc('decline_later', params: {'p_offer': laterOffer['id']}),
  );
  final seenLater = (await rows(
    avi,
    'match_offers',
  )).firstWhere((o) => o['id'] == laterOffer['id']);
  check(
    laterAnswer['status'] == 'declined' && seenLater['later_from'] == uid(noa),
    '"I\'ll get back to you" reaches the other side',
  );
  try {
    await noa.rpc('app_stats', params: {'p_days': 7});
    check(false, 'the numbers are refused to anyone but the owner');
  } on PostgrestException catch (e) {
    check(
      e.message.contains('not_owner'),
      'the numbers are refused to anyone but the owner',
    );
  }
  // The owner's code lives only in the database (D-093): set a test one.
  await dbCount(
    "with s as (insert into owner_secret (id, code_hash) values (1, "
    "encode(extensions.digest('drivetalk-admin:test-owner-code', 'sha256'), 'hex')) "
    "on conflict (id) do update set code_hash = excluded.code_hash returning 1) "
    "select count(*) from s",
  );
  await avi.rpc('claim_owner', params: {'p_code': 'test-owner-code'});
  final stats = Map<String, dynamic>.from(
    await avi.rpc('app_stats', params: {'p_days': 7}),
  );
  check(
    (stats['later'] as num) >= 1 && (stats['users'] as num) >= 2,
    'owner numbers: totals only',
  );
  check(
    !stats.keys.any((k) => k.contains('name') || k.contains('phone')),
    'owner numbers have no names or phone numbers',
  );
  await avi.rpc('set_hide_status', params: {'p_hide': false});
  // Last active: whole days only; feedback to the owner (D-079).
  await noa.rpc('touch_seen');
  final activity = List<Map<String, dynamic>>.from(
    await avi.rpc('friends_activity'),
  );
  check(
    activity.any((a) => a['user_id'] == uid(noa) && a['days'] == 0) &&
        activity.every(
          (a) =>
              a.keys.toSet().containsAll({'user_id', 'days'}) && a.length == 2,
        ),
    'friends see only whole days since last seen',
  );
  check(
    List.from(
      await eve.rpc('friends_activity'),
    ).every((a) => (a as Map)['user_id'] != uid(noa)),
    "strangers don't see it",
  );
  await avi.rpc('send_feedback', params: {'p_body': 'נראה טוב', 'p_build': 61});
  // The owner reads it in the app (D-080).
  try {
    await noa.rpc('owner_feedback');
    check(false, 'only the owner reads feedback');
  } on PostgrestException {
    check(true, 'only the owner reads feedback');
  }
  check(
    await avi.rpc('claim_owner', params: {'p_code': '1234'}) == false,
    'a wrong owner code is refused',
  );
  check(
    await avi.rpc('claim_owner', params: {'p_code': 'test-owner-code'}) == true,
    'the owner code registers the owner',
  );
  final notes = List<Map<String, dynamic>>.from(
    await avi.rpc('owner_feedback'),
  );
  check(
    notes.any((n) => n['body'] == 'נראה טוב' && n['display_name'] == 'אבי'),
    'the owner sees the feedback and who sent it',
  );

  try {
    final leakedNotes = await eve.from('feedback_notes').select();
    check(leakedNotes.isEmpty, 'feedback is readable only by the owner');
  } on PostgrestException {
    check(true, 'feedback is readable only by the owner');
  }

  await avi.rpc('clear_availability');
  await noa.rpc('clear_availability');
  // Privacy fixes from the full review (D-094).
  try {
    await me.from('profiles').select('last_seen_at');
    check(false, "nobody can read when a friend was last active");
  } on PostgrestException {
    check(true, "nobody can read when a friend was last active");
  }
  try {
    await me
        .from('profiles')
        .update({'last_seen_at': '2099-01-01T00:00:00Z'})
        .eq('id', uid(me));
    check(false, "nobody can fake being active");
  } on PostgrestException {
    check(true, "nobody can fake being active");
  }
  await eve.rpc('block_user', params: {'p_user': uid(me)});
  check(
    List.from(await eve.rpc('my_blocks')).isEmpty,
    "blocking a stranger's id reveals nothing about them",
  );
  await dbExec(
    'insert into contact_searches (user_id) '
    "select '${uid(avi)}' from generate_series(1, 30)",
  );
  try {
    await avi.rpc(
      'find_friends',
      params: {
        'p_hashes': [h(noaPhone)],
      },
    );
    check(false, 'contacts search: at most 30 a day');
  } on PostgrestException catch (e) {
    check(
      e.message.contains('rate_limited'),
      'contacts search: at most 30 a day',
    );
  }
  await dbExec("delete from contact_searches where user_id = '${uid(avi)}'");
  // --- who sees that I'm free (D-095)
  final ho = await newUser('הדס', 'female');
  final boss = await newUser('בוס', 'male');
  {
    final inv = List<Map<String, dynamic>>.from(
      await ho.rpc('create_invitation'),
    ).single;
    await boss.rpc('accept_invitation', params: {'p_token': inv['token']});
  }
  await ho.rpc(
    'ensure_preset_circles',
    params: {
      'p_names': ['משפחה', 'חברים', 'עבודה'],
    },
  );
  await ho.rpc(
    'ensure_preset_circles',
    params: {
      'p_names': ['משפחה', 'חברים', 'עבודה'],
    },
  );
  final hoCircles = await rows(ho, 'circles');
  check(
    hoCircles.length == 3,
    'family / friends / work are created once (not twice)',
  );
  final work = hoCircles.firstWhere((c) => c['name'] == 'עבודה');
  await ho.from('circle_members').insert({
    'circle_id': work['id'],
    'member': uid(boss),
  });
  await ho
      .from('circles')
      .update({'show_modes': <String>[]})
      .eq('id', work['id']);
  await ho.rpc(
    'set_availability',
    params: {'p_mode': 'breakTime', 'p_minutes': 15},
  );
  await boss.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 15},
  );
  check(
    (await rows(
      boss,
      'availability',
    )).where((a) => a['user_id'] == uid(ho)).isEmpty,
    'work: never → the boss does not see me free',
  );
  check(
    (await rows(ho, 'availability')).any((a) => a['user_id'] == uid(boss)),
    'I still see the boss free',
  );
  check(
    (await rows(
      ho,
      'match_offers',
    )).where((o) => o['status'] == 'pending').isEmpty,
    'and nobody is asked (an offer would tell him I am free)',
  );
  try {
    await boss.rpc('sees_availability', params: {'p_owner': uid(ho)});
    check(false, '"do I see her?" can\'t be asked directly (D-110)');
  } on PostgrestException {
    check(true, '"do I see her?" can\'t be asked directly (D-110)');
  }
  try {
    await boss.rpc(
      'can_see',
      params: {'p_viewer': uid(boss), 'p_owner': uid(ho), 'p_mode': 'free'},
    );
    check(false, "nobody can probe someone else's rules");
  } on PostgrestException {
    check(true, "nobody can probe someone else's rules");
  }
  check((await rows(boss, 'circles')).isEmpty, "the boss can't see my groups");
  // Only while driving: a break stays hidden, driving is seen.
  await ho
      .from('circles')
      .update({
        'show_modes': ['driving'],
      })
      .eq('id', work['id']);
  check(
    (await rows(
      boss,
      'availability',
    )).where((a) => a['user_id'] == uid(ho)).isEmpty,
    'work: only driving → my break stays hidden',
  );
  await ho.rpc(
    'set_availability',
    params: {'p_mode': 'driving', 'p_minutes': 15},
  );
  check(
    (await rows(boss, 'availability')).any((a) => a['user_id'] == uid(ho)),
    'work: only driving → driving is seen',
  );
  check(
    (await rows(ho, 'match_offers')).any((o) => o['status'] == 'pending'),
    'seen again → we can be asked',
  );
  // "Everyone else": friends in no group.
  await ho.from('circle_members').delete().eq('circle_id', work['id']);
  await ho.from('others_visibility').upsert({
    'user_id': uid(ho),
    'show_modes': <String>[],
  });
  check(
    (await rows(
      boss,
      'availability',
    )).where((a) => a['user_id'] == uid(ho)).isEmpty,
    'everyone else: never → hidden from friends in no group',
  );
  check(
    (await rows(boss, 'others_visibility')).isEmpty,
    "nobody reads my \"everyone else\" rule",
  );
  for (final x in [ho, boss]) {
    await x.rpc('clear_availability');
    await x.dispose();
  }

  // --- no number on either side → no question (the call couldn't happen)
  final nn1 = await newUser('בלי', 'male');
  final nn2 = await newUser('מספר', 'female');
  {
    final inv = List<Map<String, dynamic>>.from(
      await nn1.rpc('create_invitation'),
    ).single;
    await nn2.rpc('accept_invitation', params: {'p_token': inv['token']});
  }
  for (final x in [nn1, nn2]) {
    await x.from('phone_numbers').delete().eq('user_id', uid(x));
    await x.rpc(
      'set_availability',
      params: {'p_mode': 'free', 'p_minutes': 15},
    );
  }
  check(
    (await rows(nn1, 'match_offers')).isEmpty,
    'nobody has a number → no question',
  );
  for (final x in [nn1, nn2]) {
    await x.rpc('clear_availability');
    await x.dispose();
  }

  // --- one person, one row: an old account (same number) hides (D-099)
  final keren = await newUser('קרן', 'female');
  final mOld = await newUser('מעיין', 'female');
  final mNew = await newUser('מעיין', 'female');
  for (final x in [mOld, mNew]) {
    final inv = List<Map<String, dynamic>>.from(
      await keren.rpc('create_invitation'),
    ).single;
    await x.rpc('accept_invitation', params: {'p_token': inv['token']});
    await x.from('phone_numbers').upsert({
      'user_id': uid(x),
      'phone': '+972507777777',
    });
  }
  // Both in use (the old one opened after the new one was made): both show.
  await dbExec(
    "update profiles set last_seen_at = now() where id = '${uid(mOld)}'",
  );
  check(
    (await rows(
          keren,
          'profiles',
        )).where((p) => p['id'] != uid(keren)).length ==
        2,
    'both accounts show while both are in use',
  );
  // A reinstall: the new account was made after the old one's last use.
  await dbExec(
    "update profiles set last_seen_at = "
    "(select created_at - interval '1 minute' from profiles where id = '${uid(mNew)}') "
    "where id = '${uid(mOld)}'",
  );
  check(
    (await rows(
          keren,
          'profiles',
        )).where((p) => p['id'] != uid(keren)).length ==
        1,
    'reinstalled → the old account hides at once (no waiting a day)',
  );
  await dbExec(
    "update profiles set last_seen_at = now() - interval '3 days' "
    "where id = '${uid(mOld)}'",
  );
  final kerenSees = (await rows(
    keren,
    'profiles',
  )).where((p) => p['id'] != uid(keren)).toList();
  check(
    kerenSees.length == 1 && kerenSees.single['id'] == uid(mNew),
    'the old account (same number, unused) is hidden — one row',
  );
  check(
    (await rows(mOld, 'profiles')).any((p) => p['id'] == uid(mOld)),
    'the old account still sees itself (nothing deleted)',
  );
  await dbExec(
    "update profiles set last_seen_at = now() where id = '${uid(mOld)}'",
  );
  check(
    (await rows(keren, 'profiles')).any((p) => p['id'] == uid(mOld)),
    'opened again → shown again',
  );
  for (final x in [keren, mOld, mNew]) {
    await x.dispose();
  }

  // --- a friend reinstalled, I'm only connected to the OLD account: they
  //     don't vanish, and the contacts search offers the new one (D-102)
  final gali = await newUser('גלי', 'female');
  final tOld = await newUser('תמר', 'female');
  {
    final inv = List<Map<String, dynamic>>.from(
      await gali.rpc('create_invitation'),
    ).single;
    await tOld.rpc('accept_invitation', params: {'p_token': inv['token']});
  }
  await tOld.from('phone_numbers').upsert({
    'user_id': uid(tOld),
    'phone': '+972548888888',
  });
  await dbExec(
    "update profiles set last_seen_at = now() - interval '1 hour' "
    "where id = '${uid(tOld)}'",
  );
  final tNew = await newUser('תמר', 'female'); // reinstalled
  await tNew.from('phone_numbers').upsert({
    'user_id': uid(tNew),
    'phone': '+972548888888',
  });
  check(
    (await rows(gali, 'profiles')).any((p) => p['id'] == uid(tOld)),
    "reinstalled friend I'm not connected to anew: still in my list",
  );
  final found = List<Map<String, dynamic>>.from(
    await gali.rpc(
      'find_friends',
      params: {
        'p_hashes': [sha256.convert(utf8.encode('+972548888888')).toString()],
      },
    ),
  );
  check(
    found.length == 1 &&
        found.single['user_id'] == uid(tNew) &&
        found.single['is_friend'] == false,
    'the contacts search offers the account she uses now (to add)',
  );
  await gali.rpc(
    'add_contacts',
    params: {
      'p_users': [uid(tNew)],
    },
  );
  final galiSees = (await rows(
    gali,
    'profiles',
  )).where((p) => p['id'] != uid(gali)).toList();
  check(
    galiSees.length == 1 && galiSees.single['id'] == uid(tNew),
    'added again → one row (the new account)',
  );
  for (final x in [gali, tOld, tNew]) {
    await x.dispose();
  }

  await calmAndPrivate();
  await securityFixes(eve);
  await answerFromNotification();
  await quickPerFriend(eve);
  await quickAndPauses();
  await reviewFixes2();
  await hideStartAndGroup();
  await tripPush();
  await pushEvents();
  await missedAndQuietDays();
  await questionDelivered();

  check(
    await eve.rpc('schema_version') == 51,
    'the server says its version (41)',
  );

  // --- profile photos: private, friends only
  final pic = Uint8List.fromList(List.generate(300, (i) => i % 256));
  final avatars = avi.storage.from('avatars');
  await avatars.uploadBinary(
    '${uid(avi)}.jpg',
    pic,
    fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
  );
  final v = await avi.rpc('set_photo', params: {'p_has': true});
  check(v == 1, 'uploading my photo bumps its version');
  final picSeen = await noa.storage.from('avatars').download('${uid(avi)}.jpg');
  check(picSeen.length == pic.length, 'a friend can download my photo');
  try {
    await eve.storage.from('avatars').download('${uid(avi)}.jpg');
    check(false, "a stranger can't download my photo");
  } on StorageException {
    check(true, "a stranger can't download my photo");
  }
  try {
    await eve.storage
        .from('avatars')
        .uploadBinary(
          '${uid(avi)}.jpg',
          pic,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    check(false, "nobody can replace someone else's photo");
  } on StorageException {
    check(true, "nobody can replace someone else's photo");
  }
  final noaRow = (await rows(
    noa,
    'profiles',
  )).firstWhere((p) => p['id'] == uid(avi));
  check(noaRow['photo_version'] == 1, 'a friend sees the photo version');
  await avatars.remove(['${uid(avi)}.jpg']);
  check(
    await avi.rpc('set_photo', params: {'p_has': false}) == 0,
    'removing the photo resets it',
  );
  await avi.dispose();
  await noa.dispose();

  await channel.unsubscribe();
  for (final c in [me, yoni, eve]) {
    await c.dispose();
  }
  stdout.writeln(failures == 0 ? '\nALL PASSED' : '\n$failures FAILED');
  exit(failures == 0 ? 0 : 1);
}

Future<void> befriend(SupabaseClient a, SupabaseClient b) async {
  final inv = List<Map<String, dynamic>>.from(
    await a.rpc('create_invitation'),
  ).single;
  await b.rpc('accept_invitation', params: {'p_token': inv['token']});
}

Future<void> free(SupabaseClient c, [int minutes = 30]) =>
    c.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': minutes});

Future<Map<String, dynamic>> status(SupabaseClient c) async =>
    Map<String, dynamic>.from(await c.rpc('my_status') as Map);

List<Map<String, dynamic>> pendingOffers(List<Map<String, dynamic>> offers) => [
  for (final o in offers)
    if (o['status'] == 'pending') o,
];

/// D-103…D-106: calmer, more private, clearer about time.
Future<void> calmAndPrivate() async {
  // --- "free without my name" (D-103)
  final ana = await newUser('ענת', 'female');
  final ben = await newUser('בן', 'male');
  final gal = await newUser('גל', 'male');
  await befriend(ana, ben);
  await befriend(gal, ben);
  await ana.rpc('set_settings', params: {'p_anonymous': true});
  await free(ana);
  check(
    !(await rows(ben, 'availability')).any((a) => a['user_id'] == uid(ana)),
    'without my name: a friend doesn\'t see that I\'m free',
  );
  check(
    (await status(ben))['hidden_free'] == 1,
    'without my name: friends see "1 friend free"',
  );
  check((await status(ana))['anonymous'] == true, 'my own setting reads back');
  await free(gal);
  await free(ben);
  final benOffers = pendingOffers(await rows(ben, 'match_offers'));
  check(
    benOffers.length == 1 &&
        {
          benOffers.single['user_a'],
          benOffers.single['user_b'],
        }.contains(uid(gal)),
    'a friend who shows their name is asked first',
  );
  check(
    benOffers.single['shared_until'] != null,
    'the question says until when both are free',
  );
  // Fair: who hides their name sees only a number too.
  await ana.rpc('clear_availability');
  await free(ana);
  check(
    !(await rows(ana, 'availability')).any((a) => a['user_id'] != uid(ana)),
    'without my name: I see no names either',
  );
  check(
    ((await status(ana))['hidden_free'] as num) >= 1,
    'without my name: I see how many are free',
  );
  for (final c in [ana, ben, gal]) {
    await c.rpc('clear_availability');
  }
  await ana.rpc('set_settings', params: {'p_anonymous': false});

  // --- hide "in a call" (D-106)
  await ana.rpc('set_settings', params: {'p_hide_in_call': true});
  await skipQuietGap();
  final token = await ana.rpc('create_device_token') as String;
  final bg = SupabaseClient(url, anonKey);
  await free(ana);
  check(
    (await rows(ben, 'availability')).any((a) => a['user_id'] == uid(ana)),
    'free and not in a call: friends see me',
  );
  await bg.rpc('device_phone_call', params: {'p_token': token, 'p_on': true});
  check(
    !(await rows(ben, 'availability')).any((a) => a['user_id'] == uid(ana)),
    'hide "in a call": in a call I simply look not free',
  );
  // Both ways (D-114): whoever hides doesn't see others in a call either.
  await ana.rpc('set_settings', params: {'p_hide_in_call': false});
  check(
    (await rows(ben, 'availability')).any((a) => a['user_id'] == uid(ana)),
    'in a call, not hiding: friends see me',
  );
  await ben.rpc('set_settings', params: {'p_hide_in_call': true});
  check(
    !(await rows(ben, 'availability')).any((a) => a['user_id'] == uid(ana)),
    'hiding in a call is mutual: I don\'t see friends who are in a call',
  );
  await ben.rpc('set_settings', params: {'p_hide_in_call': false});
  check(
    (await rows(ben, 'availability')).any((a) => a['user_id'] == uid(ana)),
    'hiding in a call is mutual: turned off → I see them again',
  );
  await bg.rpc('device_phone_call', params: {'p_token': token, 'p_on': false});
  await ana.rpc('clear_availability');
  await ana.rpc('set_settings', params: {'p_hide_in_call': false});

  // --- no answer → not offered (and not seen) until "still free" (D-104)
  await skipQuietGap();
  await free(ana);
  await free(ben);
  var offer = pendingOffers(await rows(ana, 'match_offers')).single;
  await ana.rpc(
    'answer_offer',
    params: {'p_offer': offer['id'], 'p_accept': true},
  );
  // 30 seconds without an answer from Ben; I stop waiting.
  await dbExec(
    "update match_offers set created_at = created_at - interval '30 seconds' "
    "where id = '${offer['id']}'",
  );
  await ana.rpc(
    'answer_offer',
    params: {'p_offer': offer['id'], 'p_accept': false},
  );
  final benMine = (await rows(
    ben,
    'availability',
  )).firstWhere((a) => a['user_id'] == uid(ben));
  check(benMine['missed_at'] != null, 'no answer → marked on my side');
  check(
    !(await rows(gal, 'availability')).any((a) => a['user_id'] == uid(ben)),
    'no answer → friends see me as not free',
  );
  // Ana said yes: she isn't held 5 minutes; Gal becomes free → asked now.
  await befriend(ana, gal);
  await free(gal);
  final anaOffers = pendingOffers(await rows(ana, 'match_offers'));
  check(
    anaOffers.length == 1 &&
        {
          anaOffers.single['user_a'],
          anaOffers.single['user_b'],
        }.contains(uid(gal)),
    'whoever said yes gets the next friend right away',
  );
  check(
    pendingOffers(await rows(ben, 'match_offers')).isEmpty,
    'no answer → no more questions for me',
  );
  check(await ben.rpc('still_free') == true, '"still free" works');
  check(
    (await rows(gal, 'availability')).any((a) => a['user_id'] == uid(ben)),
    '"still free" → friends see me again',
  );
  for (final c in [ana, ben, gal]) {
    await c.rpc('clear_availability');
  }

  // --- tap a free friend: ask directly (D-104)
  await skipQuietGap();
  await free(ben);
  check(
    await ana.rpc('ask_friend', params: {'p_user': uid(ben)}) == 'me_not_free',
    'asking needs me to be free',
  );
  await ana.rpc('set_settings', params: {'p_anonymous': true});
  await free(ana);
  // (Ana and Ben may already have a question from the matching.)
  for (final o in pendingOffers(await rows(ana, 'match_offers'))) {
    await ana.rpc(
      'answer_offer',
      params: {'p_offer': o['id'], 'p_accept': false},
    );
  }
  await skipQuietGap();
  await dbExec(
    "update match_offers set created_at = created_at - interval '1 hour' "
    "where '${uid(ana)}' in (user_a, user_b)",
  );
  check(
    await ana.rpc('ask_friend', params: {'p_user': uid(ben)}) == 'not_free',
    'without my name I can\'t pick a friend by name',
  );
  await ana.rpc('set_settings', params: {'p_anonymous': false});
  final asked = await ana.rpc('ask_friend', params: {'p_user': uid(ben)});
  check(asked == 'asked', 'tap a free friend → they are asked now');
  offer = pendingOffers(await rows(ben, 'match_offers')).single;
  check(
    offer['direct'] == true &&
        (offer['user_a'] == uid(ana)
                ? offer['a_response']
                : offer['b_response']) ==
            'accept',
    'my tap counts as my yes',
  );
  final r = Map<String, dynamic>.from(
    await ben.rpc(
          'answer_offer',
          params: {'p_offer': offer['id'], 'p_accept': true},
        )
        as Map,
  );
  check(r['status'] == 'accepted', 'their yes → a call');
  for (final c in [ana, ben]) {
    await c.rpc('end_call', params: {'p_offer': offer['id']});
    await c.rpc('clear_availability');
  }

  // --- extend my free time
  await free(gal, 10);
  final before = DateTime.parse(
    (await rows(
          gal,
          'availability',
        )).firstWhere((a) => a['user_id'] == uid(gal))['expires_at']
        as String,
  );
  final after = DateTime.parse(
    await gal.rpc('extend_availability', params: {'p_minutes': 20}) as String,
  );
  check(
    after.difference(before).inMinutes == 20,
    '"extend" adds minutes to my free time',
  );
  await gal.rpc('clear_availability');

  // --- automatic trip: quiet hours, 5 quiet minutes, one question (D-106)
  final dov = await newUser('דב', 'male');
  final eli = await newUser('אלי', 'male');
  final hila = await newUser('הילה', 'female');
  await befriend(dov, eli);
  await befriend(dov, hila);
  final dovToken = await dov.rpc('create_device_token') as String;
  await dov.rpc(
    'set_settings',
    params: {'p_quiet_from': 0, 'p_quiet_to': 1439, 'p_time_zone': 'UTC'},
  );
  check(
    await bg.rpc('auto_start', params: {'p_token': dovToken}) == 'quiet_hours',
    'quiet hours: a trip doesn\'t make me free',
  );
  await dov.rpc('set_settings', params: {'p_clear_quiet': true});
  check(
    await bg.rpc('auto_start', params: {'p_token': dovToken}) == 'available',
    'outside quiet hours: a trip makes me free',
  );
  await free(eli);
  await free(hila);
  check(
    pendingOffers(await rows(dov, 'match_offers')).isEmpty,
    'the first 5 minutes of a trip: no question',
  );
  check(
    await dov.rpc('ready_now') == true,
    '"ready now" ends the 5 quiet minutes',
  );
  offer = pendingOffers(await rows(dov, 'match_offers')).single;
  // Dov doesn't answer; the question runs out.
  await dbExec(
    "update availability set started_at = started_at - interval '5 minutes' "
    "where user_id = '${uid(dov)}'",
  );
  await dbExec(
    "update match_offers set created_at = now() - interval '3 minutes', "
    "expires_at = now() - interval '1 second' where id = '${offer['id']}'",
  );
  await dbExec('select public.expire_stale()');
  check(
    (await status(dov))['auto_missed'] == 1,
    'a missed question on a trip is counted',
  );
  await dov.rpc('still_free');
  await skipQuietGap();
  await dov.rpc('nudge_offers');
  check(
    pendingOffers(await rows(dov, 'match_offers')).isEmpty,
    'one unanswered question per trip — no second one',
  );
  await dov.rpc('keep_auto');
  check(
    (await status(dov))['auto_missed'] == 0,
    '"keep automatic" resets the count',
  );
  await bg.rpc('auto_stop', params: {'p_token': dovToken});
  for (final c in [eli, hila]) {
    await c.rpc('clear_availability');
  }

  // --- added from contacts by someone I haven't saved (D-106)
  String h(String e164) => sha256.convert(utf8.encode(e164)).toString();
  final n = (DateTime.now().millisecondsSinceEpoch % 9000000) + 1000000;
  final yaelPhone = '+97253$n';
  final omerPhone = '+97255$n';
  final yael = await newUser('יעל', 'female');
  final omer = await newUser('עומר', 'male');
  await yael.from('phone_numbers').upsert({
    'user_id': uid(yael),
    'phone': yaelPhone,
  });
  await omer.from('phone_numbers').upsert({
    'user_id': uid(omer),
    'phone': omerPhone,
  });
  await omer.rpc(
    'find_friends',
    params: {
      'p_hashes': [h(yaelPhone)],
    },
  );
  await omer.rpc(
    'add_contacts',
    params: {
      'p_users': [uid(yael)],
    },
  );
  check(
    List.from((await status(yael))['pending'] as List).contains(uid(omer)),
    'I\'m asked whether to keep someone who added me',
  );
  await free(yael);
  check(
    !(await rows(omer, 'availability')).any((a) => a['user_id'] == uid(yael)),
    'until I decide, they don\'t see when I\'m free',
  );
  check(
    (await rows(yael, 'profiles')).any((p) => p['id'] == uid(omer)),
    'I do see who added me',
  );
  await free(omer);
  check(
    pendingOffers(await rows(omer, 'match_offers')).isEmpty,
    'until I decide, no question between us',
  );
  check(
    await yael.rpc('approve_friend', params: {'p_user': uid(omer)}) == true,
    '"keep" works',
  );
  check(
    (await rows(omer, 'availability')).any((a) => a['user_id'] == uid(yael)),
    'after "keep" they see when I\'m free',
  );
  check(
    pendingOffers(await rows(omer, 'match_offers')).length == 1,
    'after "keep" a question can come',
  );

  // --- only friends I can really ask are listed (D-107)
  final kim = await newUser('קים', 'female');
  final lev = await newUser('לב', 'male');
  await befriend(kim, lev);
  await free(lev);
  Future<List<String>> askable(SupabaseClient c) async => [
    for (final x in await c.rpc('askable_friends') as List) '$x',
  ];
  check(
    (await askable(kim)).contains(uid(lev)),
    'a free friend I can ask is listed (even when I\'m not free)',
  );
  await lev.rpc('set_rating', params: {'p_friend': uid(kim), 'p_rating': 0});
  check(
    !(await askable(kim)).contains(uid(lev)),
    'someone who doesn\'t want questions from me isn\'t listed',
  );
  await lev.rpc('set_rating', params: {'p_friend': uid(kim), 'p_rating': 3});
  await free(kim);
  for (final o in pendingOffers(await rows(kim, 'match_offers'))) {
    await lev.rpc(
      'answer_offer',
      params: {'p_offer': o['id'], 'p_accept': false},
    );
  }
  check(
    !(await askable(kim)).contains(uid(lev)),
    'someone who just said no to me isn\'t listed',
  );
  check(
    await kim.rpc('ask_friend', params: {'p_user': uid(lev)}) == 'not_now',
    'and tapping them doesn\'t ask again',
  );
  check(
    await lev.rpc('ask_friend', params: {'p_user': uid(kim)}) == 'asked',
    'my own "no" never stops me from tapping them myself',
  );
  for (final c in [kim, lev]) {
    await c.rpc('clear_availability');
  }

  // --- after a call: when to suggest them again (D-108)
  final ron = await newUser('רון', 'male');
  final tal = await newUser('טל', 'female');
  await befriend(ron, tal);
  await free(ron);
  await free(tal);
  var call = pendingOffers(await rows(ron, 'match_offers')).single;
  await ron.rpc(
    'answer_offer',
    params: {'p_offer': call['id'], 'p_accept': true},
  );
  await tal.rpc(
    'answer_offer',
    params: {'p_offer': call['id'], 'p_accept': true},
  );
  call = (await rows(
    ron,
    'match_offers',
  )).firstWhere((o) => o['id'] == call['id']);
  check(call['talked'] == true, 'a call counts as a talk right away');
  String pair(String a, String b) =>
      "((from_user = '$a' and to_user = '$b') or (from_user = '$b' and to_user = '$a'))";
  check(
    await dbCount(
          "select count(*) from pair_snoozes where ${pair(uid(ron), uid(tal))} "
          "and until > now() + interval '2 days 23 hours'",
        ) ==
        2,
    'after a call: 3 quiet days for the pair (each side)',
  );
  await ron.rpc(
    'after_call',
    params: {'p_offer': call['id'], 'p_days': 0, 'p_talked': true},
  );
  await tal.rpc(
    'after_call',
    params: {'p_offer': call['id'], 'p_days': 7, 'p_talked': false},
  );
  check(
    (await rows(
          ron,
          'match_offers',
        )).firstWhere((o) => o['id'] == call['id'])['talked'] ==
        false,
    '"we didn\'t manage to talk" takes the talk back',
  );
  check(
    await dbCount(
          "select count(*) from pair_snoozes where from_user = '${uid(ron)}' "
          "and to_user = '${uid(tal)}'",
        ) ==
        0,
    '"any time" removes my pause',
  );
  // The longer one wins: Tal asked for a week → no automatic question.
  await dbExec(
    "update match_offers set accepted_at = accepted_at - interval '1 hour' "
    "where id = '${call['id']}'",
  );
  await skipQuietGap();
  await ron.rpc('nudge_offers');
  check(
    pendingOffers(await rows(ron, 'match_offers')).isEmpty,
    'a pause by either side stops the automatic suggestions',
  );
  check(
    await ron.rpc('ask_friend', params: {'p_user': uid(tal)}) == 'asked',
    'during a pause, tapping still asks',
  );
  final talToken = await tal.rpc('create_device_token') as String;
  final talBg = SupabaseClient(url, anonKey);
  final heard = List<Map<String, dynamic>>.from(
    await talBg.rpc('auto_offers', params: {'p_token': talToken}),
  );
  check(
    heard.length == 1 && heard.single['kind'] == 'direct',
    'the phone says "Ron wants to talk with you" (not "Ron is free")',
  );
  await talBg.dispose();
  for (final c in [ron, tal]) {
    await c.rpc('clear_availability');
  }

  // --- crash notes: short, only the owner reads them
  await yael.rpc(
    'report_crash',
    params: {
      'p_build': '99',
      'p_kind': 'flutter',
      'p_message': 'x' * 900,
      'p_stack': 'y' * 9000,
    },
  );
  check(
    await dbCount(
          "select count(*) from crash_reports where user_id = '${uid(yael)}' "
          'and length(message) = 500 and length(stack) = 4000',
        ) ==
        1,
    'a crash note is saved (and trimmed)',
  );
  try {
    await yael.rpc('owner_crashes');
    check(false, 'only the owner reads crash notes');
  } on PostgrestException {
    check(true, 'only the owner reads crash notes');
  }

  for (final c in [yael, omer]) {
    await c.rpc('clear_availability');
  }
  for (final c in [
    ana,
    ben,
    gal,
    dov,
    eli,
    hila,
    yael,
    omer,
    kim,
    lev,
    ron,
    tal,
    bg,
  ]) {
    await c.dispose();
  }
}

/// D-110: the server can't be asked about other people; numbers only for
/// friends; flood limits; the owner can't be locked out; nightly cleanup.
Future<void> securityFixes(SupabaseClient eve) async {
  final sa = await newUser('סהר', 'female');
  final sb = await newUser('שי', 'male');
  await befriend(sa, sb);
  await free(sb);

  // --- helper checks: only the privacy rules use them
  final asks = <String, Map<String, dynamic>>{
    'sees_availability': {'p_owner': uid(sb)},
    'are_connected': {'x': uid(sa), 'y': uid(sb)},
    'is_blocked_between': {'x': uid(eve), 'y': uid(sb)},
    'awaits_approval': {'p_owner': uid(sa), 'p_viewer': uid(sb)},
    'in_audience': {'p_circle': uid(sb), 'viewer': uid(sa)},
    'is_anonymous': {'p_user': uid(sb)},
    'hides_call': {'p_user': uid(sb)},
    'hides_status': {'p_user': uid(sb)},
    'replaced_account': {'p_user': uid(sb)},
    'replaced_for': {'p_viewer': uid(sa), 'p_user': uid(sb)},
    'can_see_avatar': {'p_name': '${uid(sb)}.jpg'},
  };
  var refused = 0;
  for (final e in asks.entries) {
    try {
      await eve.rpc(e.key, params: e.value);
      stdout.writeln('      (answered: ${e.key})');
    } on PostgrestException {
      refused++;
    }
  }
  check(
    refused == asks.length,
    "nobody can ask the server's helper checks about others "
    '($refused/${asks.length} refused)',
  );
  check(
    (await rows(sa, 'availability')).any((a) => a['user_id'] == uid(sb)),
    'the privacy rules still work: a friend sees me free',
  );
  check(
    (await rows(eve, 'availability')).every((a) => a['user_id'] != uid(sb)),
    '… and a stranger still does not',
  );
  check(
    (await rows(sa, 'profiles')).any((p) => p['id'] == uid(sb)),
    '… and friends still see each other',
  );

  // --- a number only while still friends
  await free(sa);
  final offer = pendingOffers(await rows(sa, 'match_offers')).single;
  await sa.rpc(
    'answer_offer',
    params: {'p_offer': offer['id'], 'p_accept': true},
  );
  await sb.rpc(
    'answer_offer',
    params: {'p_offer': offer['id'], 'p_accept': true},
  );
  for (final c in [sa, sb]) {
    await c.rpc('seen_call', params: {'p_offer': offer['id']});
  }
  // Whoever calls gets the number (both shared one).
  var caller = sa;
  var other = sb;
  var before = <String, dynamic>{};
  for (var i = 0; i < 12 && before['state'] != 'ready'; i++) {
    before = Map<String, dynamic>.from(
      await sa.rpc('start_call', params: {'p_offer': offer['id']}) as Map,
    );
    if (before['state'] != 'ready') {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
  if (before['i_call'] != true) {
    caller = sb;
    other = sa;
    before = Map<String, dynamic>.from(
      await sb.rpc('start_call', params: {'p_offer': offer['id']}) as Map,
    );
  }
  await other.from('connections').delete().neq('user_a', uid(eve));
  final after = Map<String, dynamic>.from(
    await caller.rpc('start_call', params: {'p_offer': offer['id']}) as Map,
  );
  final details = List<Map<String, dynamic>>.from(
    await caller.rpc('call_details', params: {'p_offer': offer['id']}),
  ).single;
  check(
    before['phone'] != null &&
        after['phone'] == null &&
        details['other_phone'] == null,
    'removed as a friend → their number is no longer given',
  );
  await befriend(sa, sb);

  // --- reports: once per person and reason a day, up to 20 a day
  for (var i = 0; i < 3; i++) {
    await sa.from('reports').insert({'reported': uid(eve), 'reason': 'spam'});
  }
  check(
    await dbCount(
          "select count(*) from reports where reporter = '${uid(sa)}'",
        ) ==
        1,
    'the same report three times is kept once',
  );
  await dbExec(
    "set session_replication_role = replica; "
    "insert into reports (reporter, reported, reason, created_at) "
    "select '${uid(sa)}', '${uid(sb)}', 'other', now() - interval '1 hour' "
    "from generate_series(1, 19)",
  );
  await sa.from('reports').insert({
    'reported': uid(eve),
    'reason': 'harassment',
  });
  check(
    await dbCount(
          "select count(*) from reports where reporter = '${uid(sa)}'",
        ) ==
        20,
    'up to 20 reports a day from one person',
  );

  // --- brand-new accounts share one hourly cap (feedback)
  await dbExec(
    "insert into feedback_notes (user_id, body) "
    "select '${uid(sb)}', 'x' from generate_series(1, 30)",
  );
  try {
    await sa.rpc('send_feedback', params: {'p_body': 'hello'});
    check(false, 'a flood from new accounts stops more feedback from new ones');
  } on PostgrestException catch (e) {
    check(
      e.message.contains('rate_limited'),
      'a flood from new accounts stops more feedback from new ones',
    );
  }
  await dbExec(
    "update profiles set created_at = now() - interval '2 days' "
    "where id = '${uid(sa)}'",
  );
  await sa.rpc('send_feedback', params: {'p_body': 'hello'});
  check(
    await dbCount(
          "select count(*) from feedback_notes where user_id = '${uid(sa)}'",
        ) ==
        1,
    '… but not from people who joined earlier',
  );
  await dbExec("delete from feedback_notes where user_id = '${uid(sb)}'");

  // --- owner code: others' wrong guesses can't lock the owner out
  await dbExec(
    "insert into owner_claims (user_id, at) "
    "select '${uid(sb)}', now() from generate_series(1, 150)",
  );
  final boss2 = await newUser('בעלים', 'male');
  check(
    await boss2.rpc('claim_owner', params: {'p_code': 'test-owner-code'}) ==
        true,
    "150 wrong guesses by others don't lock the owner out",
  );
  await dbExec("delete from app_owners where user_id = '${uid(boss2)}'");
  for (var i = 0; i < 4; i++) {
    await sa.rpc('claim_owner', params: {'p_code': 'wrong'});
  }
  try {
    await sa.rpc('claim_owner', params: {'p_code': 'wrong'});
    await sa.rpc('claim_owner', params: {'p_code': 'test-owner-code'});
    check(false, 'after 5 tries in an hour: "too many tries"');
  } on PostgrestException catch (e) {
    check(
      e.message.contains('rate_limited'),
      'after 5 tries in an hour: "too many tries"',
    );
  }
  check(
    await dbCount(
          "select count(*) from app_owners where user_id = '${uid(sa)}'",
        ) ==
        0,
    '… and the right code then still waits',
  );

  // --- nightly cleanup
  await dbExec(
    "update match_offers set created_at = now() - interval '100 days' "
    "where id = '${offer['id']}'",
  );
  final lo = uid(sa).compareTo(uid(sb)) < 0 ? uid(sa) : uid(sb);
  final hi = lo == uid(sa) ? uid(sb) : uid(sa);
  await dbExec(
    "insert into match_offers (user_a, user_b, expires_at, status, created_at) "
    "values ('$lo', '$hi', now() - interval '120 days', 'expired', "
    "now() - interval '120 days'); "
    "insert into app_events (user_id, name, created_at) "
    "values ('${uid(sa)}', 'old_event', now() - interval '100 days'); "
    'select public.nightly_cleanup();',
  );
  check(
    await dbCount(
              "select count(*) from match_offers where user_a = '$lo' "
              "and user_b = '$hi' and created_at < now() - interval '90 days'",
            ) ==
            1 &&
        await dbCount(
              "select count(*) from match_offers where id = '${offer['id']}'",
            ) ==
            1,
    'nightly cleanup: old offers go, the last talk of a pair stays',
  );
  check(
    await dbCount("select count(*) from app_events where name = 'old_event'") ==
        0,
    'nightly cleanup: activity older than 90 days goes',
  );
  check(
    await dbCount(
          "select count(*) from cron.job where jobname = 'drivetalk-nightly-cleanup'",
        ) ==
        1,
    'the cleanup runs every night',
  );
  for (final c in [sa, sb]) {
    await c.rpc('clear_availability');
  }
  for (final c in [sa, sb, boss2]) {
    await c.dispose();
  }
}

/// D-111: "Talk" straight from the notification (device token): the one
/// who answered there gets called; a call to dial shows up for the phone.
Future<void> answerFromNotification() async {
  final na = await newUser('נועה', 'female');
  final nb = await newUser('ניר', 'male');
  await befriend(na, nb);
  final tokenA = await na.rpc('create_device_token') as String;
  final tokenB = await nb.rpc('create_device_token') as String;
  final bg = SupabaseClient(url, anonKey);

  // Noa says yes in the app, Nir from the notification → Noa dials Nir.
  await free(na);
  await free(nb);
  var offer = pendingOffers(await rows(na, 'match_offers')).single;
  await na.rpc(
    'answer_offer',
    params: {'p_offer': offer['id'], 'p_accept': true},
  );
  final r = Map<String, dynamic>.from(
    await bg.rpc(
          'device_answer',
          params: {'p_token': tokenB, 'p_offer': offer['id']},
        )
        as Map,
  );
  check(
    r['status'] == 'accepted' && r['i_call'] == false,
    '"Talk" in the notification answers yes — and the other side calls me',
  );
  final callsB = List<Map<String, dynamic>>.from(
    await bg.rpc('device_calls', params: {'p_token': tokenB}),
  );
  final callsA = List<Map<String, dynamic>>.from(
    await bg.rpc('device_calls', params: {'p_token': tokenA}),
  );
  check(
    callsB.length == 1 &&
        callsB.single['i_call'] == false &&
        callsA.length == 1 &&
        callsA.single['i_call'] == true,
    'each phone knows who dials (Noa dials, Nir waits for the ring)',
  );
  check(
    (await bg.rpc(
              'device_answer',
              params: {'p_token': 'x' * 40, 'p_offer': offer['id']},
            )
            as Map)['status'] ==
        'bad_token',
    'a wrong device token answers nothing',
  );
  for (final c in [na, nb]) {
    await c.rpc('end_call', params: {'p_offer': offer['id']});
  }

  // Nir answers first from the notification, Noa later in the app →
  // still Noa dials (Nir can't dial from the background).
  await dbExec(
    "delete from pair_snoozes where from_user in ('${uid(na)}', '${uid(nb)}')",
  );
  await dbExec(
    "update match_offers set accepted_at = accepted_at - interval '1 hour', "
    "updated_at = updated_at - interval '1 hour' where id = '${offer['id']}'",
  );
  await skipQuietGap();
  await na.rpc('nudge_offers');
  final pend = pendingOffers(await rows(na, 'match_offers'));
  if (pend.isEmpty) {
    check(false, 'a second question for the pair (setup)');
  } else {
    offer = pend.single;
    final first = Map<String, dynamic>.from(
      await bg.rpc(
            'device_answer',
            params: {'p_token': tokenB, 'p_offer': offer['id']},
          )
          as Map,
    );
    final second = Map<String, dynamic>.from(
      await na.rpc(
            'answer_offer',
            params: {'p_offer': offer['id'], 'p_accept': true},
          )
          as Map,
    );
    check(
      first['status'] == 'pending' &&
          second['status'] == 'accepted' &&
          second['i_call'] == true &&
          second['phone'] != null,
      'answered first from the notification → the other one dials me',
    );
  }
  for (final c in [na, nb]) {
    await c.rpc('clear_availability');
  }
  await bg.dispose();
  for (final c in [na, nb]) {
    await c.dispose();
  }
}

/// D-112: quick connect per friend — one switch each; both on → the call
/// starts by itself (5 seconds to cancel), without a question.
Future<void> quickPerFriend(SupabaseClient eve) async {
  final qa = await newUser('קרן', 'female');
  final qb = await newUser('קובי', 'male');
  await befriend(qa, qb);
  await qa.rpc('set_quick', params: {'p_user': uid(qb), 'p_on': true});
  final seen = List<Map<String, dynamic>>.from(await qb.rpc('quick_status'));
  check(
    seen.length == 1 &&
        seen.single['user_id'] == uid(qa) &&
        seen.single['mine'] == false &&
        seen.single['theirs'] == true,
    'a friend sees "X wants quick connect with you"',
  );
  try {
    await eve.rpc('set_quick', params: {'p_user': uid(qb), 'p_on': true});
    check(false, "quick connect only with a friend");
  } on PostgrestException {
    check(true, "quick connect only with a friend");
  }
  check(
    List.from(await eve.rpc('quick_status')).isEmpty,
    'a stranger sees nothing',
  );
  await qb.rpc('set_quick', params: {'p_user': uid(qa), 'p_on': true});
  await free(qa);
  await free(qb);
  final quick = (await rows(
    qa,
    'match_offers',
  )).where((o) => o['quick'] == true).toList();
  check(
    quick.length == 1 && quick.single['status'] == 'accepted',
    'both turned it on → no question: the call starts (5 seconds to cancel)',
  );
  for (final c in [qa, qb]) {
    await c.rpc('clear_availability');
  }
  await qb.from('connections').delete().neq('user_a', uid(eve));
  check(
    await dbCount(
          "select count(*) from quick_picks where owner in "
          "('${uid(qa)}', '${uid(qb)}')",
        ) ==
        0,
    'no longer friends → the switch is gone too',
  );
  for (final c in [qa, qb]) {
    await c.dispose();
  }
}

/// D-113: the automatic pause after a call doesn't stop quick connect; my
/// pause shows on the friend's card and can be cancelled.
Future<void> quickAndPauses() async {
  final pa = await newUser('פזית', 'female');
  final pb = await newUser('פנחס', 'male');
  await befriend(pa, pb);
  await free(pa);
  await free(pb);
  final first = pendingOffers(await rows(pa, 'match_offers')).single;
  for (final c in [pa, pb]) {
    await c.rpc(
      'answer_offer',
      params: {'p_offer': first['id'], 'p_accept': true},
    );
  }
  final mine = List<Map<String, dynamic>>.from(await pa.rpc('my_pauses'));
  check(
    mine.length == 1 &&
        mine.single['user_id'] == uid(pb) &&
        mine.single['chosen'] == false,
    'after a call: my automatic pause shows (3 days)',
  );
  for (final c in [pa, pb]) {
    await c.rpc('end_call', params: {'p_offer': first['id']});
    await c.rpc('clear_availability');
  }
  await dbExec(
    "update match_offers set accepted_at = accepted_at - interval '1 hour', "
    "created_at = created_at - interval '1 hour' where id = '${first['id']}'",
  );
  await pa.rpc('set_quick', params: {'p_user': uid(pb), 'p_on': true});
  await pb.rpc('set_quick', params: {'p_user': uid(pa), 'p_on': true});
  await free(pa);
  await free(pb);
  final quick = (await rows(
    pa,
    'match_offers',
  )).where((o) => o['quick'] == true).toList();
  check(quick.length == 1, 'quick connect works during the automatic pause');
  // The quick call happened (its 5 seconds are over) …
  await dbExec(
    "update match_offers set not_before = now() - interval '1 hour', "
    "accepted_at = accepted_at - interval '1 hour' "
    "where id = '${quick.single['id']}'",
  );
  for (final c in [pa, pb]) {
    await c.rpc('clear_availability');
  }
  // … later that day (quick connect: once a day): the automatic pause
  // still stops a regular question.
  await free(pa);
  await free(pb);
  check(
    pendingOffers(await rows(pa, 'match_offers')).isEmpty,
    'the automatic pause still stops a regular question (quick friends)',
  );
  for (final c in [pa, pb]) {
    await c.rpc('clear_availability');
  }
  // A pause I chose ("in a week") stops it.
  await pa.rpc(
    'after_call',
    params: {'p_offer': first['id'], 'p_days': 7, 'p_talked': true},
  );
  check(
    List<Map<String, dynamic>>.from(
          await pa.rpc('my_pauses'),
        ).single['chosen'] ==
        true,
    '"in a week" is my choice',
  );
  await dbExec(
    "delete from match_offers where quick and user_a in "
    "('${uid(pa)}', '${uid(pb)}')",
  );
  await free(pa);
  await free(pb);
  check(
    (await rows(
      pa,
      'match_offers',
    )).where((o) => o['status'] == 'pending' || o['quick'] == true).isEmpty,
    'a pause I chose stops quick connect too',
  );
  // "Cancel" on the card (nobody free now, so no new call starts at once).
  for (final c in [pa, pb]) {
    await c.rpc('clear_availability');
  }
  await pa.rpc('clear_pause', params: {'p_user': uid(pb)});
  check(
    List.from(await pa.rpc('my_pauses')).isEmpty &&
        await dbCount(
              "select count(*) from pair_snoozes where from_user in "
              "('${uid(pa)}', '${uid(pb)}')",
            ) ==
            0,
    '"cancel the pause" clears mine and the automatic one on their side',
  );
  for (final c in [pa, pb]) {
    await c.rpc('clear_availability');
  }
  // "Any time" after a call: no hidden pause left on either side.
  final pc = await newUser('צביה', 'female');
  final pd = await newUser('צדוק', 'male');
  await befriend(pc, pd);
  await free(pc);
  await free(pd);
  final talk = pendingOffers(await rows(pc, 'match_offers')).single;
  for (final c in [pc, pd]) {
    await c.rpc(
      'answer_offer',
      params: {'p_offer': talk['id'], 'p_accept': true},
    );
  }
  await pc.rpc(
    'after_call',
    params: {'p_offer': talk['id'], 'p_days': 0, 'p_talked': true},
  );
  check(
    await dbCount(
          "select count(*) from pair_snoozes where from_user in "
          "('${uid(pc)}', '${uid(pd)}')",
        ) ==
        0,
    '"any time" clears mine and the automatic pause on their side',
  );
  for (final c in [pa, pb, pc, pd]) {
    await c.rpc('clear_availability');
  }
  for (final c in [pa, pb, pc, pd]) {
    await c.dispose();
  }
}

/// D-115: fixes from the full review.
Future<void> reviewFixes2() async {
  final ra = await newUser('רעות', 'female');
  final rb = await newUser('רפאל', 'male');
  await befriend(ra, rb);
  await ra.from('phone_numbers').upsert({
    'user_id': uid(ra),
    'phone': '+972501112233',
  });
  await rb.from('phone_numbers').upsert({
    'user_id': uid(rb),
    'phone': '+972501112244',
  });

  // 1. The number's fingerprint can't be set by hand.
  await ra
      .from('phone_numbers')
      .update({'phone_hash': 'f' * 64})
      .eq('user_id', uid(ra));
  check(
    await dbCount(
          "select count(*) from phone_numbers where user_id = '${uid(ra)}' "
          "and phone_hash = encode(extensions.digest(public.e164(phone), 'sha256'), 'hex')",
        ) ==
        1,
    "a phone's fingerprint always matches its number (can't pose as someone)",
  );

  // 2. A late "Talk" on the notification changes nothing.
  final tokenB = await rb.rpc('create_device_token') as String;
  final bg = SupabaseClient(url, anonKey);
  await free(ra);
  await free(rb);
  final offer = pendingOffers(await rows(ra, 'match_offers')).single;
  for (final c in [ra, rb]) {
    await c.rpc(
      'answer_offer',
      params: {'p_offer': offer['id'], 'p_accept': true},
    );
  }
  final callerBefore = (await rows(
    ra,
    'match_offers',
  )).firstWhere((o) => o['id'] == offer['id'])['caller'];
  final late = Map<String, dynamic>.from(
    await bg.rpc(
          'device_answer',
          params: {'p_token': tokenB, 'p_offer': offer['id']},
        )
        as Map,
  );
  final callerAfter = (await rows(
    ra,
    'match_offers',
  )).firstWhere((o) => o['id'] == offer['id'])['caller'];
  check(
    late['status'] == 'handled' && callerAfter == callerBefore,
    'a late "Talk" on an agreed call keeps who dials (no double calls)',
  );
  for (final c in [ra, rb]) {
    await c.rpc('end_call', params: {'p_offer': offer['id']});
    await c.rpc('clear_availability');
  }
  await dbExec(
    "delete from pair_snoozes where from_user in ('${uid(ra)}', '${uid(rb)}')",
  );

  // 3. My own settings never stop me tapping a free friend (D-117):
  //    even when they can't see that I'm free.
  await ra.from('others_visibility').upsert({
    'user_id': uid(ra),
    'show_modes': <String>[],
  });
  await skipQuietGap();
  await free(ra);
  await free(rb);
  final askable = List.from(await ra.rpc('askable_friends'));
  final asked = await ra.rpc('ask_friend', params: {'p_user': uid(rb)});
  check(
    askable.contains(uid(rb)) && asked == 'asked',
    "a friend who can't see I'm free can still be tapped (D-117)",
  );
  for (final o in await rows(ra, 'match_offers')) {
    if (o['status'] == 'pending') {
      await rb.rpc(
        'answer_offer',
        params: {'p_offer': o['id'], 'p_accept': false},
      );
    }
  }
  await ra.from('others_visibility').delete().eq('user_id', uid(ra));
  for (final c in [ra, rb]) {
    await c.rpc('clear_availability');
  }

  // 4. Removing a friend ends our open question; an old link doesn't
  //    bring them back (a new one does).
  final rc = await newUser('רונית', 'female');
  final oldLink = List<Map<String, dynamic>>.from(
    await rc.rpc('create_invitation'),
  ).single;
  await befriend(rc, rb);
  await skipQuietGap();
  await free(rc);
  await free(rb);
  final open = pendingOffers(
    await rows(rc, 'match_offers'),
  ).where((o) => o['user_a'] == uid(rb) || o['user_b'] == uid(rb)).toList();
  await rc
      .from('connections')
      .delete()
      .or('user_a.eq.${uid(rb)},user_b.eq.${uid(rb)}');
  check(
    open.length == 1 &&
        await dbCount(
              "select count(*) from match_offers where id = '${open.single['id']}' "
              "and status = 'cancelled'",
            ) ==
            1,
    'removing a friend ends our open question',
  );
  check(
    await rb.rpc('accept_invitation', params: {'p_token': oldLink['token']}) ==
        'expired',
    "an old unused link doesn't bring back someone who removed me (D-090)",
  );
  final newLink = List<Map<String, dynamic>>.from(
    await rc.rpc('create_invitation'),
  ).single;
  check(
    await rb.rpc('accept_invitation', params: {'p_token': newLink['token']}) ==
        'accepted',
    '...a new link from them does',
  );
  for (final c in [rc, rb]) {
    await c.rpc('clear_availability');
  }

  // 5. A quick connect nobody started in time never dials later.
  final quick = await dbScalar(
    "insert into match_offers (user_a, user_b, expires_at, status, a_response, "
    "b_response, quick, accepted_at, not_before) values "
    "(least('${uid(ra)}'::uuid, '${uid(rb)}'::uuid), "
    "greatest('${uid(ra)}'::uuid, '${uid(rb)}'::uuid), now() + interval '20 minutes', "
    "'accepted', 'accept', 'accept', true, now() - interval '4 minutes', "
    "now() - interval '3 minutes') returning id",
  );
  final late2 = Map<String, dynamic>.from(
    await ra.rpc('start_call', params: {'p_offer': quick}) as Map,
  );
  check(
    late2['state'] == 'gone' &&
        await dbCount(
              "select count(*) from match_offers where id = '$quick' "
              "and status = 'cancelled' and talked is null",
            ) ==
            1,
    'a quick connect nobody started in time ends instead of dialing (D-026)',
  );
  await dbExec(
    "delete from pair_snoozes where from_user in ('${uid(ra)}', '${uid(rb)}')",
  );

  // 6. An automatic trip is never limited to an earlier window's group.
  final grp = await rb
      .from('circles')
      .insert({'name': 'משפחה'})
      .select()
      .single();
  await rb.rpc(
    'set_availability',
    params: {'p_mode': 'free', 'p_minutes': 15, 'p_circle': grp['id']},
  );
  await dbExec(
    "update availability set expires_at = now() - interval '1 second', "
    "started_at = now() - interval '20 minutes' where user_id = '${uid(rb)}'",
  );
  await bg.rpc('auto_start', params: {'p_token': tokenB});
  check(
    await dbCount(
          "select count(*) from availability where user_id = '${uid(rb)}' "
          "and source = 'auto' and circle_id is null",
        ) ==
        1,
    'an automatic trip is for everyone (not an earlier group)',
  );
  await bg.rpc('auto_stop', params: {'p_token': tokenB});

  // 7. Who tapped is remembered (friends tapping me don't use my limit).
  await skipQuietGap();
  await free(ra);
  await free(rb);
  await dbExec(
    "update match_offers set status = 'cancelled' where status = 'pending' "
    "and '${uid(rb)}' in (user_a, user_b)",
  );
  await ra.rpc('ask_friend', params: {'p_user': uid(rb)});
  check(
    await dbCount(
          "select count(*) from match_offers where direct and status = 'pending' "
          "and asked_by = '${uid(ra)}'",
        ) ==
        1,
    'a tap remembers who asked (only my own taps count for my limit)',
  );
  // 8. Quick connect is per person only (D-116): a "quick" group (from an
  //    older app) turns into the per-person switch for its members.
  final grp2 = await ra
      .from('circles')
      .insert({'name': 'קרובים'})
      .select()
      .single();
  await ra.from('circle_members').insert({
    'circle_id': grp2['id'],
    'member': uid(rb),
  });
  await ra.from('circles').update({'quick': true}).eq('id', grp2['id']);
  final st = List<Map<String, dynamic>>.from(await ra.rpc('quick_status'));
  check(
    st.length == 1 &&
        st.single['user_id'] == uid(rb) &&
        st.single['mine'] == true &&
        await dbCount(
              "select count(*) from circles where id = '${grp2['id']}' and quick",
            ) ==
            0,
    'a "quick group" becomes quick connect for each person in it (D-116)',
  );
  for (final c in [ra, rb, rc]) {
    await c.rpc('clear_availability');
    await c.dispose();
  }
  await bg.dispose();
}

// --- friends don't receive my start time or group (D-118)
Future<void> hideStartAndGroup() async {
  final ha = await newUser('הדס', 'female');
  final hb = await newUser('חן', 'male');
  await befriend(ha, hb);
  await free(ha);
  final visible = List<Map<String, dynamic>>.from(
    await hb
        .from('availability')
        .select('user_id, mode, expires_at, source')
        .eq('user_id', uid(ha)),
  );
  check(visible.length == 1, 'a friend still sees that I\'m free (D-118)');
  var hidden = false;
  try {
    await hb.from('availability').select('started_at').eq('user_id', uid(ha));
  } on PostgrestException {
    hidden = true;
  }
  var hiddenGroup = false;
  try {
    await hb.from('availability').select('circle_id').eq('user_id', uid(ha));
  } on PostgrestException {
    hiddenGroup = true;
  }
  check(
    hidden && hiddenGroup,
    'a friend can\'t read when I started or for which group (D-118)',
  );
  final mine = List.from(await ha.rpc('my_availability_details'));
  check(
    mine.length == 1 && mine.single['started_at'] != null,
    'I still get my own start time',
  );
  final theirs = List.from(await hb.rpc('my_availability_details'));
  check(theirs.isEmpty, 'and nobody else\'s');
  for (final c in [ha, hb]) {
    await c.rpc('clear_availability');
  }
}

// --- "X is on the way" for quick-connect friends (D-119)
Future<void> tripPush() async {
  final ta = await newUser('תמר', 'female');
  final tb = await newUser('תום', 'male');
  final tc = await newUser('טליה', 'female');
  await befriend(ta, tb);
  await befriend(ta, tc);
  // Tom: quick both ways. Talia: only I turned it on for her.
  await ta.rpc('set_quick', params: {'p_user': uid(tb), 'p_on': true});
  await tb.rpc('set_quick', params: {'p_user': uid(ta), 'p_on': true});
  await ta.rpc('set_quick', params: {'p_user': uid(tc), 'p_on': true});
  for (final c in [tb, tc]) {
    await c.rpc(
      'save_push_token',
      params: {'p_token': 'test-token-${uid(c)}-0123456789'},
    );
  }
  Future<List<String>> claim() async {
    final out = await dbScalar(
      "select coalesce(string_agg(friend_id::text, ','), '') "
      "from trip_push_claim('${uid(ta)}')",
    );
    return out.isEmpty ? [] : out.split(',');
  }

  check((await claim()).isEmpty, 'not free: nobody is told (D-119)');
  await ta.rpc(
    'set_availability',
    params: {'p_mode': 'driving', 'p_minutes': 30},
  );
  final told = await claim();
  check(
    told.length == 1 && told.single == uid(tb),
    'on the way: only a friend with quick connect both ways is told',
  );
  check((await claim()).isEmpty, 'once a day per friend');
  await dbExec("delete from trip_pushes where owner = '${uid(ta)}'");
  await tb.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 30});
  check(
    (await claim()).isEmpty,
    'a friend who is free already isn\'t told (quick connect handles it)',
  );
  await tb.rpc('clear_availability');
  await ta.rpc('set_trip_notify', params: {'p_on': false});
  check((await claim()).isEmpty, 'the switch off: nobody is told');
  check((await status(ta))['trip_notify'] == false, 'my status shows it');
  await ta.rpc('set_trip_notify', params: {'p_on': true});
  await ta.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 30});
  check((await claim()).isEmpty, 'only on the way (driving), not just free');
  var blocked = false;
  try {
    await tb.rpc('trip_push_claim', params: {'p_user': uid(ta)});
  } on PostgrestException {
    blocked = true;
  }
  check(blocked, 'an app can\'t ask who would be told');
  var hidden = false;
  try {
    await tb.from('push_tokens').select();
  } on PostgrestException {
    hidden = true;
  }
  check(hidden, 'push tokens are never readable');
  for (final c in [ta, tb, tc]) {
    await c.rpc('clear_availability');
  }
}

// --- push notes queued by the database (D-120)
Future<void> pushEvents() async {
  final pa = await newUser('פזית', 'female');
  final pb = await newUser('פלג', 'male');
  await befriend(pa, pb);
  for (final c in [pa, pb]) {
    await c.rpc(
      'save_push_token',
      params: {'p_token': 'events-token-${uid(c)}-0123456789', 'p_build': 140},
    );
  }
  Future<int> queued(SupabaseClient c, String kind) async => int.parse(
    await dbScalar(
      "select count(*) from push_outbox where user_id = '${uid(c)}' "
      "and kind = '$kind'",
    ),
  );
  await dbExec("delete from push_outbox");
  await skipQuietGap();
  await free(pa);
  await free(pb);
  final offer = pendingOffers(await rows(pa, 'match_offers')).single;
  check(
    await queued(pa, 'sync') == 1 && await queued(pb, 'sync') == 1,
    'a new question: both phones are woken to show it (D-120)',
  );
  await pa.rpc(
    'answer_offer',
    params: {'p_offer': offer['id'], 'p_accept': true},
  );
  await pb.rpc(
    'answer_offer',
    params: {'p_offer': offer['id'], 'p_accept': true},
  );
  check(
    await queued(pa, 'sync') == 2 && await queued(pb, 'sync') == 2,
    'both said yes: both phones are woken for the call',
  );
  final claimed = int.parse(
    await dbScalar("select count(*) from push_outbox_claim()"),
  );
  final again = int.parse(
    await dbScalar("select count(*) from push_outbox_claim()"),
  );
  check(claimed == 4 && again == 0, 'each queued note goes out once');
  var hidden = false;
  try {
    await pa.from('push_outbox').select();
  } on PostgrestException {
    hidden = true;
  }
  var denied = false;
  try {
    await pa.rpc('push_outbox_claim');
  } on PostgrestException {
    denied = true;
  }
  check(hidden && denied, 'apps can neither read nor take the queue');
  for (final c in [pa, pb]) {
    await c.rpc('end_call', params: {'p_offer': offer['id']});
    await c.rpc('clear_availability');
  }
  // The owner hears about feedback and new users.
  await dbExec(
    "insert into app_owners (user_id) values ('${uid(pa)}') on conflict do nothing",
  );
  await pb.rpc('send_feedback', params: {'p_body': 'נהדר', 'p_build': 140});
  final owner = await queued(pa, 'owner');
  await dbExec("delete from app_owners where user_id = '${uid(pa)}'");
  check(owner >= 1, 'the owner is told about new feedback');
  // A new version: once per build, only phones that don't have it.
  await dbExec("delete from push_state");
  final told = int.parse(
    await dbScalar(
      "select count(*) from version_push_claim(141) v "
      "where v.push_token in ('events-token-${uid(pa)}-0123456789', "
      "'events-token-${uid(pb)}-0123456789')",
    ),
  );
  final twice = int.parse(
    await dbScalar("select count(*) from version_push_claim(141)"),
  );
  final old = int.parse(
    await dbScalar(
      "select count(*) from version_push_claim(139) v "
      "where v.push_token in ('events-token-${uid(pa)}-0123456789', "
      "'events-token-${uid(pb)}-0123456789')",
    ),
  );
  check(told == 2 && twice == 0 && old == 0, 'a new version is announced once');
  // Older apps still save their address (one argument).
  await pa.rpc(
    'save_push_token',
    params: {'p_token': 'older-app-token-0123456789'},
  );
  check(
    await dbScalar(
          "select count(*) from push_tokens where token = 'older-app-token-0123456789'",
        ) ==
        '1',
    'an older app still saves its push address',
  );
}

Future<void> missedAndQuietDays() async {
  final ma = await newUser('מאיה', 'female');
  final mb = await newUser('מתן', 'male');
  await befriend(ma, mb);
  for (final c in [ma, mb]) {
    await c.rpc(
      'save_push_token',
      params: {'p_token': 'missed-token-${uid(c)}-0123456789', 'p_build': 150},
    );
  }
  Future<List<dynamic>> missed(SupabaseClient c) async {
    final r = await dbScalar(
      "select coalesce(json_agg(data), '[]') from push_outbox "
      "where user_id = '${uid(c)}' and kind = 'missed'",
    );
    return jsonDecode(r) as List<dynamic>;
  }

  final mbToken = await mb.rpc('create_device_token') as String;
  final bg = SupabaseClient(url, anonKey);
  await skipQuietGap();
  await free(ma);
  await free(mb);
  final offer = pendingOffers(await rows(ma, 'match_offers')).single;
  await ma.rpc(
    'answer_offer',
    params: {'p_offer': offer['id'], 'p_accept': true},
  );
  await bg.rpc('device_phone_call', params: {'p_token': mbToken, 'p_on': true});
  final after = (await rows(
    ma,
    'match_offers',
  )).firstWhere((o) => o['id'] == offer['id']);
  check(
    after['status'] == 'cancelled',
    'a phone call starts: my open questions close (D-121)',
  );
  final toMb = await missed(mb);
  final toMa = await missed(ma);
  check(
    toMb.length == 1 &&
        toMb.single['from'] == uid(ma) &&
        toMb.single['name'] == 'מאיה' &&
        toMa.isEmpty,
    'she said yes and I didn\'t answer: I hear "she tried to reach you"',
  );
  await bg.rpc(
    'device_phone_call',
    params: {'p_token': mbToken, 'p_on': false},
  );
  // Once a day at most (owner: no overload).
  await skipQuietGap();
  final tapped = await ma.rpc('ask_friend', params: {'p_user': uid(mb)});
  await bg.rpc('device_phone_call', params: {'p_token': mbToken, 'p_on': true});
  check(
    tapped == 'asked' && (await missed(mb)).length == 1,
    '"tried to reach you" at most once a day',
  );
  await bg.rpc(
    'device_phone_call',
    params: {'p_token': mbToken, 'p_on': false},
  );
  // Nobody said yes → no note.
  await skipQuietGap();
  final again = pendingOffers(await rows(ma, 'match_offers'));
  for (final o in again) {
    await mb.rpc(
      'answer_offer',
      params: {'p_offer': o['id'], 'p_accept': false},
    );
  }
  check(
    (await missed(ma)).isEmpty,
    'a question I didn\'t say yes to: no "tried to reach you"',
  );
  for (final c in [ma, mb]) {
    await c.rpc('clear_availability');
  }

  // Quiet hours on some days only.
  final today = int.parse(
    await dbScalar("select extract(dow from now() at time zone 'UTC')::int"),
  );
  Future<bool> quiet() async =>
      await dbScalar("select public.in_quiet_hours('${uid(ma)}')") == 't';
  await ma.rpc(
    'set_settings',
    params: {
      'p_quiet_from': 0,
      'p_quiet_to': 1439,
      'p_time_zone': 'UTC',
      'p_quiet_days': 1 << today,
    },
  );
  final onToday = await quiet();
  final status = await ma.rpc('my_status') as Map<String, dynamic>;
  await ma.rpc('set_settings', params: {'p_quiet_days': 127 ^ (1 << today)});
  final otherDays = await quiet();
  // An older app (no days) leaves the days as they are.
  await ma.rpc('set_settings', params: {'p_quiet_from': 0, 'p_quiet_to': 1439});
  final kept = await quiet();
  await ma.rpc('set_settings', params: {'p_quiet_days': 127});
  final everyDay = await quiet();
  check(
    onToday &&
        status['quiet_days'] == 1 << today &&
        !otherDays &&
        !kept &&
        everyDay,
    'quiet hours can be limited to chosen days',
  );
  // Hours across midnight belong to the day they start.
  final yesterday = (today + 6) % 7;
  final nowMin = int.parse(
    await dbScalar(
      "select (extract(hour from now() at time zone 'UTC') * 60 "
      "+ extract(minute from now() at time zone 'UTC'))::int",
    ),
  );
  if (nowMin < 1430) {
    await ma.rpc(
      'set_settings',
      params: {
        'p_quiet_from': 1439,
        'p_quiet_to': nowMin + 5,
        'p_quiet_days': 1 << yesterday,
      },
    );
    final fromYesterday = await quiet();
    await ma.rpc('set_settings', params: {'p_quiet_days': 1 << today});
    final notToday = await quiet();
    check(
      fromYesterday && !notToday,
      'night hours count for the evening they start',
    );
  }
  await ma.rpc('set_settings', params: {'p_clear_quiet': true});

  // Several schedules (D-124): e.g. weekdays and the weekend apart.
  final others = 127 ^ (1 << today);
  Future<Object?> ranges(List<Map<String, int>> r) =>
      ma.rpc('set_quiet_ranges', params: {'p_ranges': r, 'p_time_zone': 'UTC'});
  final saved = await ranges([
    {'f': 0, 't': 1439, 'd': others},
    {'f': 0, 't': 1439, 'd': 1 << today},
  ]);
  final inSecond = await quiet();
  final listed =
      ((await ma.rpc('my_status') as Map<String, dynamic>)['quiet_ranges']
              as List)
          .length;
  await ranges([
    {'f': 0, 't': 1439, 'd': others},
    {'f': 60, 't': 120, 'd': others},
  ]);
  final notToday2 = await quiet();
  final tooMany = await ranges([
    for (var i = 0; i < 5; i++) {'f': i, 't': i + 10},
  ]);
  // An older app sets one range: it replaces the list.
  await ma.rpc(
    'set_settings',
    params: {'p_quiet_from': 0, 'p_quiet_to': 1439, 'p_quiet_days': 127},
  );
  final older = await quiet();
  final afterOlder =
      ((await ma.rpc('my_status') as Map<String, dynamic>)['quiet_ranges']
              as List)
          .length;
  await ranges([]);
  final cleared = await quiet();
  check(
    saved == 'ok' &&
        inSecond &&
        listed == 2 &&
        !notToday2 &&
        tooMany == 'bad' &&
        older &&
        afterOlder == 1 &&
        !cleared,
    'quiet hours: several schedules, older apps still work',
  );

  // Notifications don't pile up: old queue rows go at night.
  await dbExec(
    "update push_outbox set created_at = now() - interval '3 days' "
    "where user_id = '${uid(mb)}'",
  );
  await dbExec("select public.nightly_cleanup()");
  check(
    (await missed(mb)).isEmpty,
    'the notification queue is emptied after 2 days',
  );
}

Future<void> questionDelivered() async {
  final qa = await newUser('קרן', 'female');
  final qb = await newUser('קובי', 'male');
  final qc = await newUser('קשת', 'female');
  await befriend(qa, qb);
  await skipQuietGap();
  await free(qa);
  await free(qb);
  // Both free: a question is made for them.
  Map<String, dynamic> offerOf(List<Map<String, dynamic>> rows) =>
      rows.firstWhere((o) => o['status'] == 'pending');
  final before = offerOf(await rows(qa, 'match_offers'));
  // A stranger can't mark it.
  await qc.rpc('offer_shown', params: {'p_offer': before['id']});
  final still = offerOf(await rows(qa, 'match_offers'));
  final bSide = before['user_a'] == uid(qb) ? 'shown_a' : 'shown_b';
  final token = await qb.rpc('create_device_token') as String;
  final bg = SupabaseClient(url, anonKey);
  final ok = await bg.rpc(
    'device_offer_shown',
    params: {'p_token': token, 'p_offer': before['id']},
  );
  final after = offerOf(await rows(qa, 'match_offers'));
  check(
    before[bSide] == null &&
        still[bSide] == null &&
        ok == 'ok' &&
        after[bSide] != null,
    'the one who asked sees "it reached their phone" (D-129)',
  );
  for (final c in [qa, qb]) {
    await c.rpc('clear_availability');
  }
}
