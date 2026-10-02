/// Audio-only calls. No recording, no transcription, no AI on call content.
/// Phase 1: simulated. Phase 5: managed RTC (LiveKit preferred, needs approval).
abstract class CallService {
  Future<void> startCall(String personId);
  Future<void> setMuted(bool muted);
  Future<void> endCall();
}
