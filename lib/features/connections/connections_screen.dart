import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../services/social_graph_service.dart';
import '../common/labels.dart';
import '../common/widgets.dart';
import 'add_friend_screen.dart';
import 'person_sheet.dart';

enum _Tab { close, reconnect, colleagues, fof }

/// Connections split into: close / reconnect / colleagues & acquaintances /
/// friends of friends.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: _Tab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.tabConnections),
          actions: [
            IconButton(
              tooltip: l.addFriend,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AddFriendScreen(),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.connTabClose),
              Tab(text: l.connTabReconnect),
              Tab(text: l.connTabColleagues),
              Tab(text: l.connTabFof),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final t in _Tab.values) _ConnectionList(tab: t)],
        ),
      ),
    );
  }
}

class _ConnectionList extends ConsumerWidget {
  const _ConnectionList({required this.tab});
  final _Tab tab;

  static const _close = {
    RelationshipType.family,
    RelationshipType.closeFriend,
    RelationshipType.friend,
    RelationshipType.childhoodFriend,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final now = ref.watch(nowProvider);
    final graph = ref.watch(socialGraphServiceProvider);
    final me = ref.watch(profileServiceProvider).me;
    final dormantDays = ref.watch(matchingConfigProvider).dormantAfterDays;
    final blocked = graph.blockedIds;

    bool isDormant(Connection c) {
      final last = c.lastInteraction;
      if (last == null) return _close.contains(c.relationshipType);
      return now.difference(last).inDays >= dormantDays;
    }

    final people = <Person>[];
    if (tab == _Tab.fof) {
      if (!me.openToFriendsOfFriends) {
        return _Empty(text: l.connFofOff, icon: Icons.lock_outline_rounded);
      }
      for (final p in graph.people) {
        if (blocked.contains(p.id) || graph.connectionWith(p.id) != null) {
          continue;
        }
        final viaFof =
            graph.mutualFriendsWith(p.id) > 0 && p.openToFriendsOfFriends;
        if (viaFof || graph.sharedGroupsWith(p.id).isNotEmpty) people.add(p);
      }
    } else {
      for (final c in graph.connections) {
        final p = graph.personById(c.personId);
        if (p == null || blocked.contains(p.id)) continue;
        final dormant = isDormant(c);
        final belongs = switch (tab) {
          _Tab.reconnect => dormant,
          _Tab.close =>
            !dormant &&
                (c.relationshipType == null ||
                    _close.contains(c.relationshipType)),
          _Tab.colleagues =>
            !dormant &&
                c.relationshipType != null &&
                !_close.contains(c.relationshipType),
          _Tab.fof => false,
        };
        if (belongs) people.add(p);
      }
    }
    if (people.isEmpty) return _Empty(text: l.connEmpty);
    people.sort((a, b) => a.name.compareTo(b.name));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: people.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _PersonTile(
        person: people[i],
        subtitle: _subtitle(l, graph, people[i], now),
      ),
    );
  }

  String _subtitle(
    AppLocalizations l,
    SocialGraphService graph,
    Person p,
    DateTime now,
  ) {
    final c = graph.connectionWith(p.id);
    final line = relationshipLine(
      l,
      connection: c,
      mutualFriends: graph.mutualFriendsWith(p.id),
      sharedGroups: graph.sharedGroupsWith(p.id),
    );
    if (c == null) {
      final mutual = graph.mutualFriendsWith(p.id);
      final groups = graph.sharedGroupsWith(p.id);
      if (mutual > 0) return l.mutualFriendsShort(mutual);
      if (groups.isNotEmpty) return l.reasonSharedGroup(groups.first.name);
      return line;
    }
    final last = c.lastInteraction;
    final talked = last == null
        ? l.connNeverTalked
        : now.difference(last).inDays < 1
        ? l.connLastTalkedToday
        : l.connLastTalked(durationText(l, now.difference(last).inDays));
    return '$line · $talked';
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.subtitle});
  final Person person;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: PersonAvatar(person: person, size: 48),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        subtitle: Text(subtitle),
        onTap: () => showPersonSheet(context, person.id),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.icon = Icons.people_outline_rounded});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.inkSoft),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
