import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../domain/catalog.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// Discover / Serendipity: how open am I? No feed here — just settings that
/// shape who may be suggested.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(dataVersionProvider);
    final profile = ref.watch(profileServiceProvider);
    final me = profile.me;

    void update(Person p) => profile.updateMe(p);

    return Scaffold(
      appBar: AppBar(title: Text(l.tabDiscover)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l.discoverIntro,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          for (final t in MatchTier.values)
            SwitchListTile(
              secondary: Icon(switch (t) {
                MatchTier.familiar => Icons.favorite_rounded,
                MatchTier.reconnect => Icons.history_rounded,
                MatchTier.widenCircle => Icons.diversity_3_rounded,
                MatchTier.surpriseMe => Icons.auto_awesome_rounded,
              }, color: AppColors.terracotta),
              title: Text(tierLabel(l, t)),
              subtitle: Text(tierDescription(l, t)),
              value: me.openTiers.contains(t),
              onChanged: (v) => update(
                me.copyWith(
                  openTiers: v
                      ? {...me.openTiers, t}
                      : ({...me.openTiers}..remove(t)),
                ),
              ),
            ),
          const Divider(indent: 20, endIndent: 20),
          SwitchListTile(
            secondary: const Icon(
              Icons.handshake_rounded,
              color: AppColors.sageDark,
            ),
            title: Text(l.discoverFofTitle),
            subtitle: Text(l.discoverFofBody),
            value: me.openToFriendsOfFriends,
            onChanged: (v) => update(me.copyWith(openToFriendsOfFriends: v)),
          ),
          SectionTitle(l.discoverInterests),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.discoverInterestsBody,
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in allInterests)
                      FilterChip(
                        label: Text(i),
                        selected: me.interests.contains(i),
                        onSelected: (v) => update(
                          me.copyWith(
                            interests: v
                                ? {...me.interests, i}
                                : ({...me.interests}..remove(i)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SectionTitle(l.discoverLanguages),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (code, label) in [
                  ('he', l.langHe),
                  ('en', l.langEn),
                ])
                  FilterChip(
                    label: Text(label),
                    selected: me.languages.contains(code),
                    onSelected: (v) {
                      final langs = v
                          ? {...me.languages, code}
                          : ({...me.languages}..remove(code));
                      if (langs.isNotEmpty) {
                        update(me.copyWith(languages: langs));
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
