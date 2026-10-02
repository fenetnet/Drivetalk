import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

/// Short, friendly openers based on a shared interest. Content lives in
/// assets/content/starters_he.json (one file per language).
class ConversationStarters {
  const ConversationStarters(this.byInterest);
  final Map<String, List<String>> byInterest;

  factory ConversationStarters.fromJson(Map<String, dynamic> j) =>
      ConversationStarters({
        for (final e in j.entries)
          e.key: [for (final s in e.value as List) s as String],
      });

  /// An opener for [me] and [other], or null if they share no known interest.
  /// Stable for the same pair, so it doesn't flicker between rebuilds.
  String? forPair(Person me, Person other) {
    final shared = me.interests.intersection(other.interests).toList()..sort();
    for (final interest in shared) {
      final list = byInterest[interest];
      if (list == null || list.isEmpty) continue;
      return list[other.id.hashCode.abs() % list.length];
    }
    return null;
  }
}

final startersProvider = Provider<ConversationStarters>(
  (ref) => const ConversationStarters({}),
);
