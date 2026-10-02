// Core domain models. Pure Dart — no Flutter imports, so the same models can
// be reused by the matching engine, fake services, and future backends.

enum RelationshipType {
  family,
  closeFriend,
  friend,
  childhoodFriend,
  colleague,
  formerColleague,
  acquaintance,
}

/// The four suggestion levels the user can open themselves to.
enum MatchTier { familiar, reconnect, widenCircle, surpriseMe }

enum AvailabilityMode { driving, walking, breakTime, free }

enum AvailabilitySource { manual, automaticVehicle, shortcut }

enum FeedbackRating { veryGood, good, notReally }

enum BeaconFrequency { off, low, normal }

/// How to address / refer to a person in Hebrew (grammatical gender).
enum Gender { female, male, unspecified }

class Group {
  const Group({required this.id, required this.name});
  final String id;
  final String name;
}

/// Public profile of a person in the app.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.avatarColor,
    this.gender = Gender.unspecified,
    this.languages = const {'he'},
    this.interests = const {},
    this.groupIds = const {},
    this.friendIds = const {},
    this.openTiers = const {
      MatchTier.familiar,
      MatchTier.reconnect,
      MatchTier.widenCircle,
    },
    this.openToFriendsOfFriends = false,
    this.adultVerified = true,
    this.safetyRestricted = false,
  });

  final String id;
  final String name;

  /// ARGB color for the generated avatar (no photos in Phase 1).
  final int avatarColor;
  final Gender gender;
  final Set<String> languages;
  final Set<String> interests;
  final Set<String> groupIds;

  /// The person's own connections (used to compute mutual friends only;
  /// names of mutual friends are never shown to the other side).
  final Set<String> friendIds;
  final Set<MatchTier> openTiers;
  final bool openToFriendsOfFriends;
  final bool adultVerified;

  /// Set by trust & safety (e.g. after reports). Restricted users are never suggested.
  final bool safetyRestricted;

  String get initial =>
      name.isEmpty ? '?' : String.fromCharCode(name.runes.first);

  Person copyWith({
    String? name,
    Gender? gender,
    Set<String>? languages,
    Set<String>? interests,
    Set<String>? groupIds,
    Set<String>? friendIds,
    Set<MatchTier>? openTiers,
    bool? openToFriendsOfFriends,
  }) => Person(
    id: id,
    name: name ?? this.name,
    avatarColor: avatarColor,
    gender: gender ?? this.gender,
    languages: languages ?? this.languages,
    interests: interests ?? this.interests,
    groupIds: groupIds ?? this.groupIds,
    friendIds: friendIds ?? this.friendIds,
    openTiers: openTiers ?? this.openTiers,
    openToFriendsOfFriends:
        openToFriendsOfFriends ?? this.openToFriendsOfFriends,
    adultVerified: adultVerified,
    safetyRestricted: safetyRestricted,
  );
}

class FeedbackEntry {
  const FeedbackEntry({required this.at, required this.rating, this.wantAgain});
  final DateTime at;
  final FeedbackRating rating;
  final bool? wantAgain;
}

/// My relationship with another person, from my point of view.
/// Everything here is about in-app interactions only — never the phone call log.
class Connection {
  const Connection({
    required this.personId,
    this.relationshipType,
    this.contextLabel,
    this.lastInteraction,
    this.callCount = 0,
    this.feedback = const [],
    this.lastDeclinedAt,
  });

  final String personId;

  /// Optional — the user does not have to classify anyone.
  final RelationshipType? relationshipType;

  /// Free text the user chose, e.g. "חבר מהצבא". Only shown to me.
  final String? contextLabel;
  final DateTime? lastInteraction;
  final int callCount;
  final List<FeedbackEntry> feedback;

  /// Last time I explicitly passed on this person (used to stop re-suggesting).
  final DateTime? lastDeclinedAt;

  Connection copyWith({
    RelationshipType? relationshipType,
    bool clearRelationshipType = false,
    String? contextLabel,
    DateTime? lastInteraction,
    int? callCount,
    List<FeedbackEntry>? feedback,
    DateTime? lastDeclinedAt,
  }) => Connection(
    personId: personId,
    relationshipType: clearRelationshipType
        ? null
        : relationshipType ?? this.relationshipType,
    contextLabel: contextLabel ?? this.contextLabel,
    lastInteraction: lastInteraction ?? this.lastInteraction,
    callCount: callCount ?? this.callCount,
    feedback: feedback ?? this.feedback,
    lastDeclinedAt: lastDeclinedAt ?? this.lastDeclinedAt,
  );
}

enum PauseKind { notToday, doNotSuggest }

/// "Not today" / "Don't suggest them for a while". Works for anyone,
/// including friends-of-friends I'm not connected to.
class SuggestionPause {
  const SuggestionPause({required this.kind, required this.until});
  final PauseKind kind;
  final DateTime until;
}

/// What the server is allowed to know about availability: status, mode, expiry.
/// No location, route or speed — ever.
class Availability {
  const Availability({
    required this.mode,
    required this.startedAt,
    required this.expiresAt,
    this.untilTripEnds = false,
    this.source = AvailabilitySource.manual,
  });

  final AvailabilityMode mode;
  final DateTime startedAt;

  /// Always set — even "until the trip ends" has a safety cap, so a user can
  /// never stay "available" forever if the app is killed.
  final DateTime expiresAt;
  final bool untilTripEnds;
  final AvailabilitySource source;

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);

  int minutesLeftAt(DateTime now) {
    final left = expiresAt.difference(now).inSeconds;
    return left <= 0 ? 0 : (left / 60).ceil();
  }
}

/// Settings and preferences that belong to the current user.
class MyPreferences {
  const MyPreferences({
    this.autoDrivingAvailability = false,
    this.excludedRelationshipTypes = const {},
    this.beaconFrequency = BeaconFrequency.normal,
    this.beaconMutedUntil,
    this.onboardingDone = false,
    this.confirmedAdult = false,
  });

  /// OPT-IN only. Off by default.
  final bool autoDrivingAvailability;
  final Set<RelationshipType> excludedRelationshipTypes;
  final BeaconFrequency beaconFrequency;
  final DateTime? beaconMutedUntil;
  final bool onboardingDone;
  final bool confirmedAdult;

  MyPreferences copyWith({
    bool? autoDrivingAvailability,
    Set<RelationshipType>? excludedRelationshipTypes,
    BeaconFrequency? beaconFrequency,
    DateTime? beaconMutedUntil,
    bool clearBeaconMute = false,
    bool? onboardingDone,
    bool? confirmedAdult,
  }) => MyPreferences(
    autoDrivingAvailability:
        autoDrivingAvailability ?? this.autoDrivingAvailability,
    excludedRelationshipTypes:
        excludedRelationshipTypes ?? this.excludedRelationshipTypes,
    beaconFrequency: beaconFrequency ?? this.beaconFrequency,
    beaconMutedUntil: clearBeaconMute
        ? null
        : beaconMutedUntil ?? this.beaconMutedUntil,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    confirmedAdult: confirmedAdult ?? this.confirmedAdult,
  );
}

enum ReportReason { inappropriate, harassment, spam, underage, other }
