import '../domain/models.dart';
import 'observable.dart';

/// People, my connections with them, and safety relationships (block/unmatch).
abstract class SocialGraphService implements ObservableService {
  /// Everyone the app may show me: my connections plus discoverable
  /// friends-of-friends and people from shared groups.
  List<Person> get people;
  Person? personById(String id);

  List<Connection> get connections;
  Connection? connectionWith(String personId);

  /// Count only — names of mutual friends are not exposed.
  int mutualFriendsWith(String personId);
  List<Group> sharedGroupsWith(String personId);
  Group? groupById(String id);

  /// Blocked in either direction.
  Set<String> get blockedIds;
  List<Person> get blockedByMe;

  Future<void> setRelationship(String personId, RelationshipType? type);
  Future<void> addConnection(String personId);

  /// Removes the connection. They can still be found again only via a new invite.
  Future<void> unmatch(String personId);
  Future<void> block(String personId);
  Future<void> unblock(String personId);
  SuggestionPause? pauseFor(String personId);
  Future<void> pauseSuggestions(
    String personId,
    PauseKind kind,
    DateTime until,
  );
  Future<void> allowSuggestions(String personId);
  Future<void> recordCall(String personId, DateTime at);
  Future<void> addFeedback(String personId, FeedbackEntry entry);

  /// Search users by name (Phase 1: fake directory).
  List<Person> search(String query);
}
