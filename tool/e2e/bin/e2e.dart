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
  final tripStart = seen.firstWhere(
    (a) => a['user_id'] == uid(me),
  )['started_at'];
  await Future<void>.delayed(const Duration(milliseconds: 1100));
  await background.rpc('auto_start', params: {'p_token': device});
  check(
    (await rows(
          yoni,
          'availability',
        )).firstWhere((a) => a['user_id'] == uid(me))['started_at'] ==
        tripStart,
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
      .insert({'name': 'משפחה', 'quick': true})
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
  // Mom (in my quick "family") also put me in her quick circle → mutual.
  final mom = await newUser('אמא', 'female');
  final invMom = List<Map<String, dynamic>>.from(
    await me.rpc('create_invitation'),
  ).single;
  await mom.rpc('accept_invitation', params: {'p_token': invMom['token']});
  await me.from('circle_members').insert({
    'circle_id': family['id'],
    'member': uid(mom),
  });
  final moms = await mom
      .from('circles')
      .insert({'name': 'קרובים', 'quick': true})
      .select()
      .single();
  await mom.from('circle_members').insert({
    'circle_id': moms['id'],
    'member': uid(me),
  });
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
    'both in each other\'s quick circle → connected at once (no question)',
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
  final shiras = await shira
      .from('circles')
      .insert({'name': 'קרובים', 'quick': true})
      .select()
      .single();
  await shira.from('circle_members').insert({
    'circle_id': shiras['id'],
    'member': uid(me),
  });
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
  check(
    await boss.rpc('sees_availability', params: {'p_owner': uid(ho)}) == false,
    'asking "do I see her?" says no — like the list',
  );
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
  check(
    (await rows(
          keren,
          'profiles',
        )).where((p) => p['id'] != uid(keren)).length ==
        2,
    'both accounts show while both are in use',
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

  check(
    await eve.rpc('schema_version') == 28,
    'the server says its version (28)',
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
