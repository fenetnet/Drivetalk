import 'observable.dart';

enum CallRequestOutcome { accepted, declined, timedOut }

/// Mutual-consent handshake and suggestion history.
abstract class MatchService implements ObservableService {
  DateTime? lastSuggestedAt(String personId);
  Future<void> markSuggested(String personId, DateTime at);

  /// Ask the other side whether they want to talk now. A call never starts
  /// without their explicit yes.
  Future<CallRequestOutcome> requestCall(String personId);
}
