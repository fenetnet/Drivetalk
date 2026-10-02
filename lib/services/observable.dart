/// A service whose cached state can change (e.g. via server realtime updates).
/// The UI listens to [changes] and re-reads the synchronous getters.
abstract class ObservableService {
  Stream<void> get changes;
}
