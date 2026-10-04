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

import 'package:crypto/crypto.dart';
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
  // Phone numbers: private, revealed only after both accepted.
  await yoni.from('phone_numbers').upsert({'user_id': uid(yoni), 'phone': '+972501234567'});
  check((await rows(me, 'phone_numbers')).isEmpty, "I can't read Yoni's number directly");
  final early = List<Map<String, dynamic>>.from(
    await me.rpc('call_details', params: {'p_offer': offerId}),
  ).single;
  check(early['other_phone'] == null, 'no number before both accepted');
  try {
    await eve.from('phone_numbers').insert({'user_id': uid(yoni), 'phone': '+972500000000'});
    check(false, "a stranger can't set someone else's number");
  } on PostgrestException {
    check(true, "a stranger can't set someone else's number");
  }

  check(await yoni.rpc('respond_offer', params: {'p_offer': offerId, 'p_accept': true}) == 'accepted',
      'Yoni accepts → match accepted');
  final details = List<Map<String, dynamic>>.from(
    await me.rpc('call_details', params: {'p_offer': offerId}),
  ).single;
  check(details['other_phone'] == '+972501234567' && details['i_share'] == false,
      'after both accepted I get the number Yoni chose to share');
  final eveDetails = List<Map<String, dynamic>>.from(
    await eve.rpc('call_details', params: {'p_offer': offerId}),
  ).single;
  check(eveDetails['other_phone'] == null, "a stranger can't get numbers from our offer");

  // --- right after a call: not the same pair again (30-minute pause)
  await me.rpc('clear_availability');
  await yoni.rpc('clear_availability');
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  await yoni.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  check((await rows(me, 'match_offers')).where((o) => o['status'] == 'pending').isEmpty,
      'no new offer for the same pair right after a call');

  // --- a round where a friend declines (Tal)
  final tal = await newUser('טל', 'male');
  final invTal = List<Map<String, dynamic>>.from(await me.rpc('create_invitation')).single;
  await tal.rpc('accept_invitation', params: {'p_token': invTal['token']});
  await tal.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  final second = (await rows(me, 'match_offers')).firstWhere((o) => o['status'] == 'pending');
  await me.rpc('respond_offer', params: {'p_offer': second['id'], 'p_accept': true});
  check(await tal.rpc('respond_offer', params: {'p_offer': second['id'], 'p_accept': false}) == 'declined',
      'Tal declines');
  final seenByMe = (await rows(me, 'match_offers')).firstWhere((o) => o['id'] == second['id']);
  check(seenByMe['status'] == 'declined', 'I see only "declined" (the app shows a gentle message)');
  // No immediate re-offer after a decline (cooldown).
  await me.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 15});
  check((await rows(me, 'match_offers')).where((o) => o['status'] == 'pending').isEmpty,
      'no new offer right after a decline (cooldown)');
  await tal.rpc('clear_availability');
  await tal.dispose();

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

  // --- automatic driving availability (device token, app closed)
  await me.rpc('clear_availability');
  await yoni.rpc('clear_availability');
  final device = await me.rpc('create_device_token') as String;
  check(device.length >= 40, 'device token is long and random');
  final background = SupabaseClient(url, anonKey); // no login, like the phone in the background
  check(await background.rpc('auto_start', params: {'p_token': 'x' * 43}) == 'bad_token',
      'a wrong device token is refused');
  check(await background.rpc('auto_start', params: {'p_token': device}) == 'available',
      'trip detected → I become available (driving), app closed');
  final seen = await rows(yoni, 'availability');
  check(seen.any((a) => a['user_id'] == uid(me) && a['mode'] == 'driving'),
      'Yoni sees me free (driving)');
  // A new friend (Yoni and I are in the 15-minute pause after his "no").
  final dani = await newUser('יוני', 'male');
  final inv2 = List<Map<String, dynamic>>.from(await me.rpc('create_invitation')).single;
  await dani.rpc('accept_invitation', params: {'p_token': inv2['token']});
  await dani.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 30});
  final pending = List<Map<String, dynamic>>.from(
    await background.rpc('auto_offers', params: {'p_token': device}),
  );
  check(pending.length == 1 && pending.single['other_name'] == 'יוני',
      'background check finds "Yoni is free — talk?"');
  check(
    await background.rpc('auto_decline', params: {
          'p_token': device,
          'p_offer': pending.single['offer_id'],
        }) ==
        'declined',
    '"not now" from the notification works',
  );
  check(List.from(await eve.rpc('auto_offers', params: {'p_token': 'y' * 43})).isEmpty,
      "a stranger's guess sees no offers");
  check(await background.rpc('auto_stop', params: {'p_token': device}) == 'stopped',
      'trip ended → automatic availability stops');
  await me.rpc('set_availability', params: {'p_mode': 'walking', 'p_minutes': 30});
  check(await background.rpc('auto_start', params: {'p_token': device}) == 'already_available',
      'a manual "I\'m free" is not overridden by the car');
  check(await background.rpc('auto_stop', params: {'p_token': device}) == 'nothing',
      'nor stopped when the trip ends');
  // One-tap button (widget / quick tile), app closed.
  await me.rpc('clear_availability');
  check(await background.rpc('device_status', params: {'p_token': device}) == null,
      'button shows "not free"');
  final until = await background.rpc('device_start', params: {'p_token': device, 'p_minutes': 30});
  check(until != null, 'one tap → free for 30 minutes');
  check(await background.rpc('device_status', params: {'p_token': device}) != null,
      'button shows "free"');
  check(await background.rpc('device_start', params: {'p_token': 'z' * 43}) == null,
      'a wrong token cannot make anyone free');
  await background.rpc('device_stop', params: {'p_token': device});
  check(await background.rpc('device_status', params: {'p_token': device}) == null,
      'second tap → not free');
  await me.rpc('revoke_device_tokens');
  check(await background.rpc('auto_start', params: {'p_token': device}) == 'bad_token',
      'turning the feature off revokes the device token');
  try {
    await eve.rpc('device_user', params: {'p_token': device});
    check(false, 'internal token lookup is not callable');
  } on PostgrestException {
    check(true, 'internal token lookup is not callable');
  }
  await background.dispose();

  // --- circles: "available only to family" + mutual quick connect
  await me.rpc('clear_availability');
  final ron = await newUser('רון', 'male');
  final inv3 = List<Map<String, dynamic>>.from(await me.rpc('create_invitation')).single;
  await ron.rpc('accept_invitation', params: {'p_token': inv3['token']});
  final family = await me.from('circles').insert({'name': 'משפחה', 'quick': true}).select().single();
  await me.from('circle_members').insert({'circle_id': family['id'], 'member': uid(dani)});
  try {
    await me.from('circle_members').insert({'circle_id': family['id'], 'member': uid(eve)});
    check(false, 'only my connections can be added to a circle');
  } on PostgrestException {
    check(true, 'only my connections can be added to a circle');
  }
  check((await rows(dani, 'circles')).isEmpty, "my circles are private");
  await dani.rpc('clear_availability');
  await ron.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 30});
  await me.rpc('set_availability',
      params: {'p_mode': 'walking', 'p_minutes': 30, 'p_circle': family['id']});
  check((await rows(ron, 'availability')).where((a) => a['user_id'] == uid(me)).isEmpty,
      'free only for "family" → Ron (not in it) does not see me');
  check((await rows(ron, 'match_offers')).where((o) => o['status'] == 'pending').isEmpty,
      'and gets no offer');
  // Mom (in my quick "family") also put me in her quick circle → mutual.
  final mom = await newUser('אמא', 'female');
  final invMom = List<Map<String, dynamic>>.from(await me.rpc('create_invitation')).single;
  await mom.rpc('accept_invitation', params: {'p_token': invMom['token']});
  await me.from('circle_members').insert({'circle_id': family['id'], 'member': uid(mom)});
  final moms = await mom.from('circles').insert({'name': 'קרובים', 'quick': true}).select().single();
  await mom.from('circle_members').insert({'circle_id': moms['id'], 'member': uid(me)});
  await mom.rpc('set_availability', params: {'p_mode': 'free', 'p_minutes': 30});
  final quickOffer = (await rows(me, 'match_offers'))
      .where((o) => o['quick'] == true)
      .toList();
  check(quickOffer.length == 1 && quickOffer.single['status'] == 'accepted',
      'both in each other\'s quick circle → connected at once (no question)');
  await mom.rpc('nudge_offers');
  check((await rows(me, 'match_offers')).where((o) => o['quick'] == true).length == 1,
      'quick connect at most once a day per pair');
  check(await mom.rpc('nudge_offers') == 0, 'nudge is harmless when nothing is new');
  await mom.rpc('clear_availability');
  await mom.dispose();
  await dani.dispose();
  await ron.dispose();
  await me.rpc('clear_availability');
  await yoni.rpc('clear_availability');

  // --- blocking (and unblocking)
  await me.rpc('block_user', params: {'p_user': uid(yoni)});
  check((await rows(yoni, 'profiles')).length == 1, 'after I block Yoni he no longer sees me');
  check(
    (await rows(me, 'connections'))
        .where((c) => c['user_a'] == uid(yoni) || c['user_b'] == uid(yoni))
        .isEmpty,
    'block removes the connection',
  );
  final myBlocks = List<Map<String, dynamic>>.from(await me.rpc('my_blocks'));
  check(myBlocks.single['display_name'] == 'יוני', 'I can see whom I blocked');
  check(await me.rpc('unblock_user', params: {'p_user': uid(yoni)}) == 'reconnected',
      'unblock brings the connection back');
  check((await rows(yoni, 'profiles')).any((p) => p['display_name'] == 'נתנאל'),
      'after unblocking Yoni sees me again');
  check(List.from(await yoni.rpc('my_blocks')).isEmpty, "Yoni can't see my block list");

  // --- friends from phone contacts (each must have the other's number)
  String h(String e164) => sha256.convert(utf8.encode(e164)).toString();
  // Fresh numbers each run (earlier runs left users in the local database).
  final n = (DateTime.now().millisecondsSinceEpoch % 9000000) + 1000000;
  final aviPhone = '+97250$n';
  final noaPhone = '+97252$n';
  final avi = await newUser('אבי', 'male');
  final noa = await newUser('נועה', 'female');
  await avi.from('phone_numbers').upsert({'user_id': uid(avi), 'phone': '050$n'}); // local form
  await noa.from('phone_numbers').upsert({'user_id': uid(noa), 'phone': noaPhone});
  final first = List.from(await avi.rpc('sync_contacts', params: {'p_hashes': [h(noaPhone)]}));
  check(first.isEmpty, 'only one side has the number → not connected yet');
  final matched = List<Map<String, dynamic>>.from(
    await noa.rpc('sync_contacts', params: {'p_hashes': [h(aviPhone), h('+972599999999')]}),
  );
  check(matched.length == 1 && matched.single['display_name'] == 'אבי',
      'both have each other → connected automatically');
  check((await rows(avi, 'profiles')).any((p) => p['display_name'] == 'נועה'),
      'Avi now sees Noa in his people');
  check((await rows(eve, 'profiles')).length == 1, 'nobody else was connected');
  try {
    final leaked = await noa.from('contact_hashes').select();
    check(leaked.isEmpty, 'contact hashes are not readable (even my own)');
  } on PostgrestException {
    check(true, 'contact hashes are not readable (even my own)');
  }
  final again = List.from(await noa.rpc('sync_contacts', params: {'p_hashes': [h(aviPhone)]}));
  check(again.isEmpty, 'syncing again creates nothing new');
  await avi.dispose();
  await noa.dispose();

  await channel.unsubscribe();
  for (final c in [me, yoni, eve]) {
    await c.dispose();
  }
  stdout.writeln(failures == 0 ? '\nALL PASSED' : '\n$failures FAILED');
  exit(failures == 0 ? 0 : 1);
}
