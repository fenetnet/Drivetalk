import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/providers.dart';
import '../app/session_controller.dart';
import '../app/theme.dart';
import '../features/common/labels.dart';
import '../l10n/app_localizations.dart';
import '../platform/vehicle_signal_source.dart';
import '../platform/voice_service.dart';
import '../services/call_service.dart';
import '../services/fake/fake_services.dart';
import '../services/fake/fake_world.dart';

/// Failure & interruption scenarios. Each one explains when it applies and
/// what to look for; buttons that change the main screen close this page.
class ScenariosSection extends ConsumerWidget {
  const ScenariosSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final world = ref.watch(fakeWorldProvider);
    final session = ref.watch(sessionProvider);
    final c = ref.read(sessionProvider.notifier);
    final vehicle = ref.read(vehicleSignalProvider) as FakeVehicleSignalSource;
    final invitations =
        ref.read(invitationServiceProvider) as FakeInvitationService;

    void toast(String text) => messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    void close() => Navigator.of(context).pop();

    final waiting = session.phase == SessionPhase.waitingForAnswer;
    final inCall = session.phase == SessionPhase.inCall;
    final inAppCall = inCall && session.callMethod == CallMethod.inApp;
    final choosing = session.phase == SessionPhase.options;
    final waitedFor = session.selected?.person;

    final scenarios = <_Scenario>[
      _Scenario(l.scNoAnswerTitle, l.scNoAnswerBody, () {
        world.forcedAnswer = ForcedAnswer.noAnswer;
        world.notify();
        toast(l.scNoAnswerArmed);
      }),
      _Scenario(
        l.scGoneTitle,
        l.scGoneBody,
        waiting && waitedFor != null
            ? () {
                world.setAvailable(waitedFor.id, null);
                close();
              }
            : null,
      ),
      _Scenario(
        l.scBlockedTitle,
        l.scBlockedBody,
        waiting && waitedFor != null
            ? () {
                world.blockedMe.add(waitedFor.id);
                world.notify();
                close();
              }
            : null,
      ),
      _Scenario(
        l.scInviteWhileWaitingTitle,
        l.scInviteWhileWaitingBody,
        waiting
            ? () {
                final from = world.others.keys.firstWhere(
                  (id) =>
                      id != waitedFor?.id && !world.blockedByMe.contains(id),
                );
                if (invitations.simulateIncoming(from, 20)) {
                  close();
                } else {
                  toast(l.debugInvitationMuted);
                }
              }
            : null,
      ),
      _Scenario(
        l.scDroppedTitle,
        l.scDroppedBody,
        inAppCall
            ? () {
                c.simulateCallDropped();
                close();
              }
            : null,
      ),
      _Scenario(
        l.scHoldTitle,
        l.scHoldBody,
        inAppCall
            ? () {
                c.simulateIncomingPhoneCall();
                close();
              }
            : null,
      ),
      _Scenario(
        world.weakSignal ? l.scWeakSignalOff : l.scWeakSignalTitle,
        l.scWeakSignalBody,
        () {
          world.weakSignal = !world.weakSignal;
          world.notify();
        },
      ),
      _Scenario(
        l.scExpireInCallTitle,
        l.scExpireInCallBody,
        inCall
            ? () {
                world.expireMyAvailabilitySoon();
                close();
              }
            : null,
      ),
      _Scenario(
        l.scExitCarInCallTitle,
        l.scExitCarInCallBody,
        inCall
            ? () {
                vehicle.simulate(VehicleTransition.exit);
                close();
              }
            : null,
      ),
      _Scenario(
        l.scEnterCarChoosingTitle,
        l.scEnterCarChoosingBody,
        choosing
            ? () {
                close();
                vehicle.simulate(VehicleTransition.enter);
              }
            : null,
      ),
      _Scenario(
        world.offline ? l.scOfflineOff : l.scOfflineTitle,
        l.scOfflineBody,
        () {
          world.offline = !world.offline;
          world.notify();
        },
      ),
      _Scenario(l.scMicDeniedTitle, l.scMicDeniedBody, () {
        ref
            .read(voiceServiceProvider)
            .simulateAnswer(VoiceAnswer.permissionDenied);
        c.simulateMicDenied();
        close();
      }),
      _Scenario(l.scAppClosedTitle, l.scAppClosedBody, () {
        world.advanceClock(const Duration(hours: 3, minutes: 1));
        ref.invalidate(sessionProvider);
        close();
      }),
      _Scenario(l.scQuickConnectTitle, l.scQuickConnectBody, () {
        world.setAvailable('avi', 30);
        if (session.phase == SessionPhase.idle) {
          toast(l.scQuickConnectHint);
        } else {
          close();
        }
      }),
    ];

    return Column(
      children: [for (final s in scenarios) _ScenarioTile(scenario: s, l: l)],
    );
  }
}

class _Scenario {
  const _Scenario(this.title, this.body, this.run);
  final String title;
  final String body;

  /// Null = not applicable right now (the body says when it is).
  final VoidCallback? run;
}

class _ScenarioTile extends StatelessWidget {
  const _ScenarioTile({required this.scenario, required this.l});
  final _Scenario scenario;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(scenario.title),
      subtitle: Text(
        scenario.body,
        style: const TextStyle(color: AppColors.inkSoft),
      ),
      trailing: FilledButton.tonal(
        onPressed: scenario.run,
        child: Text(l.scRun),
      ),
    );
  }
}
