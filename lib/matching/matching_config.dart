import '../domain/models.dart';

/// All tunable numbers of the matching engine live here — never inside the
/// engine logic. Phase 1 loads them from `assets/config/matching.json`;
/// later they can come from the server.
class MatchingConfig {
  const MatchingConfig({
    required this.weights,
    required this.closenessByRelationship,
    required this.closenessUnclassified,
    required this.closenessFriendOfFriend,
    required this.closenessSharedGroup,
    required this.dormantAfterDays,
    required this.dormancyFullDays,
    required this.overlapFullMinutes,
    required this.sharedInterestsFull,
    required this.mutualFriendsFull,
    required this.recentlySuggestedHours,
    required this.declineCooldownDays,
    required this.explorationRate,
    required this.explorationTopK,
    required this.maxReasons,
    required this.beacon,
    required this.snooze,
    required this.optionsShown,
    required this.callAnswerTimeoutSeconds,
    required this.quickConnect,
  });

  /// How many people to show at once in normal mode (driver mode shows one).
  final int optionsShown;

  /// If the other side doesn't answer a call request within this, move on.
  final int callAnswerTimeoutSeconds;
  final QuickConnectConfig quickConnect;

  /// Feature name → weight. Negative weights are penalties.
  final Map<String, double> weights;
  final Map<RelationshipType, double> closenessByRelationship;
  final double closenessUnclassified;
  final double closenessFriendOfFriend;
  final double closenessSharedGroup;

  /// After this many days without in-app interaction a known person counts
  /// as "reconnect".
  final int dormantAfterDays;

  /// Days of silence at which the dormancy bonus reaches its maximum.
  final int dormancyFullDays;
  final int overlapFullMinutes;
  final int sharedInterestsFull;
  final int mutualFriendsFull;

  /// A person suggested within this window gets the "recently suggested" penalty.
  final int recentlySuggestedHours;

  /// After I pass on someone, they lose the dormancy bonus for this long.
  final int declineCooldownDays;

  /// Share of picks (0..1) that explore instead of taking the top score.
  final double explorationRate;

  /// Exploration picks come only from this many top candidates.
  final int explorationTopK;
  final int maxReasons;
  final BeaconConfig beacon;
  final SnoozeConfig snooze;

  double weight(String feature) => weights[feature] ?? 0;

  factory MatchingConfig.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => (v as num).toDouble();
    final closeness = j['closeness'] as Map<String, dynamic>;
    return MatchingConfig(
      weights: (j['weights'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, d(v)),
      ),
      closenessByRelationship: {
        for (final t in RelationshipType.values)
          if (closeness.containsKey(t.name)) t: d(closeness[t.name]),
      },
      closenessUnclassified: d(closeness['unclassified']),
      closenessFriendOfFriend: d(closeness['friendOfFriend']),
      closenessSharedGroup: d(closeness['sharedGroup']),
      dormantAfterDays: j['dormantAfterDays'] as int,
      dormancyFullDays: j['dormancyFullDays'] as int,
      overlapFullMinutes: j['overlapFullMinutes'] as int,
      sharedInterestsFull: j['sharedInterestsFull'] as int,
      mutualFriendsFull: j['mutualFriendsFull'] as int,
      recentlySuggestedHours: j['recentlySuggestedHours'] as int,
      declineCooldownDays: j['declineCooldownDays'] as int,
      explorationRate: d(j['explorationRate']),
      explorationTopK: j['explorationTopK'] as int,
      maxReasons: j['maxReasons'] as int,
      beacon: BeaconConfig.fromJson(j['beacon'] as Map<String, dynamic>),
      snooze: SnoozeConfig.fromJson(j['snooze'] as Map<String, dynamic>),
      optionsShown: j['optionsShown'] as int,
      callAnswerTimeoutSeconds: j['callAnswerTimeoutSeconds'] as int,
      quickConnect: QuickConnectConfig.fromJson(
        j['quickConnect'] as Map<String, dynamic>,
      ),
    );
  }
}

class BeaconConfig {
  const BeaconConfig({
    required this.maxRecipientsPerWindow,
    required this.maxPerRecipientPerDayNormal,
    required this.maxPerRecipientPerDayLow,
    required this.waitSecondsBeforeBeacon,
    required this.answerTimeoutSeconds,
  });

  final int maxRecipientsPerWindow;
  final int maxPerRecipientPerDayNormal;
  final int maxPerRecipientPerDayLow;
  final int waitSecondsBeforeBeacon;
  final int answerTimeoutSeconds;

  factory BeaconConfig.fromJson(Map<String, dynamic> j) => BeaconConfig(
    maxRecipientsPerWindow: j['maxRecipientsPerWindow'] as int,
    maxPerRecipientPerDayNormal: j['maxPerRecipientPerDayNormal'] as int,
    maxPerRecipientPerDayLow: j['maxPerRecipientPerDayLow'] as int,
    waitSecondsBeforeBeacon: j['waitSecondsBeforeBeacon'] as int,
    answerTimeoutSeconds: j['answerTimeoutSeconds'] as int,
  );
}

class SnoozeConfig {
  const SnoozeConfig({
    required this.doNotSuggestDays,
    required this.drivingSafetyCapMinutes,
    required this.beaconMuteHours,
  });

  /// "Don't suggest them for a while".
  final int doNotSuggestDays;

  /// "Until the trip ends" still expires after this many minutes.
  final int drivingSafetyCapMinutes;

  /// "Mute these invitations for a while".
  final int beaconMuteHours;

  factory SnoozeConfig.fromJson(Map<String, dynamic> j) => SnoozeConfig(
    doNotSuggestDays: j['doNotSuggestDays'] as int,
    drivingSafetyCapMinutes: j['drivingSafetyCapMinutes'] as int,
    beaconMuteHours: j['beaconMuteHours'] as int,
  );
}

/// "Quick connect": mutual pre-approval, short cancellable countdown.
class QuickConnectConfig {
  const QuickConnectConfig({
    required this.countdownSeconds,
    required this.maxPerWindow,
    required this.maxPerPersonPerDay,
  });

  final int countdownSeconds;
  final int maxPerWindow;
  final int maxPerPersonPerDay;

  factory QuickConnectConfig.fromJson(Map<String, dynamic> j) =>
      QuickConnectConfig(
        countdownSeconds: j['countdownSeconds'] as int,
        maxPerWindow: j['maxPerWindow'] as int,
        maxPerPersonPerDay: j['maxPerPersonPerDay'] as int,
      );
}
