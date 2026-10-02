import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_controller.dart';
import '../../app/theme.dart';
import '../../services/invitation_service.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// "Dana is free for ~30 minutes. Want to talk?" — talk now / not now / mute.
class InvitationScreen extends ConsumerWidget {
  const InvitationScreen({super.key, required this.driverMode});
  final bool driverMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final inv = ref.watch(sessionProvider).invitation;
    final graph = ref.watch(socialGraphServiceProvider);
    final hours = ref.watch(matchingConfigProvider).snooze.beaconMuteHours;
    final c = ref.read(sessionProvider.notifier);
    final person = inv == null ? null : graph.personById(inv.fromPersonId);
    if (inv == null || person == null) return const SizedBox.shrink();
    final fg = driverMode ? Colors.white : AppColors.ink;
    final buttonHeight = driverMode ? 96.0 : 60.0;

    return Scaffold(
      backgroundColor: driverMode ? AppColors.driverBg : AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(child: PersonAvatar(person: person, size: 120)),
              const SizedBox(height: 20),
              Text(
                l.invitationText(
                  person.name,
                  genderKey(person.gender),
                  inv.minutes,
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: driverMode ? 28 : 22,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (!driverMode) ...[
                const SizedBox(height: 8),
                Text(
                  relationshipLine(
                    l,
                    connection: graph.connectionWith(person.id),
                    mutualFriends: graph.mutualFriendsWith(person.id),
                    sharedGroups: graph.sharedGroupsWith(person.id),
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 16,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: buttonHeight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sageDark,
                    textStyle: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: driverMode ? 28 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () =>
                      c.respondToInvitation(InvitationResponse.talkNow),
                  icon: const Icon(Icons.call_rounded),
                  label: Text(l.talkNow),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: buttonHeight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: fg,
                    side: BorderSide(color: fg.withValues(alpha: 0.4)),
                    textStyle: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: driverMode ? 24 : 16,
                    ),
                  ),
                  onPressed: () =>
                      c.respondToInvitation(InvitationResponse.notNow),
                  child: Text(l.invitationNotNow),
                ),
              ),
              if (!driverMode) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      c.respondToInvitation(InvitationResponse.mute),
                  child: Text(l.invitationMute(hours)),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
