import '../matching/matching_engine.dart';
import '../services/availability_service.dart';
import '../services/clock_service.dart';
import '../services/match_service.dart';
import '../services/profile_service.dart';
import '../services/social_graph_service.dart';

/// Gathers data from the services into matching-engine inputs.
/// Keeps the engine itself pure and independent of where data comes from.
class MatchingFacade {
  MatchingFacade({
    required this.profile,
    required this.graph,
    required this.availability,
    required this.match,
    required this.clock,
    required this.engine,
  });

  final ProfileService profile;
  final SocialGraphService graph;
  final AvailabilityService availability;
  final MatchService match;
  final ClockService clock;
  final MatchingEngine engine;

  List<CandidateInput> candidates() => [
    for (final p in graph.people)
      CandidateInput(
        person: p,
        connection: graph.connectionWith(p.id),
        availability: availability.availabilityOf(p.id),
        mutualFriends: graph.mutualFriendsWith(p.id),
        sharedGroups: graph.sharedGroupsWith(p.id),
        lastSuggestedAt: match.lastSuggestedAt(p.id),
        pause: graph.pauseFor(p.id),
      ),
  ];

  MatchRequest request({
    bool requireAvailable = true,
    Set<String> excludeIds = const {},
  }) => MatchRequest(
    me: profile.me,
    prefs: profile.prefs,
    now: clock.now(),
    myAvailability: availability.mine,
    blockedIds: graph.blockedIds,
    excludeIds: excludeIds,
    requireAvailable: requireAvailable,
  );

  RankResult rank({
    bool requireAvailable = true,
    Set<String> excludeIds = const {},
  }) => engine.rank(
    request(requireAvailable: requireAvailable, excludeIds: excludeIds),
    candidates(),
  );
}
