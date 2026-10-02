import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/providers.dart';
import '../app/session_controller.dart';
import '../app/theme.dart';
import '../domain/models.dart';
import '../features/common/labels.dart';
import '../features/common/widgets.dart';
import '../platform/vehicle_signal_source.dart';
import '../services/fake/fake_services.dart';
import '../services/fake/fake_world.dart';
import '../platform/voice_service.dart';
import 'matching_inspector.dart';
import 'scenarios.dart';

/// Developer / debug screen. Only compiled in when kDevTools is true; never
/// part of a store build. Lets us test the whole UX without a real drive or a
/// second user.
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final world = ref.watch(fakeWorldProvider);
    final session = ref.watch(sessionProvider);
    final prefs = ref.watch(profileServiceProvider).prefs;
    final vehicle = ref.watch(vehicleSignalProvider) as FakeVehicleSignalSource;
    final forceNoMatch = ref.watch(debugForceNoMatchProvider);

    void toast(String text) => messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    // Close the debug screen when the action changes what the user should see.
    void closeAnd(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    String two(int n) => n.toString().padLeft(2, '0');
    final clockText =
        '${two(now.day)}/${two(now.month)}  ${two(now.hour)}:${two(now.minute)}';

    return Scaffold(
      appBar: AppBar(title: Text(l.debugTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ---------------------------------------------------------- vehicle
          SectionTitle(l.debugVehicle),
          _Pad(
            Text(session.inVehicle ? l.debugInVehicleYes : l.debugInVehicleNo),
          ),
          if (!prefs.autoDrivingAvailability)
            _Pad(
              Text(
                l.debugAutoOffWarning,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            ),
          _Buttons([
            (
              l.debugEnterVehicle,
              () => closeAnd(() => vehicle.simulate(VehicleTransition.enter)),
            ),
            (
              l.debugEnterVehicleBt,
              () => closeAnd(
                () => vehicle.simulate(
                  VehicleTransition.enter,
                  confidence: VehicleConfidence.high,
                ),
              ),
            ),
            (
              l.debugExitVehicle,
              () => closeAnd(() => vehicle.simulate(VehicleTransition.exit)),
            ),
          ]),

          // -------------------------------------------------------- scenarios
          SectionTitle(l.debugScenarios),
          const ScenariosSection(),

          // ------------------------------------------------------------ voice
          SectionTitle(l.debugVoice),
          _Pad(
            Text(
              l.debugVoiceBody,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
          _Buttons([
            (
              l.debugVoiceYes,
              () => ref
                  .read(voiceServiceProvider)
                  .simulateAnswer(VoiceAnswer.yes),
            ),
            (
              l.debugVoiceNo,
              () =>
                  ref.read(voiceServiceProvider).simulateAnswer(VoiceAnswer.no),
            ),
          ]),

          // -------------------------------------------------------- test dial
          SectionTitle(l.debugTestDial),
          const _TestDialField(),

          // ------------------------------------------------------------- time
          SectionTitle(l.debugTime),
          _Pad(Text(clockText, textDirection: TextDirection.ltr)),
          _Buttons([
            (
              l.debugPlus5m,
              () => world.advanceClock(const Duration(minutes: 5)),
            ),
            (
              l.debugPlus15m,
              () => world.advanceClock(const Duration(minutes: 15)),
            ),
            (l.debugPlus1h, () => world.advanceClock(const Duration(hours: 1))),
            (l.debugPlus1d, () => world.advanceClock(const Duration(days: 1))),
            (
              l.debugPlus30d,
              () => world.advanceClock(const Duration(days: 30)),
            ),
            (l.debugResetTime, () => world.advanceClock(-world.clockOffset)),
          ]),

          // --------------------------------------------------------- matching
          SectionTitle(l.debugMatching),
          _Buttons([
            (
              l.debugSimulateMatch,
              () {
                ref.read(debugForceNoMatchProvider.notifier).set(false);
                final ranked = ref
                    .read(matchingFacadeProvider)
                    .rank(
                      requireAvailable: false,
                      excludeIds: session.skippedIds,
                    )
                    .ranked;
                if (ranked.isEmpty) return;
                world.setAvailable(ranked.first.input.person.id, 30);
                Navigator.of(context).pop();
              },
            ),
            (l.debugEveryoneUnavailable, world.makeEveryoneUnavailable),
          ]),
          SwitchListTile(
            title: Text(l.debugForceNoMatch),
            value: forceNoMatch,
            onChanged: (v) =>
                ref.read(debugForceNoMatchProvider.notifier).set(v),
          ),
          ListTile(
            leading: const Icon(Icons.insights_rounded),
            title: Text(l.debugInspector),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MatchingInspector(),
              ),
            ),
          ),

          // ---------------------------------------------------------- answers
          SectionTitle(l.debugAnswers),
          _Pad(
            SegmentedButton<ForcedAnswer>(
              segments: [
                ButtonSegment(
                  value: ForcedAnswer.auto,
                  label: Text(l.debugAnswerAuto),
                ),
                ButtonSegment(
                  value: ForcedAnswer.accept,
                  label: Text(l.debugAnswerAccept),
                ),
                ButtonSegment(
                  value: ForcedAnswer.decline,
                  label: Text(l.debugAnswerDecline),
                ),
                ButtonSegment(
                  value: ForcedAnswer.noAnswer,
                  label: Text(l.debugAnswerNone),
                ),
              ],
              selected: {world.forcedAnswer},
              onSelectionChanged: (s) {
                world.forcedAnswer = s.first;
                world.notify();
              },
            ),
          ),

          // ------------------------------------------------------- invitation
          SectionTitle(l.debugInvitation),
          _Buttons([
            (
              l.debugSimulateInvitation,
              () {
                final invitations = ref.read(
                  invitationServiceProvider,
                ) as FakeInvitationService;
                final candidates = ref
                    .read(matchingFacadeProvider)
                    .rank(requireAvailable: false)
                    .ranked;
                if (candidates.isEmpty) return;
                final from =
                    candidates[Random().nextInt(min(4, candidates.length))]
                        .input
                        .person;
                final delivered = invitations.simulateIncoming(from.id, 25);
                if (delivered) {
                  Navigator.of(context).pop();
                } else {
                  toast(l.debugInvitationMuted);
                }
              },
            ),
          ]),

          // ------------------------------------------------------ who is free
          SectionTitle(l.debugWhoIsFree),
          for (final p in world.others.values) _AvailabilityRow(person: p),

          // -------------------------------------------------------- analytics
          SectionTitle(l.debugAnalytics),
          _AnalyticsSummary(),

          const SizedBox(height: 16),
          _Pad(
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(l.debugReset),
              onPressed: () {
                final me = world.me;
                final prefs = world.prefs;
                world.reset();
                // Keep my own profile & settings so onboarding isn't repeated.
                world.me = me;
                world.prefs = prefs;
                world.notify();
                ref.invalidate(sessionProvider);
                toast(l.debugResetDone);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TestDialField extends ConsumerStatefulWidget {
  const _TestDialField();

  @override
  ConsumerState<_TestDialField> createState() => _TestDialFieldState();
}

class _TestDialFieldState extends ConsumerState<_TestDialField> {
  late final _c = TextEditingController(
    text: ref.read(profileServiceProvider).prefs.testDialNumber ?? '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = ref.read(profileServiceProvider);
    return _Pad(
      TextField(
        controller: _c,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: l.debugTestDialLabel,
          helperText: l.debugTestDialHelp,
          helperMaxLines: 3,
        ),
        onChanged: (v) => profile.updatePrefs(
          v.trim().isEmpty
              ? profile.prefs.copyWith(clearTestDialNumber: true)
              : profile.prefs.copyWith(testDialNumber: v.trim()),
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    child: child,
  );
}

class _Buttons extends StatelessWidget {
  const _Buttons(this.items);
  final List<(String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, onTap) in items)
            FilledButton.tonal(onPressed: onTap, child: Text(label)),
        ],
      ),
    );
  }
}

class _AvailabilityRow extends ConsumerWidget {
  const _AvailabilityRow({required this.person});
  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final now = ref.watch(nowProvider);
    final world = ref.watch(fakeWorldProvider);
    final a = world.availability[person.id];
    final active = a != null && a.isActiveAt(now);
    final current = active ? a.minutesLeftAt(now) : null;
    const options = [null, 15, 30, 60];
    final selected = options.contains(current) ? current : (active ? -1 : null);

    return ListTile(
      dense: true,
      leading: PersonAvatar(person: person, size: 36),
      title: Text(person.name),
      subtitle: Text(
        active
            ? '${modeLabel(l, a.mode)} · ${l.timeLeftMinutes(current!)}'
            : l.debugNotAvailable,
      ),
      trailing: DropdownButton<int?>(
        value: selected,
        underline: const SizedBox.shrink(),
        items: [
          for (final m in options)
            DropdownMenuItem(
              value: m,
              child: Text(m == null ? l.debugNotAvailable : l.minutesShort(m)),
            ),
          if (selected == -1)
            DropdownMenuItem(value: -1, child: Text(l.minutesShort(current!))),
        ],
        onChanged: (m) {
          if (m == -1) return;
          world.setAvailable(
            person.id,
            m,
            mode: a?.mode ?? AvailabilityMode.free,
          );
        },
      ),
    );
  }
}

class _AnalyticsSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(nowProvider);
    final events = ref.watch(analyticsServiceProvider).events;
    if (events.isEmpty) return _Pad(Text(l.debugAnalyticsEmpty));
    final counts = <String, int>{};
    for (final e in events) {
      counts[e.name] = (counts[e.name] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in counts.entries)
              Text(
                '${e.key}: ${e.value}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
          ],
        ),
      ),
    );
  }
}
