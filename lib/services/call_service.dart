/// How a call happens once both sides agreed.
///
/// - [phone]: a regular phone call from the phone's own dialer (used with my
///   connections, and with friends-of-friends / groups when BOTH allow sharing
///   numbers). The app never touches call settings and never reads the call log.
/// - [inApp]: an audio call inside the app, so phone numbers stay private.
///   Phase 1: simulated. Phase 5: managed RTC (LiveKit preferred, needs approval).
///
/// No recording, no transcription, no AI on call content — in either method.
enum CallMethod { phone, inApp }

abstract class CallService {
  Future<void> startInAppCall(String personId);
  Future<void> setMuted(bool muted);
  Future<void> endInAppCall();
}
