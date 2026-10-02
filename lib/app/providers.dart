import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../matching/matching_config.dart';
import '../matching/matching_engine.dart';
import '../platform/vehicle_signal_source.dart';
import '../services/analytics_service.dart';
import '../services/availability_service.dart';
import '../services/call_service.dart';
import '../services/clock_service.dart';
import '../services/fake/fake_services.dart';
import '../services/fake/fake_world.dart';
import '../services/invitation_service.dart';
import '../services/match_service.dart';
import '../services/profile_service.dart';
import '../services/safety_service.dart';
import '../services/social_graph_service.dart';
import 'matching_facade.dart';

// ---------------------------------------------------------------------------
// THE ONE PLACE where fake vs. real services are chosen.
// Phase 2+ swaps these for Supabase / LiveKit implementations; the UI only
// ever sees the interfaces.
// ---------------------------------------------------------------------------

final fakeWorldProvider = Provider<FakeWorld>((ref) => FakeWorld());

final clockProvider = Provider<ClockService>(
  (ref) => FakeClockService(ref.watch(fakeWorldProvider)),
);

final profileServiceProvider = Provider<ProfileService>(
  (ref) => FakeProfileService(ref.watch(fakeWorldProvider)),
);

final socialGraphServiceProvider = Provider<SocialGraphService>(
  (ref) => FakeSocialGraphService(ref.watch(fakeWorldProvider)),
);

final availabilityServiceProvider = Provider<AvailabilityService>(
  (ref) => FakeAvailabilityService(ref.watch(fakeWorldProvider)),
);

final matchServiceProvider = Provider<MatchService>(
  (ref) => FakeMatchService(ref.watch(fakeWorldProvider)),
);

final invitationServiceProvider = Provider<InvitationService>(
  (ref) => FakeInvitationService(ref.watch(fakeWorldProvider)),
);

final callServiceProvider = Provider<CallService>((ref) => FakeCallService());

final safetyServiceProvider = Provider<SafetyService>(
  (ref) => FakeSafetyService(ref.watch(fakeWorldProvider)),
);

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => LocalAnalyticsService(ref.watch(clockProvider)),
);

final vehicleSignalProvider = Provider<VehicleSignalSource>(
  (ref) => FakeVehicleSignalSource(),
);

// ---------------------------------------------------------------------------
// Matching
// ---------------------------------------------------------------------------

/// Loaded from assets/config/matching.json in main() and overridden there.
final matchingConfigProvider = Provider<MatchingConfig>(
  (ref) => throw StateError('matchingConfigProvider must be overridden'),
);

final matchingEngineProvider = Provider<MatchingEngine>(
  (ref) => MatchingEngine(ref.watch(matchingConfigProvider)),
);

final matchingFacadeProvider = Provider<MatchingFacade>(
  (ref) => MatchingFacade(
    profile: ref.watch(profileServiceProvider),
    graph: ref.watch(socialGraphServiceProvider),
    availability: ref.watch(availabilityServiceProvider),
    match: ref.watch(matchServiceProvider),
    clock: ref.watch(clockProvider),
    engine: ref.watch(matchingEngineProvider),
  ),
);

// ---------------------------------------------------------------------------
// Reactivity helpers
// ---------------------------------------------------------------------------

/// Increments whenever any service's cached data changes. Widgets watch this
/// and then read the services synchronously.
final dataVersionProvider = NotifierProvider<DataVersion, int>(DataVersion.new);

class DataVersion extends Notifier<int> {
  @override
  int build() {
    final streams = <Stream<void>>[
      ref.watch(profileServiceProvider).changes,
      ref.watch(socialGraphServiceProvider).changes,
      ref.watch(availabilityServiceProvider).changes,
      ref.watch(matchServiceProvider).changes,
    ];
    final subs = [for (final s in streams) s.listen((_) => state++)];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
    });
    return 0;
  }
}

/// "Now", refreshed every second and whenever data changes (e.g. the debug
/// screen fast-forwards the clock).
final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);

class NowNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => state = clock.now(),
    );
    ref.onDispose(timer.cancel);
    ref.listen(dataVersionProvider, (_, _) => state = clock.now());
    return clock.now();
  }
}
