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
          // A clear name and one line saying what it counts.
          Widget row(
            String label,
            String hint,
            String key, {
            String extra = '',
            _Notes? open,
          }) => ListTile(
            title: Text(label),
            subtitle: Text(hint),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${m[key]?.round() ?? '—'}$extra',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (open != null) const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: open == null ? null : () => _openNotes(context, open),
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
              ListTile(
                leading: const Icon(Icons.person_search_rounded),
                title: Text(l.ownerLookupTitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _OwnerLookupScreen(),
                  ),
                ),
              ),
              row(l.statsUsers, l.statsUsersHint, 'users'),
              row(l.statsNewUsers, l.statsNewUsersHint, 'new_users'),
              row(l.statsActiveUsers, l.statsActiveUsersHint, 'active_users'),
              row(l.statsFriendships, l.statsFriendshipsHint, 'friendships'),
              const Divider(),
              row(l.statsFreeTimes, l.statsFreeTimesHint, 'free_times'),
              row(l.statsOffers, l.statsOffersHint, 'offers'),
              row(l.statsQuick, l.statsQuickHint, 'quick'),
              row(
                l.statsBothYes,
                l.statsBothYesHint,
                'both_yes',
                extra: pct(m['both_yes'], offers),
              ),
              row(
                l.statsTalked,
                l.statsTalkedHint,
                'talked',
                extra: pct(m['talked'], offers),
              ),
              row(
                l.statsDeclined,
                l.statsDeclinedHint,
                'declined',
                extra: pct(m['declined'], offers),
              ),
              row(l.statsLater, l.statsLaterHint, 'later'),
              row(
                l.statsNoAnswer,
                l.statsNoAnswerHint,
                'no_answer',
                extra: pct(m['no_answer'], offers),
              ),
              const Divider(),
              row(
                l.statsReports,
                l.statsReportsHint,
                'reports',
                open: _Notes.reports,
              ),
              row(
                l.statsFeedback,
                l.statsFeedbackHint,
                'feedback',
                open: _Notes.feedback,
              ),
              row(
                l.statsCrashes,
                l.statsCrashesHint,
                'crashes',
                open: _Notes.crashes,
              ),
              const Divider(),
              ListTile(
                title: Text(l.statsDialMs),
                subtitle: Text(l.statsDialMsHint),
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

enum _Notes { reports, feedback, crashes }

void _openNotes(BuildContext context, _Notes kind) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => _NotesScreen(kind)));

/// Owner only: the latest feedback, reports or crash notes, newest first.
class _NotesScreen extends ConsumerWidget {
  const _NotesScreen(this.kind);
  final _Notes kind;
  bool get reports => kind == _Notes.reports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (kind) {
          _Notes.reports => l.statsReportsTitle,
          _Notes.feedback => l.statsFeedbackTitle,
          _Notes.crashes => l.statsCrashesTitle,
        }),
      ),
      body: FutureBuilder<List<OwnerNote>?>(
        future: kind == _Notes.crashes
            ? ref.read(realProvider.notifier).ownerCrashes()
            : ref.read(realProvider.notifier).ownerNotes(reports: reports),
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
              trailing: const Icon(Icons.chevron_right_rounded),
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
                        if (notes[i].details != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            l.ownerDetails,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            notes[i].details!,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
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

/// Owner: someone's state on the server, by name or number — "why is X
/// grey?" (D-143). Never a number shown.
class _OwnerLookupScreen extends ConsumerStatefulWidget {
  const _OwnerLookupScreen();

  @override
  ConsumerState<_OwnerLookupScreen> createState() => _OwnerLookupState();
}

class _OwnerLookupState extends ConsumerState<_OwnerLookupScreen> {
  final _query = TextEditingController();
  List<Map<String, Object?>>? _rows;
  var _busy = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _busy = true);
    final r = await ref.read(realProvider.notifier).ownerLookup(_query.text);
    if (!mounted) return;
    setState(() {
      _rows = r ?? const [];
      _busy = false;
    });
  }

  String _time(Object? v) {
    final t = v is String ? DateTime.tryParse(v)?.toLocal() : null;
    if (t == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.day}/${t.month} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: Text(l.ownerLookupTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: l.ownerLookupHint,
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: _busy ? null : _search,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (!_busy && rows != null && rows.isEmpty) Text(l.ownerLookupNone),
          if (!_busy && rows != null)
            for (final r in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    [
                      '${r['display_name']}  (${'${r['user_id']}'.substring(0, 6)})',
                      'last seen: ${_time(r['last_seen_at'])}',
                      'accounts with this number: ${r['same_number_accounts'] ?? '—'}',
                      'friends: ${r['friends'] ?? '—'}',
                      'free: ${r['free_mode'] ?? 'no'}'
                          '${r['free_mode'] == null ? '' : ' until ${_time(r['free_until'])} (${r['free_source']})'}',
                      'missed a question: ${r['missed_at'] == null ? 'no' : _time(r['missed_at'])}',
                      'quiet until: ${_time(r['quiet_until'])}',
                      'in an app call: ${r['in_call']}',
                      'on the phone: ${r['on_phone']}',
                      'open question: ${r['open_question']}',
                      'asked enough this time: ${r['asked_enough'] ?? '—'}',
                      'can be asked now: ${r['can_be_asked']}',
                      'background (device token): ${r['auto_driving']}',
                      'last question: ${r['last_offer'] ?? '—'}',
                    ].join('\n'),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
