import '../domain/models.dart';
import 'observable.dart';

/// Real-time availability. The server only ever learns status, mode and
/// expiry — never location, route or speed.
abstract class AvailabilityService implements ObservableService {
  Availability? get mine;
  Future<void> start(Availability availability);
  Future<void> stop();
  Availability? availabilityOf(String personId);
}
