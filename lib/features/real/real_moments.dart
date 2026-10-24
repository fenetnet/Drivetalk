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
    // (A friend who just left the list: nothing to show — never a crash.)
    final other = s.snapshot?.friend(offer.otherId(s.myId ?? ''));
    if (other == null) return const SizedBox.shrink();
    final theirs = s.snapshot!.availability[other.id];
    final g = genderKey(other.gender);
    // They tapped me: say so ("X wants to talk with you").
    final direct = offer.askedBy(other.id);
    final style = dark ? MomentStyle.dark : MomentStyle.coral;
    // Only what we know: how long both are free, when they last talked.
    final shared = offer.sharedUntil?.difference(now).inMinutes;
    // The chip says how they're free; their minutes only when there's no
    // "both free for…" line below (never two different numbers).
    final when = theirs != null && theirs.isActiveAt(now)
        ? theirs.auto || (shared != null && shared > 0)
              ? modeLabel(l, theirs.mode)
              : '${modeLabel(l, theirs.mode)} · '
                    '${l.timeLeftMinutes(theirs.minutesLeftAt(now))}'
        : null;
    final last = offer.lastTalk;
    final days = last == null
        ? null
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).difference(DateTime(last.year, last.month, last.day)).inDays;
    final facts = [
      if (shared != null && shared > 0) l.offerShared(shared),
      if (days == null)
        l.offerFirstTalk
      else if (days <= 0)
        l.offerLastTalkToday
      else if (days < 14)
        l.offerLastTalkDays(days)
      else
        l.offerLastTalkDate('${last!.day}/${last.month}'),
    ].join(' · ');

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
            dark
                ? other.name
                : direct
                ? l.directTitle(other.name)
                : l.realOfferName(other.name, g),
            size: dark ? 44 : 38,
            style: style,
          ),
          const SizedBox(height: 10),
          MomentText(
            dark
                ? direct
                      ? l.directAskShort
                      : l.realOfferAskShort(g)
                : direct
                ? l.directAsk
                : l.realOfferAsk,
            size: 22,
            style: style,
            soft: true,
          ),
          // Not while driving: as little text as possible.
          if (!dark) ...[
            const SizedBox(height: 12),
            MomentText(facts, size: 16, style: style, soft: true),
          ],
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
    final other = s.snapshot?.friend(offer.otherId(s.myId ?? ''));
    if (other == null) return const SizedBox.shrink();
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
          // Each step, so the wait doesn't feel lost (D-129).
          const SizedBox(height: 14),
          MomentText(
            (s.snapshot?.offers.where((o) => o.id == offer.id).firstOrNull ??
                        offer)
                    .shownTo(other.id)
                ? l.waitingReached(other.name)
                : l.waitingSent(other.name),
            size: 18,
            style: style,
          ),
          // How long I still wait (then I stop waiting by myself).
          if (c.waitSecondsLeft(offer, ref.watch(realNowProvider))
              case final left? when left > 0) ...[
            const SizedBox(height: 14),
            MomentText(l.realWaitingLeft(left), size: 22, style: style),
          ],
        ],
      ),
      actions: [
        // One button. Someone else is free: it says so — stop waiting here
        // and pick them (D-104).
        SecondaryPill(
          label:
              !dark &&
                  freeFriends(
                    s,
                    ref.watch(realNowProvider),
                  ).any((f) => f.$1.id != other.id)
              ? l.waitOther
              : l.realStopWaiting,
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

    // Leave the call screen for the main one (a banner brings it back).
    final toMain = TextButton.icon(
      onPressed: () => c.hideCall(true),
      icon: const Icon(Icons.home_rounded, color: Colors.white),
      label: Text(
        l.callToMain,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
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
        header: toMain,
        top: header(l.realCallingNow(call.other.name), body: l.realDialedBody),
        actions: [done],
      ),
      CallStage.waitingForTheirCall => MomentLayout(
        style: style,
        header: toMain,
        top: header(
          l.realTheyCallTitle(call.other.name, g),
          body: l.realTheyCallBody,
        ),
        // Two clear buttons: the call came and ended / it never came.
        actions: [
          PrimaryPill(
            label: l.realCallEnded,
            icon: Icons.check_rounded,
            style: style,
            height: dark ? 96 : 76,
            onTap: c.finishCall,
          ),
          SecondaryPill(
            label: l.realTheyDidNotCall,
            style: style,
            height: dark ? 88 : 60,
            onTap: c.finishCall,
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
    final name = call?.other.name ?? '';
    Widget choice(String label, int days, {bool main = false}) => SizedBox(
      height: 60,
      child: main
          ? FilledButton(
              onPressed: () => c.afterCall(days),
              child: Text(label, style: const TextStyle(fontSize: 18)),
            )
          : OutlinedButton(
              onPressed: () => c.afterCall(days),
              child: Text(label, style: const TextStyle(fontSize: 18)),
            ),
    );
    return MomentLayout(
      // Skipping keeps the usual 3 quiet days.
      header: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(onPressed: c.skipFeedback, child: Text(l.skip)),
      ),
      top: Column(
        children: [
          if (call != null) HeroAvatar(person: call.other.toPerson()),
          const SizedBox(height: 20),
          MomentText(l.afterCallHope, size: 17, soft: true),
          const SizedBox(height: 8),
          MomentText(l.afterCallTitle(name), size: 28),
          const SizedBox(height: 8),
          MomentText(l.afterCallNote(name), size: 16, soft: true),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(child: choice(l.afterCallAny, 0)),
            const SizedBox(width: 10),
            Expanded(child: choice(l.afterCallTomorrow, 1)),
          ],
        ),
        Row(
          children: [
            Expanded(child: choice(l.afterCall3, 3, main: true)),
            const SizedBox(width: 10),
            Expanded(child: choice(l.afterCallWeek, 7)),
          ],
        ),
        TextButton(
          onPressed: () => c.afterCall(0, talked: false),
          child: Text(l.afterCallNoTalk),
        ),
        // Feedback or an insight: welcome, never asked for.
        TextButton.icon(
          onPressed: () => openFeedbackDialog(context, ref),
          icon: const Icon(Icons.edit_note_rounded),
          label: Text(l.afterCallWrite, textAlign: TextAlign.center),
        ),
      ],
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
