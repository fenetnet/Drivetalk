import 'observable.dart';

/// Is the app online? (Phase 1: the debug screen can simulate "no internet".)
abstract class NetworkService implements ObservableService {
  bool get online;

  /// Poor connection quality (shown as a small hint during in-app calls).
  bool get weakSignal;
}
