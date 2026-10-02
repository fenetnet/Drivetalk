import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../matching/match_reason.dart';
import '../../matching/matching_engine.dart';

/// Turns domain values into localized text. All user-facing wording lives in
/// the ARB files; this file only picks the right message.

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String genderKey(Gender g) => switch (g) {
  Gender.female => 'female',
  Gender.male => 'male',
  Gender.unspecified => 'other',
};

String relationshipLabel(AppLocalizations l, RelationshipType? t) =>
    switch (t) {
      RelationshipType.family => l.relFamily,
      RelationshipType.closeFriend => l.relCloseFriend,
      RelationshipType.friend => l.relFriend,
      RelationshipType.childhoodFriend => l.relChildhoodFriend,
      RelationshipType.colleague => l.relColleague,
      RelationshipType.formerColleague => l.relFormerColleague,
      RelationshipType.acquaintance => l.relAcquaintance,
      null => l.relNone,
    };

String tierLabel(AppLocalizations l, MatchTier t) => switch (t) {
  MatchTier.familiar => l.tierFamiliar,
  MatchTier.reconnect => l.tierReconnect,
  MatchTier.widenCircle => l.tierWiden,
  MatchTier.surpriseMe => l.tierSurprise,
};

String tierDescription(AppLocalizations l, MatchTier t) => switch (t) {
  MatchTier.familiar => l.tierFamiliarDesc,
  MatchTier.reconnect => l.tierReconnectDesc,
  MatchTier.widenCircle => l.tierWidenDesc,
  MatchTier.surpriseMe => l.tierSurpriseDesc,
};

String modeLabel(AppLocalizations l, AvailabilityMode m) => switch (m) {
  AvailabilityMode.driving => l.modeDriving,
  AvailabilityMode.walking => l.modeWalking,
  AvailabilityMode.breakTime => l.modeBreak,
  AvailabilityMode.free => l.modeFree,
};

IconData modeIcon(AvailabilityMode m) => switch (m) {
  AvailabilityMode.driving => Icons.directions_car_rounded,
  AvailabilityMode.walking => Icons.directions_walk_rounded,
  AvailabilityMode.breakTime => Icons.local_cafe_rounded,
  AvailabilityMode.free => Icons.wb_sunny_rounded,
};

/// "5 חודשים", "יומיים", "יותר משנה".
String durationText(AppLocalizations l, int days) {
  if (days >= 365) return l.durationYearPlus;
  if (days >= 45) return l.durationMonths((days / 30).round());
  return l.durationDays(days < 1 ? 1 : days);
}

String joinList(AppLocalizations l, List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')}${l.listAnd}${items.last}';
}

/// The relationship line under a person's name: what *I* call them,
/// e.g. "חבר מהצבא", or how we are linked.
String relationshipLine(
  AppLocalizations l, {
  Connection? connection,
  int mutualFriends = 0,
  List<Group> sharedGroups = const [],
}) {
  if (connection != null) {
    final label = connection.contextLabel;
    if (label != null && label.isNotEmpty) return label;
    return connection.relationshipType == null
        ? l.relUnclassified
        : relationshipLabel(l, connection.relationshipType);
  }
  if (mutualFriends > 0) return l.relFriendOfFriend;
  if (sharedGroups.isNotEmpty) return l.relSharedGroup;
  return l.relUnclassified;
}

String reasonText(AppLocalizations l, MatchReason r, Person person) =>
    switch (r) {
      AvailableForReason(:final minutes) => l.reasonAvailable(
        person.name,
        genderKey(person.gender),
        minutes,
      ),
      DormantReason(:final days) => l.reasonDormant(durationText(l, days)),
      NeverTalkedInAppReason() => l.reasonNeverTalked,
      MutualFriendsReason(:final count) => l.reasonMutualFriends(count),
      SharedGroupReason(:final groupName) => l.reasonSharedGroup(groupName),
      SharedInterestsReason(:final interests) => l.reasonSharedInterests(
        joinList(l, interests),
      ),
      BothOpenToFriendsOfFriendsReason() => l.reasonBothFof,
      EnjoyedLastTimeReason() => l.reasonEnjoyedLastTime,
      AnsweredYourInvitationReason() => l.reasonAnswered(
        person.name,
        genderKey(person.gender),
      ),
    };

IconData reasonIcon(MatchReason r) => switch (r) {
  AvailableForReason() => Icons.schedule_rounded,
  DormantReason() => Icons.history_rounded,
  NeverTalkedInAppReason() => Icons.waving_hand_rounded,
  MutualFriendsReason() => Icons.people_alt_rounded,
  SharedGroupReason() => Icons.groups_rounded,
  SharedInterestsReason() => Icons.interests_rounded,
  BothOpenToFriendsOfFriendsReason() => Icons.handshake_rounded,
  EnjoyedLastTimeReason() => Icons.favorite_rounded,
  AnsweredYourInvitationReason() => Icons.check_circle_rounded,
};

String filterLabel(AppLocalizations l, FilterReason r) => switch (r) {
  FilterReason.blocked => l.filterBlocked,
  FilterReason.skippedThisSession => l.filterSkipped,
  FilterReason.safety => l.filterSafety,
  FilterReason.notToday => l.filterNotToday,
  FilterReason.doNotSuggest => l.filterDoNotSuggest,
  FilterReason.relationshipExcluded => l.filterRelExcluded,
  FilterReason.noSharedLanguage => l.filterLanguage,
  FilterReason.notAvailable => l.filterNotAvailable,
  FilterReason.friendsOfFriendsNotMutual => l.filterFof,
  FilterReason.tierNotOpen => l.filterTier,
};

String featureLabel(AppLocalizations l, String feature) => switch (feature) {
  'closeness' => l.featCloseness,
  'dormancy' => l.featDormancy,
  'availableNow' => l.featAvailableNow,
  'overlap' => l.featOverlap,
  'sharedInterests' => l.featSharedInterests,
  'sharedGroup' => l.featSharedGroup,
  'mutualFriends' => l.featMutualFriends,
  'recentlySuggested' => l.featRecentlySuggested,
  'feedback' => l.featFeedback,
  _ => feature,
};
