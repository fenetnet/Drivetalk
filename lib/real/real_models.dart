// Data shapes for the real two-user test. Pure Dart.

import '../domain/models.dart';

class RealProfile {
  const RealProfile({
    required this.id,
    required this.name,
    this.gender = Gender.unspecified,
  });
  final String id;
  final String name;
  final Gender gender;

  /// Reuse the demo UI (avatars, labels) for real people.
  Person toPerson() => Person(
    id: id,
    name: name,
    gender: gender,
    avatarColor: _palette[id.hashCode.abs() % _palette.length],
  );

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
  });
  final String userId;
  final AvailabilityMode mode;
  final DateTime startedAt;
  final DateTime expiresAt;

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);
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

  String otherId(String me) => me == userA ? userB : userA;
  bool? myAnswer(String me) => me == userA ? aAccepted : bAccepted;
}

/// What I can see right now.
class RealSnapshot {
  const RealSnapshot({
    required this.me,
    required this.friends,
    required this.availability,
    required this.offers,
    required this.fetchedAt,
  });
  final RealProfile me;
  final List<RealProfile> friends;

  /// By user id (mine included), only non-expired rows.
  final Map<String, RealAvailability> availability;
  final List<RealOffer> offers;
  final DateTime fetchedAt;

  RealAvailability? get mine => availability[me.id];
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

class CallDetails {
  const CallDetails({this.otherPhone, this.iShare = false});
  final String? otherPhone;
  final bool iShare;
}

/// Digits with an optional leading +, 6–15 digits (same rule as the server).
String? normalizePhone(String raw) {
  final t = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  return RegExp(r'^\+?[0-9]{6,15}$').hasMatch(t) ? t : null;
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
