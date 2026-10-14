// Data shapes for the real two-user test. Pure Dart.

import 'dart:typed_data';

import '../domain/models.dart';

class RealProfile {
  const RealProfile({
    required this.id,
    required this.name,
    this.gender = Gender.unspecified,
    this.photoVersion = 0,
    this.photo,
  });
  final String id;
  final String name;
  final Gender gender;

  /// 0 = no photo. Goes up every time the person changes their photo.
  final int photoVersion;

  /// The downloaded photo (small JPEG), once we have it.
  final Uint8List? photo;

  /// Shown by the name saved in MY contacts ("Mom"); stays on the phone.
  RealProfile withName(String local) => RealProfile(
    id: id,
    name: local,
    gender: gender,
    photoVersion: photoVersion,
    photo: photo,
  );

  RealProfile withPhoto(Uint8List? bytes) => RealProfile(
    id: id,
    name: name,
    gender: gender,
    photoVersion: photoVersion,
    photo: bytes,
  );

  /// Reuse the demo UI (avatars, labels) for real people.
  Person toPerson() => Person(
    id: id,
    name: name,
    gender: gender,
    avatarColor: _palette[_stableHash('$id$name') % _palette.length],
    photo: photoVersion > 0 ? photo : null,
  );

  /// Same color on every phone and every launch (String.hashCode isn't).
  static int _stableHash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  static const _palette = [
    0xFFE76F51,
    0xFF2A9D8F,
    0xFF457B9D,
    0xFF6D597A,
    0xFFF4A261,
    0xFF588157,
    0xFFB5838D,
    0xFF3D5A80,
  ];
}

Gender genderFromKey(String? k) => switch (k) {
  'female' => Gender.female,
  'male' => Gender.male,
  _ => Gender.unspecified,
};

String genderToKey(Gender g) => switch (g) {
  Gender.female => 'female',
  Gender.male => 'male',
  Gender.unspecified => 'other',
};

class RealAvailability {
  const RealAvailability({
    required this.userId,
    required this.mode,
    required this.startedAt,
    required this.expiresAt,
    this.circleId,
    this.auto = false,
    this.busyUntil,
    this.missedAt,
    this.quietUntil,
  });
  final String userId;

  /// I didn't answer a question: no more questions, and friends see me as
  /// not free, until I say "still free" (my own row only).
  final DateTime? missedAt;

  /// An automatic trip's first minutes: no questions until then.
  final DateTime? quietUntil;
  bool get missed => missedAt != null;
  bool quietAt(DateTime now) => quietUntil != null && now.isBefore(quietUntil!);

  /// In a call (through the app or any other phone call) until then.
  final DateTime? busyUntil;

  /// Free only for this circle of mine (null = all my friends).
  final String? circleId;

  /// Set by the automatic driving detection.
  final bool auto;
  final AvailabilityMode mode;
  final DateTime startedAt;
  final DateTime expiresAt;

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);
  bool inCallAt(DateTime now) => busyUntil != null && now.isBefore(busyUntil!);

  RealAvailability withBusy(DateTime? until) => RealAvailability(
    userId: userId,
    mode: mode,
    startedAt: startedAt,
    expiresAt: expiresAt,
    circleId: circleId,
    auto: auto,
    busyUntil: until,
    missedAt: missedAt,
    quietUntil: quietUntil,
  );

  /// The same, with these marks (null clears one).
  RealAvailability withMarks({
    required DateTime? missedAt,
    required DateTime? quietUntil,
    DateTime? expiresAt,
  }) => RealAvailability(
    userId: userId,
    mode: mode,
    startedAt: startedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    circleId: circleId,
    auto: auto,
    busyUntil: busyUntil,
    missedAt: missedAt,
    quietUntil: quietUntil,
  );

  int minutesLeftAt(DateTime now) {
    final s = expiresAt.difference(now).inSeconds;
    return s <= 0 ? 0 : (s / 60).ceil();
  }
}

AvailabilityMode modeFromKey(String? k) => switch (k) {
  'driving' => AvailabilityMode.driving,
  'walking' => AvailabilityMode.walking,
  'breakTime' => AvailabilityMode.breakTime,
  _ => AvailabilityMode.free,
};

enum OfferStatus { pending, accepted, declined, expired, cancelled }

class RealOffer {
  const RealOffer({
    required this.id,
    required this.userA,
    required this.userB,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.aAccepted,
    this.bAccepted,
    this.quick = false,
    this.caller,
    this.notBefore,
    this.laterFrom,
    this.sharedUntil,
    this.lastTalk,
    this.direct = false,
  });
  final String id;
  final String userA;
  final String userB;
  final OfferStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;

  /// null = no answer yet.
  final bool? aAccepted;
  final bool? bAccepted;

  /// Mutual quick connect: accepted at once, without asking.
  final bool quick;

  /// Who dials (chosen by the server). null = not decided yet (quick
  /// connect before its 5 seconds are over).
  final String? caller;

  /// Quick connect: nobody dials before this (null = not both phones saw
  /// it yet).
  final DateTime? notBefore;

  /// Who said "not now — I'll get back to you" (null = nobody).
  final String? laterFrom;

  /// Both are free until about then (null = unknown, e.g. a trip).
  final DateTime? sharedUntil;

  /// When the two last talked through the app (null = never).
  final DateTime? lastTalk;

  /// Someone tapped the other one (not the app's suggestion).
  final bool direct;

  String otherId(String me) => me == userA ? userB : userA;

  /// The other side tapped me ("X wants to talk with you", D-109).
  bool askedBy(String other) =>
      direct && (other == userA ? aAccepted : bAccepted) == true;
  bool? myAnswer(String me) => me == userA ? aAccepted : bAccepted;
}

/// A contact who uses DriveTalk and isn't my friend yet (I may add them).
class ContactMatch {
  const ContactMatch(this.id, this.name, {this.hash, this.isFriend = false});
  final String id;
  final String name;

  /// The hash of the number that matched (one I sent).
  final String? hash;

  /// Already my friend (listed only for the names saved on my phone).
  final bool isFriend;

  ContactMatch named(String local) =>
      ContactMatch(id, local, hash: hash, isFriend: isFriend);
}

/// About me, from the server; friends can't read any of it.
class MyStatus {
  const MyStatus({
    this.anonymous = false,
    this.hideInCall = false,
    this.quietFrom,
    this.quietTo,
    this.autoMissed = 0,
    this.hiddenFree = 0,
    this.pending = const {},
  });

  /// "Free without my name": friends see only how many are free (and so
  /// do I).
  final bool anonymous;

  /// In a call I simply look not free.
  final bool hideInCall;

  /// Quiet hours, minutes after midnight (null = none).
  final int? quietFrom;
  final int? quietTo;
  bool get hasQuietHours =>
      quietFrom != null && quietTo != null && quietFrom != quietTo;

  /// Automatic trips in a row with an unanswered question.
  final int autoMissed;

  /// Free friends I can't see by name (their choice or mine).
  final int hiddenFree;

  /// Friends who added me from their contacts and wait for my "keep".
  final Set<String> pending;
}

/// What I can see right now.
class RealSnapshot {
  const RealSnapshot({
    required this.me,
    required this.friends,
    required this.availability,
    required this.offers,
    required this.fetchedAt,
    this.circles = const [],
    this.lastTalk = const {},
    this.talks = const [],
    this.intents = const {},
    this.ratings = const {},
    this.hidden = false,
    this.inactiveDays = const {},
    this.othersModes,
    this.status = const MyStatus(),
    this.askable,
    this.quickMine = const {},
    this.quickTheirs = const {},
    this.pauses = const {},
  });

  /// Free friends I can really ask now (D-107). null = unknown (an older
  /// server): nobody is filtered out.
  final Set<String>? askable;

  /// Quick connect (D-112): friends I turned it on for (also via a quick
  /// group), and friends who turned it on for me.
  final Set<String> quickMine;
  final Set<String> quickTheirs;

  /// My pauses after a call (D-108/D-113): friend id → until, and whether
  /// I chose it (else the automatic 3 days).
  final Map<String, ({DateTime until, bool chosen})> pauses;

  /// Both sides turned it on: the call can start by itself.
  bool quickBoth(String id) =>
      quickMine.contains(id) && quickTheirs.contains(id);

  /// My private settings and counts (see [MyStatus]).
  final MyStatus status;

  /// "Everyone else" (friends in none of my circles): who sees that I'm
  /// free. null = always, empty = never.
  final Set<AvailabilityMode>? othersModes;

  /// Does [friendId] see me free in [mode] (by my circles' rules)?
  bool showsMeTo(String friendId, AvailabilityMode mode) {
    final mine = [
      for (final c in circles)
        if (c.memberIds.contains(friendId)) c,
    ];
    if (mine.isEmpty) return othersModes == null || othersModes!.contains(mode);
    return mine.every(
      (c) => c.showModes == null || c.showModes!.contains(mode),
    );
  }

  /// Friend id → whole days since they last opened the app (0 = today).
  final Map<String, int> inactiveDays;

  /// How much I want to talk with each friend, 0–5 (only I see it).
  /// Not set = 3.
  final Map<String, int> ratings;
  int ratingOf(String friendId) => ratings[friendId] ?? 3;

  /// I hide my status: friends don't see when I'm free, and I don't see
  /// theirs (offers still happen).
  final bool hidden;

  /// "I'd like to talk" (mine only): friend id → until when (null = until
  /// I remove it). Only active ones.
  final Map<String, TalkIntent> intents;

  /// Every talk (both said yes): friend id and when — newest first.
  final List<(String, DateTime)> talks;

  /// This week's talks (last 7 days): (talks, different friends).
  (int, int) weekAt(DateTime now) {
    final since = now.subtract(const Duration(days: 7));
    final recent = [
      for (final t in talks)
        if (t.$2.isAfter(since)) t,
    ];
    return (recent.length, {for (final t in recent) t.$1}.length);
  }

  /// When I last talked with each friend through the app (both said yes).
  /// Only real history — the source of "you haven't talked in a while".
  final Map<String, DateTime> lastTalk;
  final RealProfile me;
  final List<RealProfile> friends;

  /// By user id (mine included), only non-expired rows.
  final Map<String, RealAvailability> availability;
  final List<RealOffer> offers;
  final DateTime fetchedAt;

  /// My private circles (only I see them).
  final List<RealCircle> circles;

  RealAvailability? get mine => availability[me.id];

  /// The same snapshot with other people in it — every other field kept
  /// (one place, so a new field can't be dropped by a copy).
  RealSnapshot _withPeople({
    required RealProfile me,
    required List<RealProfile> friends,
  }) => RealSnapshot(
    me: me,
    friends: friends,
    availability: availability,
    offers: offers,
    fetchedAt: fetchedAt,
    circles: circles,
    lastTalk: lastTalk,
    talks: talks,
    intents: intents,
    ratings: ratings,
    hidden: hidden,
    inactiveDays: inactiveDays,
    othersModes: othersModes,
    status: status,
    askable: askable,
    quickMine: quickMine,
    quickTheirs: quickTheirs,
    pauses: pauses,
  );

  /// Same snapshot with downloaded photos filled in (by user id).
  RealSnapshot withPhotos(Map<String, Uint8List> photos) {
    RealProfile fill(RealProfile p) =>
        p.photoVersion > 0 && photos[p.id] != null
        ? p.withPhoto(photos[p.id])
        : p;
    return _withPeople(
      me: fill(me),
      friends: [for (final f in friends) fill(f)],
    );
  }

  /// Friends shown by the names saved in MY contacts (id → name).
  RealSnapshot withLocalNames(Map<String, String> names) {
    if (names.isEmpty) return this;
    return _withPeople(
      me: me,
      friends: [
        for (final f in friends)
          if (names[f.id] case final n? when n.trim().isNotEmpty)
            f.withName(n.trim())
          else
            f,
      ]..sort((a, b) => a.name.compareTo(b.name)),
    );
  }

  RealProfile? friend(String id) {
    for (final f in friends) {
      if (f.id == id) return f;
    }
    return null;
  }
}

enum InviteStatus { valid, used, expired, own, alreadyConnected, notFound }

InviteStatus inviteStatusFromKey(String? k) => switch (k) {
  'valid' => InviteStatus.valid,
  'used' => InviteStatus.used,
  'expired' => InviteStatus.expired,
  'own' => InviteStatus.own,
  'already_connected' => InviteStatus.alreadyConnected,
  _ => InviteStatus.notFound,
};

class InviteInfo {
  const InviteInfo(this.status, {this.inviterName, this.inviterGender});
  final InviteStatus status;
  final String? inviterName;
  final Gender? inviterGender;
}

enum AcceptResult { accepted, alreadyConnected, own, used, expired, notFound }

AcceptResult acceptResultFromKey(String? k) => switch (k) {
  'accepted' => AcceptResult.accepted,
  'already_connected' => AcceptResult.alreadyConnected,
  'own' => AcceptResult.own,
  'used' => AcceptResult.used,
  'expired' => AcceptResult.expired,
  _ => AcceptResult.notFound,
};

class CreatedInvitation {
  const CreatedInvitation(this.token, this.expiresAt);
  final String token;
  final DateTime expiresAt;
}

/// Connection to the realtime channel, for the test screen.
enum LiveStatus { disconnected, connecting, connected, error }

/// "I'd like to talk with this friend" — a quiet wish, never sent to them.
class TalkIntent {
  const TalkIntent({required this.friendId, this.until});
  final String friendId;

  /// null = until I remove it.
  final DateTime? until;

  bool isActiveAt(DateTime now) => until == null || now.isBefore(until!);
}

enum TalkIntentSpan { today, week, always }

/// After a call: it was good / talked but not again soon / didn't talk.

/// The server's reply to "talk?" (yes/no).
class OfferAnswer {
  const OfferAnswer(this.status, {this.iCall = false, this.phone});
  final OfferStatus status;

  /// Both said yes and I answered last: I dial, right now.
  final bool iCall;

  /// The number to dial (only when [iCall]).
  final String? phone;
}

enum CallStartState { ready, wait, cancelled, gone }

/// The server's reply when a quick connect may start.
class CallStart {
  const CallStart(this.state, {this.iCall = false, this.phone, this.waitMs});
  final CallStartState state;
  final bool iCall;
  final String? phone;
  final int? waitMs;
}

/// Digits with an optional leading +, 6–15 digits (same rule as the server).
String? normalizePhone(String raw) {
  final t = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  return RegExp(r'^\+?[0-9]{6,15}$').hasMatch(t) ? t : null;
}

/// International form used for matching contacts (+972…). Must match the
/// server's `e164()` in supabase/migrations/20261005000000_contacts.sql.
String? e164Phone(String raw) {
  final plus = raw.trim().startsWith('+');
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return null;
  if (!plus) {
    if (d.startsWith('00')) {
      d = d.substring(2);
    } else if (d.startsWith('972')) {
      // already international
    } else if (d.startsWith('0')) {
      d = '972${d.substring(1)}';
    }
  }
  if (d.length < 8 || d.length > 15) return null;
  return '+$d';
}

/// Pulls an invitation token out of a link or a pasted code.
/// Accepts `https://host/i/<token>`, `…/invite.html?t=<token>`,
/// `drivetalk://invite/<token>`, or the bare token.
String? parseInviteToken(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final tokenRe = RegExp(r'^[A-Za-z0-9_-]{16,64}$');
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    final q = uri.queryParameters['t'];
    if (q != null && tokenRe.hasMatch(q)) return q;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == 'drivetalk' && uri.host == 'invite' && segs.isNotEmpty) {
      return tokenRe.hasMatch(segs.last) ? segs.last : null;
    }
    final i = segs.lastIndexOf('i');
    if (i >= 0 && i + 1 < segs.length && tokenRe.hasMatch(segs[i + 1])) {
      return segs[i + 1];
    }
  }
  // A link or a code inside a longer pasted message.
  final inLink = RegExp(
    r'(?:/i/|[?&]t=|drivetalk://invite/)([A-Za-z0-9_-]{16,64})',
  ).firstMatch(text);
  if (inLink != null) return inLink.group(1);
  // Server tokens are exactly 22 URL-safe characters.
  final bare = RegExp(
    r'(?:^|[^A-Za-z0-9_-])([A-Za-z0-9_-]{22})(?:$|[^A-Za-z0-9_-])',
  ).firstMatch(text);
  return bare?.group(1);
}

/// A private circle ("family", "army friends"). [quick] = quick connect:
/// when BOTH have each other in a quick circle and both are free, they are
/// connected at once (with a 5-second cancel), at most once a day.
class RealCircle {
  const RealCircle({
    required this.id,
    required this.name,
    this.quick = false,
    this.memberIds = const {},
    this.showModes,
  });
  final String id;
  final String name;
  final bool quick;
  final Set<String> memberIds;

  /// Who sees that I'm free: null = always, empty = never, otherwise only
  /// in these modes. Someone in two circles sees me only if both allow.
  final Set<AvailabilityMode>? showModes;

  RealCircle copyWith({
    String? name,
    bool? quick,
    Set<String>? memberIds,
    ShowRule? show,
  }) => RealCircle(
    id: id,
    name: name ?? this.name,
    quick: quick ?? this.quick,
    memberIds: memberIds ?? this.memberIds,
    showModes: show == null ? showModes : show.modes,
  );
}

/// A "who sees me" rule, with "always" (null modes) as a real value.
class ShowRule {
  const ShowRule(this.modes);
  static const always = ShowRule(null);
  static const never = ShowRule({});
  final Set<AvailabilityMode>? modes;

  bool allows(AvailabilityMode m) => modes == null || modes!.contains(m);
}

/// Server form: null = always; [] = never; ['driving', …].
List<String>? modesToKeys(Set<AvailabilityMode>? modes) => modes == null
    ? null
    : [
        for (final m in AvailabilityMode.values)
          if (modes.contains(m)) m.name,
      ];

Set<AvailabilityMode>? modesFromKeys(Object? keys) =>
    keys is List ? {for (final k in keys) modeFromKey(k as String?)} : null;

/// A note for the owner: feedback or a report.
class OwnerNote {
  const OwnerNote(this.at, this.title, this.body);
  final DateTime at;

  /// Who sent it (feedback) / "reporter → reported" (report).
  final String title;
  final String body;
}
