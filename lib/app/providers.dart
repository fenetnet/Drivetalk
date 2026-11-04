import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/phone_dialer.dart';
import '../platform/voice_service.dart';

// Device capabilities (tests swap them for fakes).
final phoneDialerProvider = Provider<PhoneDialer>(
  (ref) => PlatformPhoneDialer(),
);

final voiceServiceProvider = Provider<VoiceService>(
  (ref) => DeviceVoiceService(),
);
