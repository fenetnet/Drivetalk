import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/dev_tools.dart';
import '../../app/theme.dart';
import '../../real/backend_config.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import 'real_common.dart';
import 'real_people.dart';

/// "Test with a friend": is everything working? Plus "copy test info"
/// (never contains keys, tokens, phone numbers or full ids).
class RealTestScreen extends ConsumerWidget {
  const RealTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final now = ref.watch(realNowProvider);
    final snap = s.snapshot;
    final mine = myActiveAvailability(s, now);
    final free = freeFriends(s, now);
    final offers = [...?snap?.offers]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final last = offers.firstOrNull;

    (String, bool?) live() => switch (s.live) {
      LiveStatus.connected => (l.realOk, true),
      LiveStatus.connecting => (l.realStarting, null),
      LiveStatus.error => (l.realLiveError, false),
      LiveStatus.disconnected => (l.realNotConnected, false),
    };

    final rows = <(IconData, String, String, bool?)>[
      (
        Icons.cloud_rounded,
        l.realStatusServer,
        BackendConfig.backendHost,
        s.lastError == 'offline' || s.lastError == 'schema_missing'
            ? false
            : snap != null,
      ),
      (
        Icons.person_rounded,
        l.realStatusAccount,
        snap == null ? '—' : snap.me.name,
        snap != null,
      ),
      (Icons.bolt_rounded, l.realStatusLive, live().$1, live().$2),
      (
        Icons.people_alt_rounded,
        l.realStatusFriends,
        '${snap?.friends.length ?? 0}',
        (snap?.friends.isNotEmpty ?? false) ? true : null,
      ),
      (
        Icons.record_voice_over_rounded,
        l.realStatusMe,
        mine == null
            ? l.realMeNotAvailable
            : '${modeLabel(l, mine.mode)} · '
                  '${l.timeLeftMinutes(mine.minutesLeftAt(now))}',
        mine == null ? null : true,
      ),
      (
        Icons.group_rounded,
        l.realStatusFreeFriends,
        free.isEmpty ? l.realNone : free.map((f) => f.$1.name).join(', '),
        free.isEmpty ? null : true,
      ),
      (
        Icons.handshake_rounded,
        l.realStatusLastOffer,
        last == null
            ? l.realNone
            : '${snap!.friend(last.otherId(snap.me.id))?.name ?? '?'} · '
                  '${offerStatusText(l, last.status)}',
        last == null ? null : last.status == OfferStatus.accepted,
      ),
      (
        Icons.phone_rounded,
        l.realStatusPhone,
        s.myPhone == null ? l.realNotShared : l.realShared,
        null,
      ),
      (
        Icons.directions_car_rounded,
        l.realStatusAutoDriving,
        !s.driving.supported
            ? l.realAutoDrivingUnsupported
            : [
                s.driving.enabled ? l.realAutoOn : l.realAutoOff,
                if (s.driving.inVehicle) l.realInVehicleNow,
              ].join(' · '),
        s.driving.enabled ? true : null,
      ),
      (
        Icons.info_outline_rounded,
        l.realStatusVersion,
        ref.watch(appVersionProvider),
        null,
      ),
      (
        Icons.error_outline_rounded,
        l.realStatusLastError,
        s.lastError == null ? l.realNone : realErrorText(l, s.lastError!),
        s.lastError == null ? true : false,
      ),
    ];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: c.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(
              l.realWelcomeTitle,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              l.realTestIntro,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  l.realTestSteps,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final (icon, label, value, ok) in rows)
                    ListTile(
                      dense: true,
                      leading: Icon(icon, color: AppColors.inkSoft),
                      title: Text(label),
                      subtitle: Text(value),
                      trailing: switch (ok) {
                        true => const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.sageDark,
                        ),
                        false => const Icon(
                          Icons.error_rounded,
                          color: AppColors.danger,
                        ),
                        null => const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Colors.black26,
                        ),
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: c.diagnostics()));
                messengerKey.currentState?.showSnackBar(
                  SnackBar(
                    content: Text(l.realCopied),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(l.realCopyDiagnostics),
            ),
            if (kDevTools && s.driving.enabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => c.simulateTrip(enter: true),
                      child: Text(l.realSimEnter),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => c.simulateTrip(enter: false),
                      child: Text(l.realSimExit),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: c.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l.realRefresh),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: s.busy ? null : () => shareInvite(context, ref),
                    icon: const Icon(Icons.share_rounded),
                    label: Text(l.realInviteFriend),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
