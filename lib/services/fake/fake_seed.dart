import '../../domain/models.dart';

/// Phase 1 fake data: a varied cast so the matching engine can be felt.
/// Everything here is invented; nothing is real user data.

const meId = 'me';

const fakeGroups = <String, Group>{
  'running': Group(id: 'running', name: 'קבוצת הריצה של הבוקר'),
  'parents': Group(id: 'parents', name: 'קהילת הורים צעירים'),
};

/// Fake people's phone numbers are placeholders; the prototype never dials them.
const _allTiers = {
  MatchTier.familiar,
  MatchTier.reconnect,
  MatchTier.widenCircle,
  MatchTier.surpriseMe,
};

/// Seed for one fake person.
class FakePersonSeed {
  const FakePersonSeed({
    required this.person,
    this.relationship,
    this.contextLabel,
    this.isConnection = true,
    this.daysSinceInteraction,
    this.callCount = 0,
    this.feedback = const [],
    this.availableMinutes,
    this.mode = AvailabilityMode.free,
    this.acceptProbability = 0.7,
    this.myQuickConnect = false,
  });

  final Person person;
  final RelationshipType? relationship;
  final String? contextLabel;
  final bool isConnection;
  final int? daysSinceInteraction;
  final int callCount;
  final List<FeedbackRating> feedback;

  /// Null → not available at start.
  final int? availableMinutes;
  final AvailabilityMode mode;

  /// Fake-only: chance they say yes when asked to talk.
  final double acceptProbability;

  /// My side of "quick connect" with this person.
  final bool myQuickConnect;
}

/// Private circles the user starts with (editable in the Connections screen).
const seedCircles = <Circle>[
  Circle(id: 'family', name: 'משפחה', memberIds: {'michal', 'avi'}),
  Circle(id: 'army', name: 'חברים מהצבא', memberIds: {'yoni'}),
];

Person seedMe() => const Person(
  id: meId,
  name: '',
  avatarColor: 0xFFE07A5F,
  interests: {'פודקאסטים', 'ריצה', 'טכנולוגיה', 'מוזיקה'},
  groupIds: {'running', 'parents'},
);

final fakeSeeds = <FakePersonSeed>[
  const FakePersonSeed(
    person: Person(
      id: 'dana',
      phoneNumber: '050-555-0102',
      quickConnectIds: {meId},
      gender: Gender.female,
      name: 'דנה',
      avatarColor: 0xFFE76F51,
      interests: {'פודקאסטים', 'ספרים', 'בישול'},
      friendIds: {meId, 'michal', 'tamar', 'maya'},
      openTiers: _allTiers,
      openToFriendsOfFriends: true,
    ),
    relationship: RelationshipType.closeFriend,
    contextLabel: 'החברה הכי טובה',
    daysSinceInteraction: 3,
    callCount: 24,
    feedback: [FeedbackRating.veryGood],
    availableMinutes: 25,
    mode: AvailabilityMode.driving,
    acceptProbability: 0.9,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'michal',
      phoneNumber: '050-555-0103',
      quickConnectIds: {meId},
      gender: Gender.female,
      name: 'מיכל',
      avatarColor: 0xFF9C6644,
      interests: {'בישול', 'הורות'},
      friendIds: {meId, 'dana'},
    ),
    relationship: RelationshipType.family,
    contextLabel: 'אחות',
    daysSinceInteraction: 6,
    callCount: 40,
    acceptProbability: 0.85,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'avi',
      phoneNumber: '050-555-0104',
      quickConnectIds: {meId},
      gender: Gender.male,
      name: 'אבי',
      avatarColor: 0xFF6D597A,
      interests: {'כדורגל', 'טיולים'},
      friendIds: {meId},
    ),
    relationship: RelationshipType.family,
    contextLabel: 'אבא',
    daysSinceInteraction: 2,
    callCount: 60,
    acceptProbability: 0.9,
    myQuickConnect: true,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'yoni',
      phoneNumber: '050-555-0105',
      gender: Gender.male,
      name: 'יוני',
      avatarColor: 0xFF2A9D8F,
      interests: {'כדורגל', 'טכנולוגיה'},
      friendIds: {meId, 'alon'},
    ),
    relationship: RelationshipType.friend,
    contextLabel: 'חבר מהצבא',
    daysSinceInteraction: 150,
    callCount: 3,
    feedback: [FeedbackRating.good],
    availableMinutes: 30,
    mode: AvailabilityMode.walking,
    acceptProbability: 0.8,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'uri',
      phoneNumber: '050-555-0106',
      gender: Gender.male,
      name: 'אורי',
      avatarColor: 0xFF457B9D,
      interests: {'מוזיקה', 'טיולים'},
      friendIds: {meId, 'tamar'},
    ),
    relationship: RelationshipType.childhoodFriend,
    contextLabel: 'חבר ילדות מחיפה',
    daysSinceInteraction: 240,
    callCount: 1,
    availableMinutes: 15,
    mode: AvailabilityMode.breakTime,
    acceptProbability: 0.7,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'gil',
      phoneNumber: '050-555-0107',
      gender: Gender.male,
      name: 'גיל',
      avatarColor: 0xFF8D99AE,
      interests: {'פודקאסטים', 'ספרים'},
      friendIds: {meId, 'alon'},
    ),
    relationship: RelationshipType.friend,
    contextLabel: 'חבר מהאוניברסיטה',
    daysSinceInteraction: 185,
    callCount: 6,
    acceptProbability: 0.7,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'roni',
      phoneNumber: '050-555-0108',
      gender: Gender.female,
      name: 'רוני',
      avatarColor: 0xFFF4A261,
      interests: {'טכנולוגיה', 'ריצה'},
      friendIds: {meId, 'tamar'},
    ),
    relationship: RelationshipType.colleague,
    contextLabel: 'עובדת איתך בצוות',
    daysSinceInteraction: 10,
    callCount: 5,
    availableMinutes: 45,
    mode: AvailabilityMode.driving,
    acceptProbability: 0.7,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'lior',
      phoneNumber: '050-555-0109',
      name: 'ליאור',
      avatarColor: 0xFFB5838D,
      interests: {'מוזיקה', 'צילום'},
      friendIds: {meId},
    ),
    relationship: RelationshipType.colleague,
    contextLabel: 'מהמשרד בתל אביב',
    daysSinceInteraction: 30,
    callCount: 4,
    acceptProbability: 0.5,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'amit',
      phoneNumber: '050-555-0110',
      gender: Gender.male,
      name: 'עמית',
      avatarColor: 0xFF588157,
      interests: {'סטארטאפים', 'טכנולוגיה'},
      friendIds: {meId},
    ),
    relationship: RelationshipType.formerColleague,
    contextLabel: 'מהסטארטאפ הקודם',
    daysSinceInteraction: 120,
    callCount: 2,
    acceptProbability: 0.6,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'daniel',
      phoneNumber: '050-555-0111',
      gender: Gender.male,
      name: 'Daniel',
      avatarColor: 0xFF3D5A80,
      languages: {'en'},
      interests: {'טכנולוגיה'},
      friendIds: {meId},
    ),
    relationship: RelationshipType.colleague,
    contextLabel: 'מהצוות בלונדון (מדבר אנגלית בלבד)',
    daysSinceInteraction: 20,
    callCount: 1,
    availableMinutes: 30,
    mode: AvailabilityMode.driving,
    acceptProbability: 0.5,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'shira',
      phoneNumber: '050-555-0112',
      gender: Gender.female,
      name: 'שירה',
      avatarColor: 0xFFCB997E,
      interests: {'ריצה', 'צילום'},
      groupIds: {'running'},
      friendIds: {meId},
      openTiers: _allTiers,
    ),
    relationship: RelationshipType.acquaintance,
    contextLabel: 'מכירים מקבוצת הריצה',
    callCount: 0,
    availableMinutes: 60,
    mode: AvailabilityMode.free,
    acceptProbability: 0.6,
  ),
  // ---- friends of friends (not connected to me) ----
  const FakePersonSeed(
    person: Person(
      id: 'tamar',
      phoneNumber: '050-555-0113',
      sharesNumberWithFriendsOfFriends: true,
      gender: Gender.female,
      name: 'תמר',
      avatarColor: 0xFFD62828,
      interests: {'פודקאסטים', 'ריצה', 'ספרים'},
      friendIds: {'dana', 'roni', 'uri'},
      openTiers: _allTiers,
      openToFriendsOfFriends: true,
    ),
    isConnection: false,
    availableMinutes: 30,
    mode: AvailabilityMode.driving,
    acceptProbability: 0.7,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'alon',
      phoneNumber: '050-555-0114',
      gender: Gender.male,
      name: 'אלון',
      avatarColor: 0xFF264653,
      interests: {'טכנולוגיה', 'סטארטאפים'},
      friendIds: {'yoni', 'gil'},
      openTiers: _allTiers,
      openToFriendsOfFriends: true,
    ),
    isConnection: false,
    acceptProbability: 0.6,
  ),
  const FakePersonSeed(
    person: Person(
      id: 'maya',
      phoneNumber: '050-555-0115',
      gender: Gender.female,
      name: 'מאיה',
      avatarColor: 0xFFBC6C25,
      interests: {'מוזיקה'},
      friendIds: {'dana'},
      // Did NOT opt in to friends-of-friends → never suggested to me.
      openToFriendsOfFriends: false,
    ),
    isConnection: false,
    availableMinutes: 40,
    mode: AvailabilityMode.free,
    acceptProbability: 0.5,
  ),
  // ---- shared group (not connected, no mutual friends) ----
  const FakePersonSeed(
    person: Person(
      id: 'noa',
      phoneNumber: '050-555-0116',
      sharesNumberWithFriendsOfFriends: true,
      gender: Gender.female,
      name: 'נועה',
      avatarColor: 0xFF7B2CBF,
      interests: {'הורות', 'בישול', 'פודקאסטים'},
      groupIds: {'parents'},
      openTiers: _allTiers,
    ),
    isConnection: false,
    availableMinutes: 20,
    mode: AvailabilityMode.walking,
    acceptProbability: 0.6,
  ),
];
