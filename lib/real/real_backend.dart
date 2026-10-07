import 'dart:typed_data';

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
  /// Yes / not now. The second "yes" gets the number back at once.
  /// "Not now — I'll get back to you": a no, and the other side is told so.
  Future<OfferAnswer> declineLater(String offerId);

  /// Totals for the owner (no names, nothing about one person).
  Future<Map<String, num?>> appStats(int days);

  Future<OfferAnswer> answerOffer(String offerId, {required bool accept});

  /// Quick connect: my phone shows it (the 5 seconds start once both saw it).
  Future<void> seenCall(String offerId);

  /// Quick connect: cancel during the 5 seconds. False if too late.
  Future<bool> cancelCall(String offerId);

  /// Quick connect (or after a restart): may we dial now, and who dials?
  Future<CallStart> startCall(String offerId);

  /// The call is over for me (frees me for the next offer).
  Future<void> endCall(String offerId);

  /// After a call (also ends it for me). "Not soon" quietly pauses the
  /// pair for a while; "no talk" doesn't count as a talk.
  Future<void> sendCallOutcome(String offerId, CallOutcome outcome);

  /// My phone number for regular calls (null = not shared).
  Future<String?> getMyPhone();
  Future<void> setMyPhone(String? phone);

  /// Automatic driving: a token this phone uses in the background.
  Future<String> createDeviceToken();
  Future<void> revokeDeviceTokens();

  /// Upload hashed contact numbers; returns contacts who use DriveTalk and
  /// can be added. Connects nobody (I pick).
  Future<List<ContactMatch>> syncContacts(List<String> hashes);

  /// Add the contacts I picked — connected at once. Returns their names.
  Future<List<String>> addContacts(List<String> userIds);

  /// How much I want to talk with a friend, 0 (never offer) – 5 (first).
  Future<void> setRating(String friendId, int rating);

  /// Hide my status from friends (and theirs from me).
  Future<void> setHideStatus(bool hide);

  /// My profile photo (a small JPEG); null removes it.
  Future<void> setPhoto(Uint8List? jpeg);

  /// A friend's (or my) photo; null if there is none or I may not see it.
  Future<Uint8List?> downloadPhoto(String userId);

  /// "I'd like to talk" with a friend (never told to them). null = always.
  Future<void> setTalkIntent(String userId, DateTime? until);
  Future<void> clearTalkIntent(String userId);

  /// Realtime per table (true = watching). Empty when not applicable.
  Map<String, bool> get realtimeTables => const {};

  /// The server's version (see schema_version()); 0 = older than that.
  Future<int> schemaVersion();

  /// Remove the hashed contact numbers I uploaded (connections stay).
  Future<void> clearContactHashes();

  /// Delete my account and everything that belongs to it (photo too).
  Future<void> deleteAccount();

  /// A measurement: an event name and maybe a duration. Never content.
  Future<void> logEvent(String name, {int? ms});

  /// "I opened the app" (for friends' "last active", whole days only).
  Future<void> touchSeen();

  /// The owner's code also registers this account as owner on the server.
  Future<bool> claimOwner(String code);

  /// Owner only: latest feedback and reports.
  Future<List<OwnerNote>> ownerFeedback();
  Future<List<OwnerNote>> ownerReports();

  /// A short note to the owner ("Send feedback").
  Future<void> sendFeedback(String text, {int? build});

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
