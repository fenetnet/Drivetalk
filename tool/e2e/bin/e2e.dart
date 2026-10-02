// End-to-end check of the DriveTalk backend with real Supabase clients.
//
//   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=... dart run bin/e2e.dart
//
// Simulates two phones (Netanel & Yoni) and a stranger (Eve) and verifies:
// invitations, connections, RLS isolation, availability + realtime,
// mutual acceptance, gentle decline, expiry and blocking.
import 'dart:async';
import 'dart:io';

import 'package:supabase/supabase.dart';

final url = Platform.environment['SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
final anonKey = Platform.environment['SUPABASE_ANON_KEY']!;

var failures = 0;
void check(bool ok, String what) {
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $what');
  if (!ok) failures++;
}

Future<SupabaseClient> newUser(String name, String gender) async {
  final c = SupabaseClient(url, anonKey);
  await c.auth.signInAnonymously();
  await c.rpc('ensure_profile', params: {'p_name': name, 'p_gender': gender});
  return c;
}

String uid(SupabaseClient c) => c.auth.currentUser!.id;

Future<List<Map<String, dynamic>>> rows(SupabaseClient c, String table) async =>
    List<Map<String, dynamic>>.from(await c.from(table).select());

Future<void> main() async {
  final me = await newUser('נתנאל', 'male');
  final yoni = await newUser('יוני', 'male');
  final eve = await newUser('איב', 'female');

  // --- profiles are private until connected
  check((await rows(yoni, 'profiles')).length == 1, 'before connecting, Yoni sees only himself');

  // --- invitation
  final inv = List<Map<String, dynamic>>.from(await me.rpc('create_invitation')).single;
  final token = inv['token'] as String;
  check(token.length >= 22, 'invitation token is long and random (${token.length} chars)');

  final peek = List<Map<String, dynamic>>.from(
    await yoni.rpc('get_invitation', params: {'p_token': token}),
  ).single;
  check(peek['status'] == 'valid' && peek['inviter_name'] == 'נתנאל',
      'Yoni sees "Netanel invited you" before accepting');

  final bad = List<Map<String, dynamic>>.from(
    await yoni.rpc('get_invitation', params: {'p_token': '${token}x'}),
  ).single;
  check(bad['status'] == 'not_found', 'a mistyped invitation is "not found"');

  check(await me.rpc('accept_invitation', params: {'p_token': token}) == 'own',
      'I cannot accept my own invitation');
  check(await yoni.rpc('accept_invitation', params: {'p_token': token}) == 'accepted',
      'Yoni accepts the invitation');
  check(await yoni.rpc('accept_invitation', params: {'p_token': token}) == 'already_connected',
      'opening the invitation twice is harmless');
  check(await eve.rpc('accept_invitation', params: {'p_token': token}) == 'used',
      'a used invitation cannot be reused by someone else');

  // --- connections & RLS isolation
  final myPeople = await rows(me, 'profiles');
  check(myPeople.any((p) => p['display_name'] == 'יוני'), 'I see Yoni in my people');
  check((await rows(yoni, 'profiles')).any((p) => p['display_name'] == 'נתנאל'),
      'Yoni sees me');
  check((await rows(eve, 'profiles')).length == 1, 'a stranger sees nobody else');
  check((await rows(eve, 'connections')).isEmpty, 'a stranger sees no connections');
  check((await rows(eve, 'invitations')).isEmpty, "a stranger can't list invitations");

  // Direct writes are not allowed — only through functions.
  try {
    await eve.from('connections').insert({'user_a': uid(eve), 'user_b': uid(me)});
    check(false, 'a stranger cannot insert a connection directly');
  } on PostgrestException {
    check(true, 'a stranger cannot insert a connection directly');
  }
  try {
    await eve.from('availability').insert({
      'user_id': uid(eve),
      'mode': 'free',
      'expires_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
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
    if (status == RealtimeSubscribeStatus.subscribed && !subscribed.isCompleted) {
      subscribed.complete();
    }
  });
  await subscribed.future.timeout(const Duration(seconds: 15));
  // The server needs a moment after "subscribed" before changes flow.
  await Future<void>.delayed(const Duration(seconds: 2));

  await me.rpc('set_availability', params: {'p_mode': 'driving', 'p_minutes': 30});
  try {
    await heard.future.timeout(const Duration(seconds: 10));
    check(true, 'Yoni gets a realtime update when I become available');
  } on TimeoutException {
    check(false, 'Yoni gets a realtime update when I become available');
  }
  final yoniSees = await rows(yoni, 'availability');
  check(yoniSees.any((a) => a['user_id'] == uid(me) && a['mode'] == 'driving'),
      'Yoni sees: Netanel is free, driving');
  check((await rows(eve, 'availability')).where((a) => a['user_id'] == uid(me)).isEmpty,
      "a stranger can't see my availability");
  check((await rows(me, 'match_offers')).isEmpty, 'only I am free → no offer yet');

  // --- both free → offer for both
  await yoni.rpc('set_availability', params: {'p_mode': 'walking', 'p_minutes': 20});
  final offersMe = await rows(me, 'match_offers');
  final offersYoni = await rows(yoni, 'match_offers');
  check(offersMe.length == 1 && offersYoni.length == 1, 'both free → one offer, both see it');
  check((await rows(eve, 'match_offers')).isEmpty, "a stranger can't see the offer");
  final offerId = offersMe.single['id'] as String;

  // --- mutual acceptance
  check(await me.rpc('respond_offer', params: {'p_offer': offerId, 'p_accept': true}) == 'pending',
      'I accept → still waiting for Yoni');
  check(await eve.rpc('respond_offer', params: {'p_offer': offerId, 'p_accept': true}) == 'not_found',
      "a stranger can't answer our offer");
  check(await yoni.rpc('respond_offer', params: {'p_offer': offerId, 'p_accept': true}) == 'accepted',
      'Yoni accepts → match accepted');

  // --- a fresh round where Yoni declines
  await me.rpc('clear_availability');
  await yoni.rpc('clear_availability');
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  await yoni.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  final second = (await rows(me, 'match_offers')).firstWhere((o) => o['status'] == 'pending');
  await me.rpc('respond_offer', params: {'p_offer': second['id'], 'p_accept': true});
  check(await yoni.rpc('respond_offer', params: {'p_offer': second['id'], 'p_accept': false}) == 'declined',
      'Yoni declines');
  final seenByMe = (await rows(me, 'match_offers')).firstWhere((o) => o['id'] == second['id']);
  check(seenByMe['status'] == 'declined', 'I see only "declined" (the app shows a gentle message)');
  // No immediate re-offer after a decline (cooldown).
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  check((await rows(me, 'match_offers')).where((o) => o['status'] == 'pending').isEmpty,
      'no new offer right after a decline (cooldown)');

  // --- clearing availability cancels and hides
  await yoni.rpc('clear_availability');
  check((await rows(me, 'availability')).where((a) => a['user_id'] == uid(yoni)).isEmpty,
      'when Yoni stops, I no longer see him as free');

  // --- validation
  try {
    await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 500});
    check(false, 'availability longer than 3 hours is refused');
  } on PostgrestException {
    check(true, 'availability longer than 3 hours is refused');
  }

  // --- blocking
  await me.rpc('block_user', params: {'p_user': uid(yoni)});
  check((await rows(yoni, 'profiles')).length == 1, 'after I block Yoni he no longer sees me');
  check((await rows(me, 'connections')).isEmpty, 'block removes the connection');

  await channel.unsubscribe();
  for (final c in [me, yoni, eve]) {
    await c.dispose();
  }
  stdout.writeln(failures == 0 ? '\nALL PASSED' : '\n$failures FAILED');
  exit(failures == 0 ? 0 : 1);
}
