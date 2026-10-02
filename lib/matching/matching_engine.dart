import 'dart:math';

import '../domain/models.dart';
import 'match_reason.dart';
import 'matching_config.dart';

/// Everything the engine needs to know about one potential person to talk to.
class CandidateInput {
  const CandidateInput({
    required this.person,
    this.connection,
    this.availability,
    this.mutualFriends = 0,
    this.sharedGroups = const [],
    this.lastSuggestedAt,
    this.pause,
  });

  final Person person;

  /// Null when this is not someone I'm connected to (friend-of-friend / group).
  final Connection? connection;
  final Availability? availability;
  final int mutualFriends;
  final List<Group> sharedGroups;
  final DateTime? lastSuggestedAt;
  final SuggestionPause? pause;
}

class MatchRequest {
  const MatchRequest({
    required this.me,
    required this.prefs,
    required this.now,
    this.myAvailability,
    this.blockedIds = const {},
    this.excludeIds = const {},
    this.requireAvailable = true,
  });

  final Person me;
  final MyPreferences prefs;
  final DateTime now;
  final Availability? myAvailability;

  /// Blocked in either direction.
  final Set<String> blockedIds;

  /// Already skipped / suggested in the current availability window.
  final Set<String> excludeIds;

  /// False when ranking people to send an availability invitation (beacon) to.
  final bool requireAvailable;
}

/// Why a candidate was removed before scoring (shown in the debug inspector).
enum FilterReason {
  blocked,
  skippedThisSession,
  safety,
  notToday,
  doNotSuggest,
  relationshipExcluded,
  noSharedLanguage,
  notAvailable,
  friendsOfFriendsNotMutual,
  tierNotOpen,
}

class ScoredCandidate {
  const ScoredCandidate({
    required this.input,
    required this.tier,
    required this.score,
    required this.contributions,
    required this.reasons,
  });

  final CandidateInput input;
  final MatchTier tier;
  final double score;

  /// Feature name → weight × value, for transparency.
  final Map<String, double> contributions;
  final List<MatchReason> reasons;
}

class RejectedCandidate {
  const RejectedCandidate(this.input, this.reason);
  final CandidateInput input;
  final FilterReason reason;
}

class RankResult {
  const RankResult(this.ranked, this.rejected);
  final List<ScoredCandidate> ranked;
  final List<RejectedCandidate> rejected;
}

class Suggestion {
  const Suggestion({
    required this.candidate,
    this.isExploration = false,
    this.alreadyAccepted = false,
  });

  final ScoredCandidate candidate;

  /// Picked by the controlled-serendipity rule rather than the top score.
  final bool isExploration;

  /// The other side already said yes (they answered my invitation).
  final bool alreadyAccepted;

  Person get person => candidate.input.person;
}

/// Simple, transparent, rule-based matching: filter → score → pick → explain.
class MatchingEngine {
  MatchingEngine(this.config, {Random? random}) : _random = random ?? Random();

  final MatchingConfig config;
  final Random _random;

  static const _closeTypes = {
    RelationshipType.family,
    RelationshipType.closeFriend,
    RelationshipType.friend,
    RelationshipType.childhoodFriend,
  };
  static const _widerTypes = {
    RelationshipType.colleague,
    RelationshipType.formerColleague,
    RelationshipType.acquaintance,
  };

  RankResult rank(MatchRequest req, List<CandidateInput> candidates) {
    final ranked = <ScoredCandidate>[];
    final rejected = <RejectedCandidate>[];
    for (final c in candidates) {
      if (c.person.id == req.me.id) continue;
      final reason = _filter(req, c);
      if (reason != null) {
        rejected.add(RejectedCandidate(c, reason));
        continue;
      }
      final tier = _chooseTier(req, c);
      if (tier == null) {
        rejected.add(RejectedCandidate(c, FilterReason.tierNotOpen));
        continue;
      }
      ranked.add(_score(req, c, tier));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    return RankResult(ranked, rejected);
  }

  /// Usually the best candidate; sometimes (explorationRate) a good-but-not-top
  /// one, so the app stays a little surprising without becoming random.
  Suggestion? pick(RankResult result) {
    final ranked = result.ranked;
    if (ranked.isEmpty) return null;
    final pool = min(config.explorationTopK, ranked.length);
    if (pool > 1 && _random.nextDouble() < config.explorationRate) {
      return Suggestion(
        candidate: ranked[1 + _random.nextInt(pool - 1)],
        isExploration: true,
      );
    }
    return Suggestion(candidate: ranked.first);
  }

  // ---------------------------------------------------------------- filters

  FilterReason? _filter(MatchRequest req, CandidateInput c) {
    final p = c.person;
    final conn = c.connection;
    final now = req.now;
    if (req.blockedIds.contains(p.id)) return FilterReason.blocked;
    if (req.excludeIds.contains(p.id)) return FilterReason.skippedThisSession;
    if (p.safetyRestricted || !p.adultVerified) return FilterReason.safety;
    final pause = c.pause;
    if (pause != null && pause.until.isAfter(now)) {
      return pause.kind == PauseKind.notToday
          ? FilterReason.notToday
          : FilterReason.doNotSuggest;
    }
    final rel = conn?.relationshipType;
    if (rel != null && req.prefs.excludedRelationshipTypes.contains(rel)) {
      return FilterReason.relationshipExcluded;
    }
    if (req.me.languages.intersection(p.languages).isEmpty) {
      return FilterReason.noSharedLanguage;
    }
    if (req.requireAvailable && !_isAvailable(c, now)) {
      return FilterReason.notAvailable;
    }
    if (conn == null &&
        c.sharedGroups.isEmpty &&
        !(c.mutualFriends > 0 && _bothOpenToFof(req, c))) {
      return FilterReason.friendsOfFriendsNotMutual;
    }
    return null;
  }

  bool _isAvailable(CandidateInput c, DateTime now) =>
      c.availability?.isActiveAt(now) ?? false;

  bool _bothOpenToFof(MatchRequest req, CandidateInput c) =>
      req.me.openToFriendsOfFriends && c.person.openToFriendsOfFriends;

  // ------------------------------------------------------------------ tiers

  int? _daysSilent(Connection conn, DateTime now) =>
      conn.lastInteraction == null
      ? null
      : now.difference(conn.lastInteraction!).inDays;

  bool _isDormant(Connection conn, DateTime now) {
    final days = _daysSilent(conn, now);
    return days != null && days >= config.dormantAfterDays;
  }

  /// Tiers this candidate can belong to, from the relationship alone.
  Set<MatchTier> eligibleTiers(CandidateInput c, DateTime now) {
    final conn = c.connection;
    if (conn == null) return {MatchTier.widenCircle, MatchTier.surpriseMe};
    final rel = conn.relationshipType;
    final tiers = <MatchTier>{};
    if (_isDormant(conn, now)) tiers.add(MatchTier.reconnect);
    if (rel == null || _closeTypes.contains(rel)) {
      if (!_isDormant(conn, now)) tiers.add(MatchTier.familiar);
    }
    if (_widerTypes.contains(rel)) tiers.add(MatchTier.widenCircle);
    if (rel == RelationshipType.acquaintance) tiers.add(MatchTier.surpriseMe);
    return tiers;
  }

  /// Both sides must be open to the tier. Ordered from most to least familiar.
  MatchTier? _chooseTier(MatchRequest req, CandidateInput c) {
    final eligible = eligibleTiers(c, req.now);
    for (final t in MatchTier.values) {
      if (eligible.contains(t) &&
          req.me.openTiers.contains(t) &&
          c.person.openTiers.contains(t)) {
        return t;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- scoring

  ScoredCandidate _score(MatchRequest req, CandidateInput c, MatchTier tier) {
    final now = req.now;
    final conn = c.connection;
    final features = <String, double>{};

    // How close the relationship is.
    if (conn != null) {
      final rel = conn.relationshipType;
      features['closeness'] = rel == null
          ? config.closenessUnclassified
          : config.closenessByRelationship[rel] ?? config.closenessUnclassified;
    } else {
      features['closeness'] = max(
        c.mutualFriends > 0 ? config.closenessFriendOfFriend : 0,
        c.sharedGroups.isNotEmpty ? config.closenessSharedGroup : 0,
      );
    }

    // Time since last in-app interaction (never the phone call log).
    var dormancy = 0.0;
    final days = conn == null ? null : _daysSilent(conn, now);
    if (days != null && days >= config.dormantAfterDays) {
      dormancy = min(1.0, days / config.dormancyFullDays);
    }
    final declined = conn?.lastDeclinedAt;
    if (declined != null &&
        now.difference(declined).inDays < config.declineCooldownDays) {
      dormancy = 0; // Don't push someone I recently passed on.
    }
    features['dormancy'] = dormancy;

    final available = _isAvailable(c, now);
    features['availableNow'] = available ? 1 : 0;

    var overlap = 0.0;
    if (available) {
      final theirs = c.availability!.minutesLeftAt(now);
      final mine = req.myAvailability?.isActiveAt(now) ?? false
          ? req.myAvailability!.minutesLeftAt(now)
          : theirs;
      overlap = min(1.0, min(mine, theirs) / config.overlapFullMinutes);
    }
    features['overlap'] = overlap;

    final shared = req.me.interests.intersection(c.person.interests).toList()
      ..sort();
    features['sharedInterests'] = min(
      1.0,
      shared.length / config.sharedInterestsFull,
    );
    features['sharedGroup'] = c.sharedGroups.isNotEmpty ? 1 : 0;
    features['mutualFriends'] = min(
      1.0,
      c.mutualFriends / config.mutualFriendsFull,
    );

    final lastSuggested = c.lastSuggestedAt;
    features['recentlySuggested'] =
        lastSuggested != null &&
            now.difference(lastSuggested).inHours <
                config.recentlySuggestedHours
        ? 1
        : 0;

    features['feedback'] = _feedbackValue(conn);

    final contributions = {
      for (final e in features.entries) e.key: e.value * config.weight(e.key),
    };
    final score = contributions.values.fold(0.0, (a, b) => a + b);

    return ScoredCandidate(
      input: c,
      tier: tier,
      score: score,
      contributions: contributions,
      reasons: _explain(req, c, contributions, shared, days),
    );
  }

  double _feedbackValue(Connection? conn) {
    if (conn == null || conn.feedback.isEmpty) return 0;
    var total = 0.0;
    for (final f in conn.feedback) {
      if (f.wantAgain == false) {
        total += -1;
        continue;
      }
      total += switch (f.rating) {
        FeedbackRating.veryGood => 1.0,
        FeedbackRating.good => 0.5,
        FeedbackRating.notReally => -1.0,
      };
    }
    return total / conn.feedback.length;
  }

  // ------------------------------------------------------------ explanation

  List<MatchReason> _explain(
    MatchRequest req,
    CandidateInput c,
    Map<String, double> contributions,
    List<String> sharedInterests,
    int? daysSilent,
  ) {
    final now = req.now;
    final reasons = <MatchReason>[];
    final availability = c.availability;
    if (availability != null && availability.isActiveAt(now)) {
      reasons.add(
        AvailableForReason(
          availability.minutesLeftAt(now),
          mode: availability.mode,
        ),
      );
    }

    // Other reasons, strongest contribution first. Each only if data exists.
    final optional = <(double, MatchReason)>[];
    final conn = c.connection;
    if (daysSilent != null && daysSilent >= config.dormantAfterDays) {
      optional.add((
        contributions['dormancy']! + 0.01,
        DormantReason(daysSilent),
      ));
    } else if (conn != null && conn.lastInteraction == null) {
      optional.add((0.05, const NeverTalkedInAppReason()));
    }
    if (c.mutualFriends > 0) {
      optional.add((
        contributions['mutualFriends']!,
        MutualFriendsReason(c.mutualFriends),
      ));
      if (conn == null && _bothOpenToFof(req, c)) {
        optional.add((
          contributions['mutualFriends']! / 2,
          const BothOpenToFriendsOfFriendsReason(),
        ));
      }
    }
    if (c.sharedGroups.isNotEmpty) {
      optional.add((
        contributions['sharedGroup']!,
        SharedGroupReason(c.sharedGroups.first.name),
      ));
    }
    if (sharedInterests.isNotEmpty) {
      optional.add((
        contributions['sharedInterests']!,
        SharedInterestsReason(sharedInterests.take(2).toList()),
      ));
    }
    final lastFeedback = conn?.feedback.isEmpty ?? true
        ? null
        : conn!.feedback.last;
    if (lastFeedback != null &&
        lastFeedback.rating == FeedbackRating.veryGood &&
        lastFeedback.wantAgain != false) {
      optional.add((contributions['feedback']!, const EnjoyedLastTimeReason()));
    }
    optional.sort((a, b) => b.$1.compareTo(a.$1));
    for (final o in optional) {
      if (reasons.length >= config.maxReasons) break;
      reasons.add(o.$2);
    }
    return reasons;
  }
}
