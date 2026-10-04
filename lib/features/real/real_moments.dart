import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'real_common.dart';

/// "Yoni is free now. Want to talk?" — talk now / not now.
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
    return MomentLayout(
      dark: dark,
      footer: dark ? l.driverSafety : l.realOfferNote,
      top: Column(
        children: [
          PersonAvatar(person: other.toPerson(), size: 120),
          const SizedBox(height: 20),
          MomentText(
            l.realOfferTitle(other.name, genderKey(other.gender)),
            size: 30,
            dark: dark,
          ),
          if (theirs != null && theirs.isActiveAt(now)) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  modeIcon(theirs.mode),
                  color: dark ? Colors.white70 : AppColors.inkSoft,
                ),
                const SizedBox(width: 6),
                MomentText(
                  '${modeLabel(l, theirs.mode)} · '
                  '${l.timeLeftMinutes(theirs.minutesLeftAt(now))}',
                  size: 18,
                  dark: dark,
                  soft: true,
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        BigActionButton(
          label: l.realTalkNow,
          icon: Icons.call_rounded,
          height: 110,
          onTap: s.busy ? null : () => c.respond(offer, accept: true),
        ),
        BigActionButton(
          label: l.realNotNow,
          icon: Icons.close_rounded,
          color: dark ? AppColors.driverCard : AppColors.inkSoft,
          onTap: () => c.respond(offer, accept: false),
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
    return MomentLayout(
      dark: dark,
      footer: dark ? l.driverSafety : null,
      top: Column(
        children: [
          PulsingCircle(
            size: 132,
            color: AppColors.sage,
            child: PersonAvatar(person: other.toPerson(), size: 120),
          ),
          const SizedBox(height: 22),
          MomentText(l.realWaitingTitle(other.name), size: 30, dark: dark),
          const SizedBox(height: 8),
          MomentText(
            l.realWaitingBody(other.name, genderKey(other.gender)),
            size: 18,
            dark: dark,
            soft: true,
          ),
        ],
      ),
      actions: [
        BigActionButton(
          label: l.realStopWaiting,
          icon: Icons.close_rounded,
          color: dark ? AppColors.driverCard : AppColors.inkSoft,
          onTap: () => c.cancelWaiting(offer),
        ),
      ],
    );
  }
}

/// Both said yes: countdown → phone call, or "they'll call you", or the
/// simulated in-app call.
class RealCallScreen extends ConsumerWidget {
  const RealCallScreen({super.key, required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final c = ref.read(realProvider.notifier);
    final call = s.call;
    if (call == null) return const SizedBox.shrink();
    final person = call.other.toPerson();
    final g = genderKey(call.other.gender);

    Widget header(String title, {String? body, bool pulse = false}) => Column(
      children: [
        if (pulse)
          PulsingCircle(
            size: 132,
            color: AppColors.sage,
            child: PersonAvatar(person: person, size: 120),
          )
        else
          PersonAvatar(person: person, size: 120),
        const SizedBox(height: 22),
        MomentText(title, size: 28, dark: dark),
        if (body != null) ...[
          const SizedBox(height: 8),
          MomentText(body, size: 17, dark: dark, soft: true),
        ],
      ],
    );

    final done = BigActionButton(
      label: l.callWeAreDone,
      icon: Icons.call_end_rounded,
      color: AppColors.danger,
      onTap: c.finishCall,
    );

    return switch (s.callStage) {
      CallStage.connecting => MomentLayout(
        dark: dark,
        top: header(
          call.quick && s.dialCountdown > 0
              ? l.realQuickIn(call.other.name, s.dialCountdown)
              : call.role == CallRole.iCall && s.dialCountdown > 0
              ? l.realCallingIn(call.other.name, s.dialCountdown)
              : l.realConnecting,
          body: call.quick ? l.realQuickWhy : l.realBothSaidYes,
          pulse: true,
        ),
        actions: [
          if (call.role == CallRole.iCall)
            BigActionButton(
              label: l.realCallNow,
              icon: Icons.call_rounded,
              height: 110,
              onTap: c.dialNow,
            ),
          BigActionButton(
            label: l.cancel,
            icon: Icons.close_rounded,
            color: dark ? AppColors.driverCard : AppColors.inkSoft,
            onTap: c.cancelCall,
          ),
        ],
      ),
      CallStage.dialed => MomentLayout(
        dark: dark,
        top: header(l.realDialedTitle, body: l.realDialedBody),
        actions: [done],
      ),
      CallStage.waitingForTheirCall => MomentLayout(
        dark: dark,
        top: header(
          l.realTheyCallTitle(call.other.name, g),
          body: l.realTheyCallBody,
          pulse: true,
        ),
        actions: [
          done,
          TextButton(
            onPressed: c.finishCall,
            child: Text(
              l.realTheyDidNotCall,
              style: TextStyle(color: dark ? Colors.white70 : null),
            ),
          ),
        ],
      ),
      _ => MomentLayout(
        dark: dark,
        top: Column(
          children: [
            header(l.realInAppTitle(call.other.name), body: l.realInAppBody),
            const SizedBox(height: 16),
            _CallTimer(since: call.startedAt, dark: dark),
          ],
        ),
        actions: [done],
        footer: l.callAudioOnly,
      ),
    };
  }
}

class _CallTimer extends ConsumerWidget {
  const _CallTimer({required this.since, required this.dark});
  final DateTime since;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(realNowProvider);
    final d = now.difference(since);
    final secs = d.isNegative ? 0 : d.inSeconds;
    final text =
        '${(secs ~/ 60).toString().padLeft(2, '0')}:'
        '${(secs % 60).toString().padLeft(2, '0')}';
    return MomentText(text, size: 22, dark: dark, soft: true);
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
    final me = s.snapshot?.me;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: c.skipFeedback,
                  child: Text(l.skip),
                ),
              ),
              const Spacer(),
              if (call != null)
                Center(
                  child: PersonAvatar(person: call.other.toPerson(), size: 96),
                ),
              const SizedBox(height: 20),
              Text(
                l.feedbackQuestion(genderKey(me?.gender ?? Gender.unspecified)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 28),
              for (final (r, label, icon) in [
                (
                  FeedbackRating.veryGood,
                  l.feedbackVeryGood,
                  Icons.sentiment_very_satisfied_rounded,
                ),
                (
                  FeedbackRating.good,
                  l.feedbackGood,
                  Icons.sentiment_satisfied_rounded,
                ),
                (
                  FeedbackRating.notReally,
                  l.feedbackNotReally,
                  Icons.sentiment_neutral_rounded,
                ),
              ]) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: () => c.sendFeedback(talked: true, rating: r),
                  icon: Icon(icon, color: AppColors.terracotta),
                  label: Text(label, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 12),
              ],
              TextButton(
                onPressed: () => c.sendFeedback(talked: false),
                child: Text(l.feedbackDidNotTalk),
              ),
              const Spacer(flex: 2),
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
            MomentText(l.realInviteLoading, size: 20),
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
            PersonAvatar(person: person, size: 120),
            const SizedBox(height: 20),
            MomentText(l.realInviteTitle(name, g), size: 30),
            const SizedBox(height: 10),
            MomentText(l.realInviteBody, size: 18, soft: true),
          ],
        ),
        actions: [
          BigActionButton(
            label: l.realInviteAccept,
            icon: Icons.check_rounded,
            onTap: busy ? null : c.acceptInvite,
          ),
          TextButton(onPressed: c.dismissInvite, child: Text(l.realNotNow)),
        ],
      ),
      InviteStatus.alreadyConnected => MomentLayout(
        top: Column(
          children: [
            PersonAvatar(person: person, size: 120),
            const SizedBox(height: 20),
            MomentText(l.realInviteAlready(name), size: 24),
          ],
        ),
        actions: [
          BigActionButton(
            label: l.confirm,
            icon: Icons.check_rounded,
            onTap: c.dismissInvite,
          ),
        ],
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
        actions: [
          BigActionButton(
            label: l.confirm,
            icon: Icons.check_rounded,
            color: AppColors.inkSoft,
            onTap: c.dismissInvite,
          ),
        ],
      ),
    };
  }
}
