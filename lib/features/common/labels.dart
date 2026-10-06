import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

/// Turns domain values into localized text. All user-facing wording lives in
/// the ARB files; this file only picks the right message.

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Texts are gender-neutral for everyone (owner decision D-073): the
/// "other" wording is always used, whatever an old profile says.
String genderKey(Gender g) => 'other';

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

String weekdayShort(AppLocalizations l, int weekday) => switch (weekday) {
  DateTime.sunday => l.daySun,
  DateTime.monday => l.dayMon,
  DateTime.tuesday => l.dayTue,
  DateTime.wednesday => l.dayWed,
  DateTime.thursday => l.dayThu,
  DateTime.friday => l.dayFri,
  _ => l.daySat,
};

/// "א׳, ב׳, ג׳" in week order starting Sunday.
String weekdaysText(AppLocalizations l, Set<int> days) => [
  for (final d in const [7, 1, 2, 3, 4, 5, 6])
    if (days.contains(d)) weekdayShort(l, d),
].join(', ');
