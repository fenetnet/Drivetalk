import '../domain/models.dart';

/// A reason shown to the user for why someone was suggested.
///
/// Reasons are structured data built only from fields we actually have; the
/// UI turns them into text. This makes it impossible to "invent" a reason.
sealed class MatchReason {
  const MatchReason();
}

class AvailableForReason extends MatchReason {
  const AvailableForReason(this.minutes, {this.mode});
  final int minutes;
  final AvailabilityMode? mode;
}

class DormantReason extends MatchReason {
  const DormantReason(this.days);
  final int days;
}

class NeverTalkedInAppReason extends MatchReason {
  const NeverTalkedInAppReason();
}

class MutualFriendsReason extends MatchReason {
  const MutualFriendsReason(this.count);
  final int count;
}

class SharedGroupReason extends MatchReason {
  const SharedGroupReason(this.groupName);
  final String groupName;
}

class SharedInterestsReason extends MatchReason {
  const SharedInterestsReason(this.interests);
  final List<String> interests;
}

class BothOpenToFriendsOfFriendsReason extends MatchReason {
  const BothOpenToFriendsOfFriendsReason();
}

class EnjoyedLastTimeReason extends MatchReason {
  const EnjoyedLastTimeReason();
}

/// The other side already said "yes" to my availability invitation.
class AnsweredYourInvitationReason extends MatchReason {
  const AnsweredYourInvitationReason();
}
