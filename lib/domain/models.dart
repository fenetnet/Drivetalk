// Core domain models. Pure Dart — no Flutter imports, so the same models can
// be reused by the matching engine, fake services, and future backends.

import 'dart:convert';
import 'dart:typed_data';

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
    this.photo,
    this.phoneNumber,
    this.sharesNumberWithFriendsOfFriends = false,
    this.quickConnectIds = const {},
  });

  final String id;
  final String name;

  /// ARGB color for the generated avatar when there is no photo.
  final int avatarColor;

  /// Profile photo (Phase 1: chosen from the gallery, kept on this phone only).
  final Uint8List? photo;

  /// Used only to place a regular phone call after both sides agreed.
  /// Never shown in the UI.
  final String? phoneNumber;

  /// Whether friends-of-friends / shared-group people may get my number for
  /// a regular call. If either side says no, the call stays inside the app.
  final bool sharesNumberWithFriendsOfFriends;

  /// People this person pre-approved for "quick connect" (call me right away
  /// when we're both free — no extra approval). Only works when mutual.
  final Set<String> quickConnectIds;
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
    Uint8List? photo,
    bool clearPhoto = false,
    String? phoneNumber,
    bool? sharesNumberWithFriendsOfFriends,
    Set<String>? quickConnectIds,
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
    photo: clearPhoto ? null : photo ?? this.photo,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    sharesNumberWithFriendsOfFriends:
        sharesNumberWithFriendsOfFriends ??
        this.sharesNumberWithFriendsOfFriends,
    quickConnectIds: quickConnectIds ?? this.quickConnectIds,
  );

  /// Only used to keep *my own* profile on this phone between launches.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'avatarColor': avatarColor,
    'gender': gender.name,
    'languages': languages.toList(),
    'interests': interests.toList(),
    'groupIds': groupIds.toList(),
    'openTiers': [for (final t in openTiers) t.name],
    'openToFriendsOfFriends': openToFriendsOfFriends,
    'photo': photo == null ? null : base64Encode(photo!),
    'phoneNumber': phoneNumber,
    'sharesNumberWithFriendsOfFriends': sharesNumberWithFriendsOfFriends,
  };

  /// Restores my profile on top of [base] (which carries non-stored fields).
  static Person fromJson(Map<String, Object?> j, Person base) {
    List<String> strs(Object? v) => [for (final x in v as List) x as String];
    final photo = j['photo'] as String?;
    return Person(
      id: base.id,
      name: j['name'] as String? ?? base.name,
      avatarColor: base.avatarColor,
      gender: Gender.values.byName(j['gender'] as String? ?? base.gender.name),
      languages: strs(j['languages']).toSet(),
      interests: strs(j['interests']).toSet(),
      groupIds: strs(j['groupIds']).toSet(),
      friendIds: base.friendIds,
      openTiers: {
        for (final t in strs(j['openTiers'])) MatchTier.values.byName(t),
      },
      openToFriendsOfFriends: j['openToFriendsOfFriends'] as bool? ?? false,
      photo: photo == null ? null : base64Decode(photo),
      phoneNumber: j['phoneNumber'] as String?,
      sharesNumberWithFriendsOfFriends:
          j['sharesNumberWithFriendsOfFriends'] as bool? ?? false,
    );
  }
}

/// A private circle the user defines, e.g. "חברים מהצבא". Only visible to me.
class Circle {
  const Circle({
    required this.id,
    required this.name,
    this.memberIds = const {},
  });
  final String id;
  final String name;
  final Set<String> memberIds;

  Circle copyWith({String? name, Set<String>? memberIds}) => Circle(
    id: id,
    name: name ?? this.name,
    memberIds: memberIds ?? this.memberIds,
  );
}

/// "I usually drive at 08:00 on Sun–Thu." Used to suggest becoming available.
class Routine {
  const Routine({
    required this.id,
    required this.weekdays,
    required this.minuteOfDay,
    required this.durationMinutes,
    required this.mode,
  });

  final String id;

  /// DateTime.weekday values (Mon=1 … Sun=7).
  final Set<int> weekdays;
  final int minuteOfDay;
  final int durationMinutes;
  final AvailabilityMode mode;

  /// True if [now] is within [windowMinutes] of this routine's start today.
  bool isDueAt(DateTime now, {int windowMinutes = 15}) {
    if (!weekdays.contains(now.weekday)) return false;
    final minutes = now.hour * 60 + now.minute;
    return (minutes - minuteOfDay).abs() <= windowMinutes;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'weekdays': weekdays.toList(),
    'minuteOfDay': minuteOfDay,
    'durationMinutes': durationMinutes,
    'mode': mode.name,
  };

  static Routine fromJson(Map<String, Object?> j) => Routine(
    id: j['id'] as String,
    weekdays: {for (final d in j['weekdays'] as List) d as int},
    minuteOfDay: j['minuteOfDay'] as int,
    durationMinutes: j['durationMinutes'] as int,
    mode: AvailabilityMode.values.byName(j['mode'] as String),
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
    this.quickConnect = false,
  });

  final String personId;

  /// My side of "quick connect": I pre-approve being connected right away
  /// when we're both free. Works only if they pre-approved me too.
  final bool quickConnect;

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
    bool? quickConnect,
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
    quickConnect: quickConnect ?? this.quickConnect,
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
    this.circleId,
  });

  final AvailabilityMode mode;

  /// If set, I'm available only to people in this private circle.
  final String? circleId;
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
    this.voiceReadout = true,
    this.voiceCommands = true,
    this.testDialNumber,
    this.dialTestNumberOnEveryCall = true,
    this.routines = const [],
    this.circles = const [],
  });

  /// OPT-IN only. Off by default.
  final bool autoDrivingAvailability;
  final Set<RelationshipType> excludedRelationshipTypes;
  final BeaconFrequency beaconFrequency;
  final DateTime? beaconMutedUntil;
  final bool onboardingDone;
  final bool confirmedAdult;

  /// Driving: read suggestions aloud.
  final bool voiceReadout;

  /// Driving: answer "yes" / "no" by voice (speech recognition on the phone).
  final bool voiceCommands;

  /// Prototype only: a real number (e.g. my own) to test a real phone call.
  final String? testDialNumber;

  /// Prototype only: every regular call actually dials [testDialNumber]
  /// (instead of the fake person), to feel the real flow.
  final bool dialTestNumberOnEveryCall;
  final List<Routine> routines;
  final List<Circle> circles;

  MyPreferences copyWith({
    bool? autoDrivingAvailability,
    Set<RelationshipType>? excludedRelationshipTypes,
    BeaconFrequency? beaconFrequency,
    DateTime? beaconMutedUntil,
    bool clearBeaconMute = false,
    bool? onboardingDone,
    bool? confirmedAdult,
    bool? voiceReadout,
    bool? voiceCommands,
    String? testDialNumber,
    bool clearTestDialNumber = false,
    bool? dialTestNumberOnEveryCall,
    List<Routine>? routines,
    List<Circle>? circles,
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
    voiceReadout: voiceReadout ?? this.voiceReadout,
    voiceCommands: voiceCommands ?? this.voiceCommands,
    testDialNumber: clearTestDialNumber
        ? null
        : testDialNumber ?? this.testDialNumber,
    dialTestNumberOnEveryCall:
        dialTestNumberOnEveryCall ?? this.dialTestNumberOnEveryCall,
    routines: routines ?? this.routines,
    circles: circles ?? this.circles,
  );

  Map<String, Object?> toJson() => {
    'autoDrivingAvailability': autoDrivingAvailability,
    'excludedRelationshipTypes': [
      for (final t in excludedRelationshipTypes) t.name,
    ],
    'beaconFrequency': beaconFrequency.name,
    'onboardingDone': onboardingDone,
    'confirmedAdult': confirmedAdult,
    'voiceReadout': voiceReadout,
    'voiceCommands': voiceCommands,
    'testDialNumber': testDialNumber,
    'dialTestNumberOnEveryCall': dialTestNumberOnEveryCall,
    'routines': [for (final r in routines) r.toJson()],
  };

  /// Circles are seeded data in Phase 1, so they come from [base].
  static MyPreferences fromJson(Map<String, Object?> j, MyPreferences base) =>
      MyPreferences(
        autoDrivingAvailability: j['autoDrivingAvailability'] as bool? ?? false,
        excludedRelationshipTypes: {
          for (final t in (j['excludedRelationshipTypes'] as List? ?? []))
            RelationshipType.values.byName(t as String),
        },
        beaconFrequency: BeaconFrequency.values.byName(
          j['beaconFrequency'] as String? ?? 'normal',
        ),
        onboardingDone: j['onboardingDone'] as bool? ?? false,
        confirmedAdult: j['confirmedAdult'] as bool? ?? false,
        voiceReadout: j['voiceReadout'] as bool? ?? true,
        voiceCommands: j['voiceCommands'] as bool? ?? true,
        testDialNumber: j['testDialNumber'] as String?,
        dialTestNumberOnEveryCall:
            j['dialTestNumberOnEveryCall'] as bool? ?? true,
        routines: [
          for (final r in (j['routines'] as List? ?? []))
            Routine.fromJson((r as Map).cast<String, Object?>()),
        ],
        circles: base.circles,
      );
}

enum ReportReason { inappropriate, harassment, spam, underage, other }
