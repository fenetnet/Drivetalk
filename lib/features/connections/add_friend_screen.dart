import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Add a friend without reading the phone's contacts: invite link, search,
/// invitation groups. (QR comes later.)
class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  var _query = '';

  static const _sampleLink = 'https://drivetalk.example/i/demo123';

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(context.l10n.addFriendCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final graph = ref.watch(socialGraphServiceProvider);
    final me = ref.watch(profileServiceProvider).me;
    final results = graph.search(_query);

    return Scaffold(
      appBar: AppBar(title: Text(l.addFriend)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        color: AppColors.terracotta,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.addFriendInviteLink,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l.addFriendInviteLinkBody),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _copy(_sampleLink),
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(l.addFriendCopy),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.inkSoft,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.addFriendQrSoon,
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionTitle(l.addFriendSearch),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l.addFriendSearch,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          for (final p in results)
            ListTile(
              leading: PersonAvatar(person: p, size: 40),
              title: Text(p.name),
              trailing: graph.connectionWith(p.id) != null
                  ? Text(
                      l.addFriendConnected,
                      style: const TextStyle(color: AppColors.sageDark),
                    )
                  : FilledButton.tonal(
                      onPressed: () => graph.addConnection(p.id),
                      child: Text(l.addFriendAdd),
                    ),
            ),
          SectionTitle(l.addFriendGroups),
          for (final g in me.groupIds)
            if (graph.groupById(g) case final group?)
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(Icons.groups_rounded),
                title: Text(group.name),
                trailing: TextButton(
                  onPressed: () => _copy('$_sampleLink?group=$g'),
                  child: Text(l.addFriendGroupInvite),
                ),
              ),
        ],
      ),
    );
  }
}
