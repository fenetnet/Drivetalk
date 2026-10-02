import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import '../match/safety_actions.dart';
import 'real_common.dart';

/// Create an invitation and open the phone's share sheet (WhatsApp, SMS…).
/// Falls back to copying when sharing isn't available.
Future<void> shareInvite(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final text = await ref.read(realProvider.notifier).createInviteMessage();
  if (text == null) return;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: l.realInviteShareSubject),
      );
      return;
    } catch (_) {
      // Fall through to copying.
    }
  }
  await Clipboard.setData(ClipboardData(text: text));
  messengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(l.realInviteCopied),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// "I have an invitation code": paste a link, a code or the whole message.
Future<void> openInviteCodeSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CodeSheet(),
  );
}

class _CodeSheet extends ConsumerStatefulWidget {
  const _CodeSheet();

  @override
  ConsumerState<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends ConsumerState<_CodeSheet> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _open() {
    final token = parseInviteToken(_text.text);
    if (token == null) {
      setState(() => _error = context.l10n.realCodeInvalid);
      return;
    }
    // Close first: opening the invitation takes over the whole screen.
    Navigator.of(context).pop();
    ref.read(realProvider.notifier).openInvite(token);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.realHaveCode, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: l.realCodeHint,
              errorText: _error,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) _text.text = data!.text!;
                },
              ),
            ),
            onSubmitted: (_) => _open(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _open, child: Text(l.realOpen)),
        ],
      ),
    );
  }
}

/// My real friends, with who's free right now. Invite / enter a code.
class RealPeopleScreen extends ConsumerWidget {
  const RealPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final now = ref.watch(realNowProvider);
    final snap = s.snapshot;
    final friends = snap?.friends ?? const <RealProfile>[];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: ref.read(realProvider.notifier).refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(
              l.realTabPeople,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: s.busy ? null : () => shareInvite(context, ref),
                    icon: const Icon(Icons.share_rounded),
                    label: Text(l.realInviteFriend),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () => openInviteCodeSheet(context, ref),
                    icon: const Icon(Icons.vpn_key_rounded),
                    label: Text(l.realHaveCode),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l.realNoFriendsBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
            for (final f in friends)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: PersonAvatar(person: f.toPerson(), size: 44),
                  title: Text(
                    f.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: switch (snap!.availability[f.id]) {
                    final a? when a.isActiveAt(now) => Text(
                      '${modeLabel(l, a.mode)} · '
                      '${l.timeLeftMinutes(a.minutesLeftAt(now))}',
                      style: const TextStyle(color: AppColors.sageDark),
                    ),
                    _ => Text(l.realNotFree),
                  },
                  trailing: const Icon(Icons.more_vert_rounded),
                  onTap: () => _friendActions(context, ref, f),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _friendActions(
    BuildContext context,
    WidgetRef ref,
    RealProfile f,
  ) async {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    final person = f.toPerson();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonAvatar(person: person, size: 64),
            const SizedBox(height: 8),
            Text(f.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_remove_rounded),
              title: Text(l.unmatch),
              onTap: () => Navigator.pop(sheet, 'unmatch'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.danger),
              title: Text(l.block),
              onTap: () => Navigator.pop(sheet, 'block'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: Text(l.report),
              onTap: () => Navigator.pop(sheet, 'report'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'unmatch':
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            content: Text(l.personUnmatchConfirm(f.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(l.confirm),
              ),
            ],
          ),
        );
        if (ok ?? false) await c.unmatch(f);
      case 'block':
        await confirmBlock(context, ref, person, onBlock: () => c.block(f));
      case 'report':
        await showReportSheet(
          context,
          ref,
          person,
          onReport: (reason, alsoBlock) async {
            await c.report(f, reason);
            if (alsoBlock) await c.block(f);
          },
        );
    }
  }
}
