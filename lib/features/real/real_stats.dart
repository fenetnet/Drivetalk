import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../real/real_controller.dart';
import '../common/labels.dart';

/// Owner only (behind the admin code): totals — no names, nothing about
/// a single person.
class RealStatsScreen extends ConsumerStatefulWidget {
  const RealStatsScreen({super.key});

  @override
  ConsumerState<RealStatsScreen> createState() => _RealStatsState();
}

class _RealStatsState extends ConsumerState<RealStatsScreen> {
  var _days = 7;
  Future<Map<String, num?>?>? _load;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _load = ref.read(realProvider.notifier).appStats(_days);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String pct(num? part, num? whole) =>
        whole == null || whole == 0 || part == null
        ? ''
        : '  (${(part * 100 / whole).round()}%)';
    return Scaffold(
      appBar: AppBar(title: Text(l.statsTitle)),
      body: FutureBuilder<Map<String, num?>?>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snap.data;
          if (m == null) return Center(child: Text(l.statsFailed));
          Widget row(String label, String key, [String extra = '']) => ListTile(
            title: Text(label),
            trailing: Text(
              '${m[key]?.round() ?? '—'}$extra',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          );
          final offers = (m['offers'] ?? 0) + (m['quick'] ?? 0);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 7, label: Text(l.statsWeek)),
                  ButtonSegment(value: 30, label: Text(l.statsMonth)),
                ],
                selected: {_days},
                onSelectionChanged: (v) => setState(() {
                  _days = v.first;
                  _reload();
                }),
              ),
              const SizedBox(height: 12),
              row(l.statsUsers, 'users'),
              row(l.statsNewUsers, 'new_users'),
              row(l.statsActiveUsers, 'active_users'),
              row(l.statsFriendships, 'friendships'),
              const Divider(),
              row(l.statsFreeTimes, 'free_times'),
              row(l.statsOffers, 'offers'),
              row(l.statsQuick, 'quick'),
              row(l.statsBothYes, 'both_yes', pct(m['both_yes'], offers)),
              row(l.statsTalked, 'talked', pct(m['talked'], offers)),
              row(l.statsDeclined, 'declined', pct(m['declined'], offers)),
              row(l.statsLater, 'later'),
              row(l.statsNoAnswer, 'no_answer', pct(m['no_answer'], offers)),
              row(l.statsReports, 'reports'),
              row(l.statsFeedback, 'feedback'),
              const Divider(),
              ListTile(
                title: Text(l.statsDialMs),
                trailing: Text(
                  m['dial_ms'] == null
                      ? '—'
                      : '${(m['dial_ms']! / 1000).toStringAsFixed(1)} ${l.statsSeconds}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.statsNote,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
            ],
          );
        },
      ),
    );
  }
}
