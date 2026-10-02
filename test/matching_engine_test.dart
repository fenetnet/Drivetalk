import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/matching/match_reason.dart';
import 'package:drivetalk/matching/matching_config.dart';
import 'package:drivetalk/matching/matching_engine.dart';
import 'package:flutter_test/flutter_test.dart';

MatchingConfig loadConfig([void Function(Map<String, dynamic>)? edit]) {
  final json = jsonDecode(
    File('assets/config/matching.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  edit?.call(json);
  return MatchingConfig.fromJson(json);
}

final now = DateTime(2026, 10, 2, 18);

Availability avail(int minutes) => Availability(
  mode: AvailabilityMode.free,
  startedAt: now,
  expiresAt: now.add(Duration(minutes: minutes)),
);

const me = Person(
  id: 'me',
  name: 'Me',
  avatarColor: 0,
  interests: {'ריצה', 'ספרים'},
  openTiers: {MatchTier.familiar, MatchTier.reconnect, MatchTier.widenCircle},
);

MatchRequest req({
  Person person = me,
  MyPreferences prefs = const MyPreferences(),
  bool requireAvailable = true,
  Set<String> blocked = const {},
}) => MatchRequest(
  me: person,
  prefs: prefs,
  now: now,
  myAvailability: avail(30),
  blockedIds: blocked,
  requireAvailable: requireAvailable,
);

CandidateInput friend(
  String id, {
  RelationshipType? type = RelationshipType.friend,
  int? daysAgo = 5,
  int? minutes = 30,
  Set<String> languages = const {'he'},
  Set<String> interests = const {},
  List<FeedbackEntry> feedback = const [],
  DateTime? lastDeclinedAt,
  SuggestionPause? pause,
}) => CandidateInput(
  person: Person(
    id: id,
    name: id,
    avatarColor: 0,
    languages: languages,
    interests: interests,
  ),
  connection: Connection(
    personId: id,
    relationshipType: type,
    lastInteraction: daysAgo == null
        ? null
        : now.subtract(Duration(days: daysAgo)),
    feedback: feedback,
    lastDeclinedAt: lastDeclinedAt,
  ),
  availability: minutes == null ? null : avail(minutes),
  pause: pause,
);

void main() {
  final config = loadConfig();

  test('config file loads and weights are not hard-coded', () {
    expect(config.weight('closeness'), greaterThan(0));
    expect(config.weight('recentlySuggested'), lessThan(0));
    expect(config.explorationRate, inInclusiveRange(0, 1));
    expect(config.beacon.maxRecipientsPerWindow, 3);
  });

  group('filters', () {
    final engine = MatchingEngine(config, random: Random(1));

    test(
      'removes blocked, unavailable, paused, and no-shared-language people',
      () {
        final r = engine.rank(req(blocked: {'blocked'}), [
          friend('ok'),
          friend('blocked'),
          friend('busy', minutes: null),
          friend('english', languages: {'en'}),
          friend(
            'paused',
            pause: SuggestionPause(
              kind: PauseKind.doNotSuggest,
              until: now.add(const Duration(days: 3)),
            ),
          ),
        ]);
        expect(r.ranked.map((c) => c.input.person.id), ['ok']);
        final reasons = {
          for (final x in r.rejected) x.input.person.id: x.reason,
        };
        expect(reasons['blocked'], FilterReason.blocked);
        expect(reasons['busy'], FilterReason.notAvailable);
        expect(reasons['english'], FilterReason.noSharedLanguage);
        expect(reasons['paused'], FilterReason.doNotSuggest);
      },
    );

    test('an expired pause no longer filters', () {
      final r = engine.rank(req(), [
        friend(
          'a',
          pause: SuggestionPause(
            kind: PauseKind.notToday,
            until: now.subtract(const Duration(minutes: 1)),
          ),
        ),
      ]);
      expect(r.ranked, hasLength(1));
    });

    test('relationship types I excluded are not suggested', () {
      final r = engine.rank(
        req(
          prefs: const MyPreferences(
            excludedRelationshipTypes: {RelationshipType.colleague},
          ),
        ),
        [friend('c', type: RelationshipType.colleague)],
      );
      expect(r.rejected.single.reason, FilterReason.relationshipExcluded);
    });

    test('friends-of-friends need BOTH sides to opt in', () {
      CandidateInput fof({required bool theyOptIn}) => CandidateInput(
        person: Person(
          id: 'fof',
          name: 'fof',
          avatarColor: 0,
          openToFriendsOfFriends: theyOptIn,
          openTiers: MatchTier.values.toSet(),
        ),
        mutualFriends: 2,
        availability: avail(30),
      );
      final meOptIn = me.copyWith(openToFriendsOfFriends: true);

      expect(
        engine.rank(req(person: meOptIn), [fof(theyOptIn: true)]).ranked,
        hasLength(1),
      );
      expect(
        engine
            .rank(req(person: meOptIn), [fof(theyOptIn: false)])
            .rejected
            .single
            .reason,
        FilterReason.friendsOfFriendsNotMutual,
      );
      expect(
        engine.rank(req(), [fof(theyOptIn: true)]).rejected.single.reason,
        FilterReason.friendsOfFriendsNotMutual,
      );
    });

    test('a tier is used only if both sides are open to it', () {
      final group = CandidateInput(
        person: const Person(
          id: 'g',
          name: 'g',
          avatarColor: 0,
          openTiers: {MatchTier.surpriseMe},
        ),
        sharedGroups: const [Group(id: 'x', name: 'X')],
        availability: avail(30),
      );
      // I'm not open to "surprise me" → no common tier.
      expect(
        engine.rank(req(), [group]).rejected.single.reason,
        FilterReason.tierNotOpen,
      );
      final open = me.copyWith(
        openTiers: {...me.openTiers, MatchTier.surpriseMe},
      );
      final r = engine.rank(req(person: open), [group]);
      expect(r.ranked.single.tier, MatchTier.surpriseMe);
    });
  });

  group('tiers, scoring and explanations', () {
    final engine = MatchingEngine(config, random: Random(1));

    test(
      'a friend not talked to for 150 days is "reconnect" with a real reason',
      () {
        final r = engine.rank(req(), [friend('yoni', daysAgo: 150)]);
        final c = r.ranked.single;
        expect(c.tier, MatchTier.reconnect);
        expect(c.reasons.first, isA<AvailableForReason>());
        final dormant = c.reasons.whereType<DormantReason>().single;
        expect(dormant.days, 150);
      },
    );

    test('dormancy raises the score, unless I passed on them recently', () {
      final recent = engine
          .rank(req(), [friend('a', daysAgo: 3)])
          .ranked
          .single;
      final dormant = engine
          .rank(req(), [friend('a', daysAgo: 200)])
          .ranked
          .single;
      final declined = engine
          .rank(req(), [
            friend(
              'a',
              daysAgo: 200,
              lastDeclinedAt: now.subtract(const Duration(days: 2)),
            ),
          ])
          .ranked
          .single;
      expect(dormant.score, greaterThan(recent.score));
      expect(declined.contributions['dormancy'], 0);
    });

    test('reasons never invent data', () {
      final c = engine.rank(req(), [friend('a', daysAgo: 3)]).ranked.single;
      expect(c.reasons.whereType<MutualFriendsReason>(), isEmpty);
      expect(c.reasons.whereType<SharedGroupReason>(), isEmpty);
      expect(c.reasons.whereType<DormantReason>(), isEmpty);
      expect(c.reasons.whereType<SharedInterestsReason>(), isEmpty);

      final withInterest = engine
          .rank(req(), [
            friend('b', interests: {'ריצה', 'שחייה'}),
          ])
          .ranked
          .single;
      final shared = withInterest.reasons
          .whereType<SharedInterestsReason>()
          .single;
      expect(shared.interests, ['ריצה']);
    });

    test('at most maxReasons reasons', () {
      final c = engine
          .rank(req(), [
            friend(
              'a',
              daysAgo: 300,
              interests: {'ריצה', 'ספרים'},
              feedback: [
                FeedbackEntry(
                  at: now,
                  rating: FeedbackRating.veryGood,
                  wantAgain: true,
                ),
              ],
            ),
          ])
          .ranked
          .single;
      expect(c.reasons.length, lessThanOrEqualTo(config.maxReasons));
    });

    test('"do not connect again" feedback lowers the score', () {
      final liked = engine
          .rank(req(), [
            friend(
              'a',
              feedback: [
                FeedbackEntry(
                  at: now,
                  rating: FeedbackRating.veryGood,
                  wantAgain: true,
                ),
              ],
            ),
          ])
          .ranked
          .single;
      final notAgain = engine
          .rank(req(), [
            friend(
              'a',
              feedback: [
                FeedbackEntry(
                  at: now,
                  rating: FeedbackRating.good,
                  wantAgain: false,
                ),
              ],
            ),
          ])
          .ranked
          .single;
      expect(liked.score, greaterThan(notAgain.score));
    });

    test('closer relationships rank higher, all else equal', () {
      final r = engine.rank(req(), [
        friend('acq', type: RelationshipType.acquaintance),
        friend('family', type: RelationshipType.family),
      ]);
      expect(r.ranked.first.input.person.id, 'family');
    });
  });

  group('controlled serendipity', () {
    final candidates = [
      friend('top', type: RelationshipType.family),
      friend('second', type: RelationshipType.friend),
      friend('third', type: RelationshipType.acquaintance),
    ];

    test('exploration 0 → always the top score', () {
      final engine = MatchingEngine(
        loadConfig((j) => j['explorationRate'] = 0.0),
        random: Random(7),
      );
      for (var i = 0; i < 50; i++) {
        final s = engine.pick(engine.rank(req(), candidates))!;
        expect(s.person.id, 'top');
        expect(s.isExploration, isFalse);
      }
    });

    test('exploration 1 → never the top, but always from the top-K', () {
      final engine = MatchingEngine(
        loadConfig((j) => j['explorationRate'] = 1.0),
        random: Random(7),
      );
      for (var i = 0; i < 50; i++) {
        final s = engine.pick(engine.rank(req(), candidates))!;
        expect(s.person.id, isNot('top'));
        expect(s.isExploration, isTrue);
      }
    });

    test('no candidates → no suggestion', () {
      final engine = MatchingEngine(config);
      expect(engine.pick(engine.rank(req(), const [])), isNull);
    });
  });
}
