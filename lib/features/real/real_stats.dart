import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
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
              ListTile(
                title: Text(l.statsReports),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${m['reports']?.round() ?? '—'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
                onTap: () => _openNotes(context, reports: true),
              ),
              ListTile(
                title: Text(l.statsFeedback),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${m['feedback']?.round() ?? '—'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
                onTap: () => _openNotes(context, reports: false),
              ),
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

void _openNotes(BuildContext context, {required bool reports}) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => _NotesScreen(reports: reports)));

/// Owner only: the latest feedback or reports, newest first.
class _NotesScreen extends ConsumerWidget {
  const _NotesScreen({required this.reports});
  final bool reports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(reports ? l.statsReportsTitle : l.statsFeedbackTitle),
      ),
      body: FutureBuilder<List<OwnerNote>?>(
        future: ref.read(realProvider.notifier).ownerNotes(reports: reports),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snap.data;
          if (notes == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l.statsNotesFailed)),
            );
          }
          if (notes.isEmpty) return Center(child: Text(l.statsNotesEmpty));
          String when(DateTime t) {
            final d = t.toLocal();
            String two(int n) => n.toString().padLeft(2, '0');
            return '${d.day}/${d.month} ${two(d.hour)}:${two(d.minute)}';
          }

          // A report's reason in words ("harassment" → "הטרדה").
          String body(OwnerNote n) {
            if (!reports) return n.body;
            return switch (n.body) {
              'inappropriate' => l.reportInappropriate,
              'harassment' => l.reportHarassment,
              'spam' => l.reportSpam,
              'underage' => l.reportUnderage,
              'other' => l.reportOther,
              _ => n.body,
            };
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, i) => ListTile(
              title: Text(
                body(notes[i]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${notes[i].title} · ${when(notes[i].at)}'),
              trailing: const Icon(Icons.chevron_left_rounded),
              // Tap: everything about it.
              onTap: () => showDialog<void>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text(notes[i].title),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          when(notes[i].at),
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          body(notes[i]),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: Text(l.close),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
