/// Source of "now". Injected everywhere so the debug screen can fast-forward time.
abstract class ClockService {
  DateTime now();
}
