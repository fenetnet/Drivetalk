import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'real_common.dart';

/// "Yoni is free now — want to talk?" (coral; dark while driving).
class RealOfferScreen extends ConsumerWidget {
  const RealOfferScreen({super.key, required this.offer, required this.dark});
  final RealOffer offer;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final now = ref.watch(realNowProvider);
    final other = s.snapshot!.friend(offer.otherId(s.myId!))!;
    final theirs = s.snapshot!.availability[other.id];
    final g = genderKey(other.gender);
    final style = dark ? MomentStyle.dark : MomentStyle.coral;
    final when = theirs != null && theirs.isActiveAt(now)
        ? '${modeLabel(l, theirs.mode)} · '
              '${l.timeLeftMinutes(theirs.minutesLeftAt(now))}'
        : null;

    return MomentLayout(
      style: style,
      header: when == null
          ? null
          : MomentChip(
              text: when,
              style: style,
              icon: modeIcon(theirs!.mode),
              dot: dark ? AppColors.sage : null,
            ),
      footer: dark ? l.driverSafety : l.realOfferNote,
      top: Column(
        children: [
          HeroAvatar(
            person: other.toPerson(),
            size: dark ? 150 : 168,
            ring: dark ? AppColors.driverRing : Colors.white,
          ),
          const SizedBox(height: 32),
          MomentText(
            dark ? other.name : l.realOfferName(other.name, g),
            size: dark ? 44 : 38,
            style: style,
          ),
          const SizedBox(height: 10),
          MomentText(
            dark ? l.realOfferAskShort(g) : l.realOfferAsk,
            size: 22,
            style: style,
            soft: true,
          ),
        ],
      ),
      actions: [
        PrimaryPill(
          label: dark ? l.yes : l.realTalkNow,
          icon: Icons.call_rounded,
          style: style,
          height: dark ? 120 : 76,
          onTap: s.busy ? null : () => c.respond(offer, accept: true),
        ),
        SecondaryPill(
          label: l.realNotNow,
          style: style,
          height: dark ? 88 : 60,
          onTap: () => c.respond(offer, accept: false),
        ),
        // Not while driving: two big buttons only.
        if (!dark)
          TextButton(
            onPressed: s.busy ? null : () => c.respondLater(offer),
            child: Text(
              l.realLaterButton,
              style: TextStyle(
                color: style == MomentStyle.coral ? Colors.white : null,
                fontSize: 16,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// I said yes; waiting for the other side.
class RealWaitingScreen extends ConsumerWidget {
  const RealWaitingScreen({super.key, required this.offer, required this.dark});
  final RealOffer offer;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final other = s.snapshot!.friend(offer.otherId(s.myId!))!;
    final style = dark ? MomentStyle.dark : MomentStyle.coral;
    return MomentLayout(
      style: style,
      footer: dark ? l.driverSafety : null,
      top: Column(
        children: [
          PulsingCircle(
            size: 184,
            color: Colors.white.withValues(alpha: 0.35),
            child: HeroAvatar(person: other.toPerson(), size: 168),
          ),
          const SizedBox(height: 32),
          MomentText(l.realWaitingTitle(other.name), size: 34, style: style),
          const SizedBox(height: 10),
          MomentText(
            l.realWaitingBody(other.name, genderKey(other.gender)),
            size: 18,
            style: style,
            soft: true,
          ),
        ],
      ),
      actions: [
        SecondaryPill(
          label: l.realStopWaiting,
          style: style,
          height: dark ? 88 : 60,
          onTap: () => c.cancelWaiting(offer),
        ),
      ],
    );
  }
}

/// Both said yes: countdown → phone call, or "they'll call you", or the
/// simulated in-app call. Green.
class RealCallScreen extends ConsumerWidget {
  const RealCallScreen({super.key, required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final call = s.call;
    final me = s.snapshot?.me;
    if (call == null) return const SizedBox.shrink();
    final person = call.other.toPerson();
    final g = genderKey(call.other.gender);
    final style = dark ? MomentStyle.dark : MomentStyle.green;

    // Me + them, overlapping.
    Widget pair() => SizedBox(
      width: 232,
      height: 128,
      child: Stack(
        children: [
          if (me != null)
            PositionedDirectional(
              start: 0,
              child: HeroAvatar(person: me.toPerson(), size: 128),
            ),
          PositionedDirectional(
            end: 0,
            child: HeroAvatar(person: person, size: 128),
          ),
        ],
      ),
    );

    Widget header(String title, {String? body, Widget? extra}) => Column(
      children: [
        MomentText(title, size: 28, style: style),
        if (body != null) ...[
          const SizedBox(height: 8),
          MomentText(body, size: 16, style: style, soft: true),
        ],
        const SizedBox(height: 48),
        pair(),
        ?extra,
      ],
    );

    final done = PrimaryPill(
      label: l.callWeAreDone,
      icon: Icons.call_end_rounded,
      style: style,
      height: dark ? 96 : 76,
      onTap: c.finishCall,
    );

    // Quick connect: the 5 seconds to cancel, counted on screen (the server
    // has the final word; this is only what the person sees).
    final quickLeft = call.quick
        ? 5 - ref.watch(realNowProvider).difference(call.startedAt).inSeconds
        : 0;

    return switch (s.callStage) {
      CallStage.connecting => MomentLayout(
        style: style,
        top: header(
          call.quick
              ? l.realQuickConnecting(call.other.name)
              : l.realCallingNow(call.other.name),
          body: !call.quick
              ? null
              : quickLeft > 0
              ? l.realQuickSeconds(quickLeft)
              : l.realQuickConnectingBody,
        ),
        actions: [
          if (call.quick)
            SecondaryPill(
              label: l.cancel,
              style: style,
              height: dark ? 120 : 76,
              onTap: c.cancelCall,
            ),
        ],
      ),
      CallStage.dialed => MomentLayout(
        style: style,
        top: header(l.realCallingNow(call.other.name), body: l.realDialedBody),
        actions: [done],
      ),
      CallStage.waitingForTheirCall => MomentLayout(
        style: style,
        top: header(
          l.realTheyCallTitle(call.other.name, g),
          body: l.realTheyCallBody,
        ),
        actions: [
          done,
          TextButton(
            onPressed: c.finishCall,
            child: Text(
              l.realTheyDidNotCall,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      // No phone call is possible: say so plainly (no fake call screen).
      _ => MomentLayout(
        style: style,
        top: header(
          call.dialFailed ? l.realDialFailedTitle : l.realNoNumbersTitle,
          body: call.dialFailed
              ? l.realDialFailedBody(call.other.name)
              : l.realNoNumbersBody,
        ),
        actions: [
          PrimaryPill(
            label: l.gotIt,
            style: style,
            height: dark ? 96 : 76,
            // Dialed by hand: still ask how it went.
            onTap: call.dialFailed ? c.finishCall : c.skipFeedback,
          ),
        ],
      ),
    };
  }
}

/// One question after the call. Not shown while driving (the root waits).
class RealFeedbackScreen extends ConsumerWidget {
  const RealFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final call = s.call;
    return MomentLayout(
      header: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(onPressed: c.skipFeedback, child: Text(l.skip)),
      ),
      top: Column(
        children: [
          if (call != null) HeroAvatar(person: call.other.toPerson()),
          const SizedBox(height: 28),
          MomentText(l.outcomeQuestion, size: 30),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: _RatingTile(
                label: l.outcomeGood,
                icon: Icons.sentiment_very_satisfied_rounded,
                onTap: () => c.sendOutcome(CallOutcome.good),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RatingTile(
                label: l.outcomeNotSoon,
                icon: Icons.snooze_rounded,
                onTap: () => c.sendOutcome(CallOutcome.notSoon),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => c.sendOutcome(CallOutcome.noTalk),
          child: Text(l.outcomeNoTalk),
        ),
      ],
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      shadowColor: const Color(0x221565C0),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, size: 40, color: AppColors.terracotta),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Netanel invited you" → accept.
class RealInviteScreen extends ConsumerWidget {
  const RealInviteScreen({super.key, required this.invite});
  final PendingInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final busy = ref.watch(realProvider.select((s) => s.busy));
    final info = invite.info;

    if (info == null) {
      return MomentLayout(
        top: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            MomentText(l.realInviteLoading, size: 20, soft: true),
          ],
        ),
        actions: [
          TextButton(onPressed: c.dismissInvite, child: Text(l.cancel)),
        ],
      );
    }
    final name = info.inviterName ?? '';
    final g = genderKey(info.inviterGender ?? Gender.unspecified);
    final person = RealProfile(
      id: name,
      name: name.isEmpty ? '?' : name,
      gender: info.inviterGender ?? Gender.unspecified,
    ).toPerson();

    return switch (info.status) {
      InviteStatus.valid => MomentLayout(
        top: Column(
          children: [
            HeroAvatar(person: person),
            const SizedBox(height: 28),
            MomentText(l.realInviteTitle(name, g), size: 34),
            const SizedBox(height: 10),
            MomentText(l.realInviteBody, size: 18, soft: true),
          ],
        ),
        actions: [
          PrimaryPill(
            label: l.realInviteAccept,
            icon: Icons.check_rounded,
            onTap: busy ? null : c.acceptInvite,
          ),
          SecondaryPill(label: l.realNotNow, onTap: c.dismissInvite),
        ],
      ),
      InviteStatus.alreadyConnected => MomentLayout(
        top: Column(
          children: [
            HeroAvatar(person: person),
            const SizedBox(height: 28),
            MomentText(l.realInviteAlready(name), size: 26),
          ],
        ),
        actions: [PrimaryPill(label: l.confirm, onTap: c.dismissInvite)],
      ),
      _ => MomentLayout(
        top: Column(
          children: [
            const Icon(
              Icons.link_off_rounded,
              size: 72,
              color: AppColors.inkSoft,
            ),
            const SizedBox(height: 20),
            MomentText(
              inviteProblemText(l, switch (info.status) {
                InviteStatus.used => 'used',
                InviteStatus.expired => 'expired',
                InviteStatus.own => 'own',
                _ => 'notFound',
              }),
              size: 22,
            ),
          ],
        ),
        actions: [PrimaryPill(label: l.confirm, onTap: c.dismissInvite)],
      ),
    };
  }
}

/// Small avatar for lists in real mode.
Widget realPersonAvatar(RealProfile p, {double size = 44}) =>
    PersonAvatar(person: p.toPerson(), size: size);
