import 'package:drivetalk/real/memory_backend.dart';

/// A backend that reports "no server configured" (demo-only build).
class NoServerBackend extends MemoryRealBackend {
  NoServerBackend() : super(MemoryServer());
  @override
  bool get isConfigured => false;
}
