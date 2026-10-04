import '../domain/models.dart';
import 'real_models.dart';

/// Everything the app needs from the real backend. Implemented by
/// [SupabaseRealBackend] (production) and an in-memory version for tests.
abstract class RealBackend {
  bool get isConfigured;

  /// Current signed-in user id, or null.
  String? get userId;

  /// Restore a saved session (if any). Never throws for "no session".
  Future<void> start();

  /// Create an account (first time) and set the profile.
  Future<RealProfile> signIn(String name, Gender gender);
  Future<RealProfile> updateProfile(String name, Gender gender);
  Future<void> signOut();

  Future<RealSnapshot> fetchSnapshot();

  /// Fires when something relevant may have changed (realtime events).
  Stream<void> get changes;
  Stream<LiveStatus> get liveStatus;

  Future<CreatedInvitation> createInvitation();
  Future<InviteInfo> getInvitation(String token);
  Future<AcceptResult> acceptInvitation(String token);

  Future<void> setAvailability(
    AvailabilityMode mode,
    int minutes, {
    String? circleId,
  });

  /// Ask the server to create offers that became possible (e.g. a pause
  /// ended). Called every few seconds while I'm free.
  Future<void> nudgeOffers();
  Future<void> clearAvailability();

  /// Returns the offer's new status.
  Future<OfferStatus> respondOffer(String offerId, {required bool accept});

  Future<void> sendFeedback({
    required String? offerId,
    required bool talked,
    FeedbackRating? rating,
    bool? wantAgain,
  });

  /// My phone number for regular calls (null = not shared).
  Future<String?> getMyPhone();
  Future<void> setMyPhone(String? phone);

  /// After both accepted: the other side's number (if they share it).
  Future<CallDetails> callDetails(String offerId);

  /// Automatic driving: a token this phone uses in the background.
  Future<String> createDeviceToken();
  Future<void> revokeDeviceTokens();

  Future<void> block(String userId);

  /// People I blocked (to unblock them).
  Future<List<RealProfile>> blockedPeople();

  /// Returns true if the connection came back.
  Future<bool> unblock(String userId);

  /// Circles (private to me).
  Future<RealCircle> saveCircle(RealCircle circle);
  Future<void> deleteCircle(String circleId);
  Future<void> unmatch(String userId);
  Future<void> report(String userId, ReportReason reason);
}

/// A failure the UI can show in simple words. [code] is a short machine
/// code (never contains secrets) — shown in the test screen.
class RealBackendException implements Exception {
  const RealBackendException(this.code);
  final String code;

  @override
  String toString() => 'RealBackendException($code)';
}
