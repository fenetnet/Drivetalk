import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../real/backend_config.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import '../match/safety_actions.dart';
import 'real_circles.dart';
import 'real_common.dart';

/// Create an invitation and open the phone's share sheet (WhatsApp, SMS…).
/// Falls back to copying when sharing isn't available.
/// Normally just the download link: once the friend joins, people who have
/// each other's number connect by themselves. [withCode] adds a personal
/// code, for a friend who isn't saved in my contacts.
Future<void> shareInvite(
  BuildContext context,
  WidgetRef ref, {
  bool withCode = false,
}) async {
  final l = context.l10n;
  final text = withCode
      ? await ref.read(realProvider.notifier).createInviteMessage()
      : BackendConfig.store
      ? l.realInviteStore(BackendConfig.playUrl)
      : l.realInviteSimple(
          ref.read(apkUrlProvider),
          BackendConfig.downloadPageUrl,
        );
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
    bool isAsleep(RealProfile f) => (snap?.inactiveDays[f.id] ?? 0) >= 30;
    final active = [
      for (final f in friends)
        if (!isAsleep(f)) f,
    ];
    final asleep = [
      for (final f in friends)
        if (isAsleep(f)) f,
    ];
    Widget friendCard(RealProfile f) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: RealAvatar(
          person: f.toPerson(),
          size: 48,
          online:
              (snap!.availability[f.id]?.isActiveAt(now) ?? false) &&
              !(snap.availability[f.id]?.inCallAt(now) ?? false),
        ),
        title: Text(
          f.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            switch (snap.availability[f.id]) {
              final a? when a.isActiveAt(now) && a.inCallAt(now) => StatusLine(
                icon: Icons.call_rounded,
                text: l.inCall,
                color: AppColors.coralDeep,
                bold: true,
              ),
              final a? when a.isActiveAt(now) => StatusLine(
                icon: modeIcon(a.mode),
                text:
                    '${modeLabel(l, a.mode)} · '
                    '${l.timeLeftMinutes(a.minutesLeftAt(now))}',
                color: AppColors.sageDark,
              ),
              _ => Text(switch (snap.inactiveDays[f.id] ?? 0) {
                >= 30 => l.inactiveMonth,
                final d when d >= 7 => l.inactiveDays(d),
                _ => l.realNotFree,
              }),
            },
            RatingStars(rating: snap.ratingOf(f.id)),
          ],
        ),
        trailing: const Icon(Icons.more_vert_rounded),
        onTap: () => _friendActions(context, ref, f),
      ),
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: ref.read(realProvider.notifier).refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(
              l.realTabPeople,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => shareInvite(context, ref),
              icon: const Icon(Icons.share_rounded),
              label: Text(l.realInviteFriend),
            ),

            const SizedBox(height: 12),
            const _ContactsCard(),
            const SizedBox(height: 12),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l.realNoFriendsBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
            for (final f in active) friendCard(f),
            // Haven't opened the app for a month: out of the way, not gone.
            if (asleep.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.peopleAsleepTitle(asleep.length)),
                subtitle: Text(l.peopleAsleepBody),
                children: [for (final f in asleep) friendCard(f)],
              ),
            if (friends.isNotEmpty) const RealCirclesSection(),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => _openRemoved(context, ref),
                icon: const Icon(Icons.restore_rounded),
                label: Text(l.removedTitle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// People I removed, each with "bring back".
  Future<void> _openRemoved(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final c = ref.read(realProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: FutureBuilder<List<ContactMatch>?>(
          future: c.removedFriends(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final people = snap.data ?? const <ContactMatch>[];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.removedTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    people.isEmpty ? l.removedEmpty : l.removedBody,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 8),
                  for (final m in people)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline_rounded),
                      title: Text(m.name),
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          Navigator.pop(sheet);
                          await c.restoreFriend(m);
                        },
                        child: Text(l.removedRestore),
                      ),
                    ),
                ],
              ),
            );
          },
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
      // Tall enough for everything; scrolls on small screens so "report"
      // at the bottom is always reachable.
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(person: person, size: 64),
              const SizedBox(height: 8),
              Text(f.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              RatingPicker(friend: f, onDone: () => Navigator.pop(sheet)),
              const Divider(),
              FriendCirclesPicker(friend: f),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded),
                title: Text(l.unmatch),
                onTap: () => Navigator.pop(sheet, 'unmatch'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.block_rounded,
                  color: AppColors.danger,
                ),
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

class _ContactsCard extends ConsumerWidget {
  const _ContactsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final busy = ref.watch(realProvider.select((s) => s.busy));
    final c = ref.read(realProvider.notifier);
    // Searched before: just a small button, so the people come first.
    if (c.contactsSynced && ref.watch(realProvider).snapshot != null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: busy ? null : () => openContactPicker(context, ref),
          icon: const Icon(Icons.refresh_rounded, color: AppColors.sageDark),
          label: Text(
            l.realContactsAgain,
            style: const TextStyle(color: AppColors.sageDark),
          ),
        ),
      );
    }
    return Card(
      color: const Color(0xFFDCEBE3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.contacts_rounded, color: AppColors.sageDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.realContactsTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l.realContactsBody,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sageDark,
              ),
              onPressed: busy ? null : () => openContactPicker(context, ref),
              icon: const Icon(Icons.search_rounded),
              label: Text(l.realContactsButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// 0–5 as small stars (0 = "not offered").
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    if (rating == 0) {
      return Text(
        context.l10n.ratingNever,
        style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
      );
    }
    return Semantics(
      label: context.l10n.ratingLabel(rating),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 16,
              color: i <= rating ? AppColors.terracotta : AppColors.inkSoft,
            ),
        ],
      ),
    );
  }
}

/// "How much do I want to talk with them?" 0 (never offer) – 5 (first).
/// Only I see it.
class RatingPicker extends ConsumerWidget {
  const RatingPicker({super.key, required this.friend, this.onDone});
  final RealProfile friend;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(realProvider).snapshot?.ratingOf(friend.id) ?? 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.ratingTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var r = 0; r <= 5; r++)
                ChoiceChip(
                  label: Text('$r'),
                  selected: r == current,
                  onSelected: (_) async {
                    await ref.read(realProvider.notifier).setRating(friend, r);
                    onDone?.call();
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.ratingHelp,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Search my contacts, then pick who to add. Nobody is added otherwise,
/// and nobody is told who wasn't picked.
Future<void> openContactPicker(BuildContext context, WidgetRef ref) async {
  final c = ref.read(realProvider.notifier);
  await c.syncContacts();
  if (!context.mounted || c.contactMatches.isEmpty) return;
  c.markMatchesSeen();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ContactPickerSheet(),
  );
}

class _ContactPickerSheet extends ConsumerWidget {
  const _ContactPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(realProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.contactsPickTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l.contactsPickBody,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 12),
              const Flexible(child: ContactPickList()),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// My contacts who use DriveTalk, each with "Add".
class ContactPickList extends ConsumerWidget {
  const ContactPickList({super.key, this.scrolls = true});

  /// False inside a page that scrolls itself (one scroll, not two).
  final bool scrolls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final busy = ref.watch(realProvider.select((s) => s.busy));
    final c = ref.read(realProvider.notifier);
    final matches = c.contactMatches;
    return ListView(
      shrinkWrap: true,
      physics: scrolls ? null : const NeverScrollableScrollPhysics(),
      children: [
        for (final m in matches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_rounded),
            title: Text(m.name),
            trailing: FilledButton.tonal(
              onPressed: busy ? null : () => c.addContacts([m]),
              child: Text(l.contactsAdd),
            ),
          ),
      ],
    );
  }
}

/// Which of my groups this friend is in (that decides when they see me
/// free). Each tap saves.
class FriendCirclesPicker extends ConsumerWidget {
  const FriendCirclesPicker({super.key, required this.friend});
  final RealProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(realProvider);
    final circles = s.snapshot?.circles ?? const <RealCircle>[];
    if (circles.isEmpty) return const SizedBox.shrink();
    final inIds = {
      for (final c in circles)
        if (c.memberIds.contains(friend.id)) c.id,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.friendCirclesTitle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            l.friendCirclesBody,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in circles)
                FilterChip(
                  label: Text(c.name),
                  selected: inIds.contains(c.id),
                  onSelected: s.busy
                      ? null
                      : (on) => ref
                            .read(realProvider.notifier)
                            .setFriendCircles(
                              friend,
                              on
                                  ? {...inIds, c.id}
                                  : ({...inIds}..remove(c.id)),
                            ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
