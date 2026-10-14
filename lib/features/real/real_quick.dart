import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import 'real_common.dart';

/// Quick connect per friend (D-112): one switch, with a short explanation
/// before turning it on.
class QuickSwitch extends ConsumerWidget {
  const QuickSwitch({super.key, required this.friend});
  final RealProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(realProvider);
    final snap = s.snapshot;
    final mine = snap?.quickMine.contains(friend.id) ?? false;
    final both = snap?.quickBoth(friend.id) ?? false;
    return SwitchListTile(
      secondary: const Icon(Icons.bolt_rounded, color: AppColors.terracotta),
      title: Text(
        l.quickTitle,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        both
            ? l.quickBothBody
            : mine
            ? l.quickWaitingBody(friend.name)
            : l.quickOffBody,
      ),
      value: mine,
      onChanged: s.busy
          ? null
          : (on) async {
              if (on && !await confirmQuick(context, friend)) return;
              await ref.read(realProvider.notifier).setQuick(friend, on);
            },
    );
  }
}

/// "Quick connect with X?" — what it does, before turning it on.
Future<bool> confirmQuick(BuildContext context, RealProfile friend) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      icon: const Icon(Icons.bolt_rounded, color: AppColors.terracotta),
      title: Text(l.quickConfirmTitle(friend.name)),
      content: Text(l.quickConfirmBody(friend.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(l.quickTurnOn),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Home: "X wants quick connect with you" — once, only in the app.
class QuickAskCard extends ConsumerWidget {
  const QuickAskCard({super.key, required this.friend});
  final RealProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = ref.read(realProvider.notifier);
    final busy = ref.watch(realProvider.select((s) => s.busy));
    return Card(
      color: AppColors.blush,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RealAvatar(person: friend.toPerson(), size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.quickAskTitle(friend.name),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.bolt_rounded, color: AppColors.terracotta),
              ],
            ),
            const SizedBox(height: 6),
            Text(l.quickAskBody),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => c.setQuick(friend, true),
                    child: Text(l.quickAskYes),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: busy ? null : () => c.dismissQuickAsk(friend),
                  child: Text(l.notNowShort),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Home, once: "New: quick connect" → pick friends right there.
class QuickIntroCard extends ConsumerWidget {
  const QuickIntroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = ref.read(realProvider.notifier);
    return Card(
      color: AppColors.blush,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.terracotta),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.quickIntroTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(l.quickIntroBody),
                    ],
                  ),
                ),
              ],
            ),
            // Wraps on small screens with large text.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: c.dismissQuickIntro,
                  child: Text(l.notNowShort),
                ),
                FilledButton(
                  onPressed: () => showQuickPicker(context, ref),
                  child: Text(l.quickIntroPick),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// All friends, each with the quick-connect switch.
Future<void> showQuickPicker(BuildContext context, WidgetRef ref) async {
  ref.read(realProvider.notifier).dismissQuickIntro();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final l = AppLocalizations.of(context);
          final friends =
              ref.watch(realProvider.select((s) => s.snapshot?.friends)) ??
              const <RealProfile>[];
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l.quickPickTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                for (final f in friends)
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      RealAvatar(person: f.toPerson(), size: 40),
                      Expanded(child: _QuickRow(friend: f)),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _QuickRow extends ConsumerWidget {
  const _QuickRow({required this.friend});
  final RealProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(realProvider);
    final on = s.snapshot?.quickMine.contains(friend.id) ?? false;
    return SwitchListTile(
      title: Text(friend.name),
      value: on,
      onChanged: s.busy
          ? null
          : (v) async {
              if (v && !await confirmQuick(context, friend)) return;
              await ref.read(realProvider.notifier).setQuick(friend, v);
            },
    );
  }
}
