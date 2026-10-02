/// Short voice notes ("hey, thought of you") when the other side can't talk.
/// A note is something the user chooses to record and send — calls are never
/// recorded. Phase 1: simulated, no audio is captured or stored.
abstract class VoiceMessageService {
  Future<void> send(String personId, Duration length);
}
