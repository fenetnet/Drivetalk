import '../domain/models.dart';

/// "X is free for ~30 minutes. Want to talk?" — sent to a few relevant people
/// when there is no immediate match (Availability Beacon).
class Invitation {
  const Invitation({
    required this.id,
    required this.fromPersonId,
    required this.minutes,
    required this.mode,
    required this.sentAt,
  });
  final String id;
  final String fromPersonId;
  final int minutes;
  final AvailabilityMode mode;
  final DateTime sentAt;
}

enum InvitationResponse { talkNow, notNow, mute }

class InvitationAnswer {
  const InvitationAnswer({required this.personId, required this.accepted});
  final String personId;
  final bool accepted;
}

abstract class InvitationService {
  /// Invitations other people sent me.
  Stream<Invitation> get incoming;

  /// Answers to the invitations I sent.
  Stream<InvitationAnswer> get answers;

  /// Returns the ids that were actually sent (limits may drop some).
  Future<List<String>> sendBeacon(List<String> personIds, Availability mine);
  Future<void> respond(Invitation invitation, InvitationResponse response);

  /// How many invitations this person already received today (rate limit).
  int sentTodayTo(String personId, DateTime now);
}
