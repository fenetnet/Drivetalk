import '../domain/models.dart';

abstract class SafetyService {
  Future<void> report(String personId, ReportReason reason);
}
