import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// My people → "Groups": one row that opens the groups on their own screen
/// (not one more long block at the bottom of the list).
class RealCirclesEntry extends ConsumerWidget {
  const RealCirclesEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final circles = ref.watch(
      realProvider.select((s) => s.snapshot?.circles ?? const <RealCircle>[]),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(
          Icons.group_work_rounded,
          color: AppColors.sageDark,
        ),
        title: Text(
          l.realCirclesTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          circles.isEmpty
              ? l.realCirclesNone
              : circles.map((c) => c.name).join(' · '),
          maxLines: 2,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RealCirclesScreen()),
        ),
      ),
    );
  }
}

class RealCirclesScreen extends StatelessWidget {
  const RealCirclesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.realCirclesTitle)),
    body: const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: RealCirclesSection(),
    ),
  );
}

/// The groups: private, each says who sees that I'm free — and when.
/// (Quick connect is per person, on each friend's card — D-116.)
class RealCirclesSection extends ConsumerWidget {
  const RealCirclesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final snap = ref.watch(realProvider.select((s) => s.snapshot));
    final c = ref.read(realProvider.notifier);
    final circles = snap?.circles ?? const <RealCircle>[];
    final friends = snap?.friends ?? const <RealProfile>[];
    final others = ShowRule(snap?.othersModes);
    final inNone = [
      for (final f in friends)
        if (!circles.any((x) => x.memberIds.contains(f.id))) f,
    ];
    // "Who sees me in each mode" left the groups (D-156): shown only where
    // someone already set it (so it can still be seen and changed).
    final legacy =
        circles.any((x) => x.showModes != null) || snap?.othersModes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.showGroupsNote) ...[
          Card(
            color: const Color(0xFFFFF7E8),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l.groupsNote,
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: c.dismissGroupsNote,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          l.realCirclesIntro,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
        ),
        const SizedBox(height: 12),
        for (final circle in circles)
          Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(
                Icons.group_work_rounded,
                color: AppColors.sageDark,
              ),
              title: Text(
                circle.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                circle.showModes == null
                    ? l.realCircleCount(circle.memberIds.length)
                    : '${l.realCircleCount(circle.memberIds.length)}'
                          '\n${circleRuleLine(l, ShowRule(circle.showModes))}',
              ),
              isThreeLine: circle.showModes != null,
              trailing: const Icon(Icons.edit_rounded),
              onTap: () => openCircleEditor(context, circle),
            ),
          ),
        // Friends in no group: one rule for all of them (only if set).
        if (legacy)
          Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(
                Icons.people_outline_rounded,
                color: AppColors.inkSoft,
              ),
              title: Text(
                l.whoSeesOthers,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${l.realCircleCount(inNone.length)}'
                '\n${circleRuleLine(l, others)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.edit_rounded),
              onTap: snap == null
                  ? null
                  : () async {
                      final r = await pickShowRule(
                        context,
                        title: l.othersRuleTitle,
                        initial: others,
                      );
                      if (r != null) await c.setOthersRule(r);
                    },
            ),
          ),
        if (legacy) ...[
          Text(l.whoSeesTwo, style: const TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: friends.isEmpty
              ? null
              : () => openCircleEditor(context, null),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            friends.isEmpty ? l.realCircleNoFriends : l.realCircleNew,
          ),
        ),
      ],
    );
  }
}

Future<void> openCircleEditor(BuildContext context, RealCircle? circle) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CircleEditor(circle: circle),
    );

class _CircleEditor extends ConsumerStatefulWidget {
  const _CircleEditor({this.circle});
  final RealCircle? circle;

  @override
  ConsumerState<_CircleEditor> createState() => _CircleEditorState();
}

class _CircleEditorState extends ConsumerState<_CircleEditor> {
  late final _name = TextEditingController(text: widget.circle?.name ?? '');
  late final Set<String> _members = {...?widget.circle?.memberIds};
  late ShowRule _rule = ShowRule(widget.circle?.showModes);
  var _deleting = false;

  Future<void> _save() async {
    final c = ref.read(realProvider.notifier);
    final ok = await c.saveCircle(
      RealCircle(
        id: widget.circle?.id ?? '',
        name: _name.text,
        memberIds: _members,
        showModes: _rule.modes,
      ),
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final friends =
        ref.watch(realProvider.select((s) => s.snapshot?.friends)) ??
        const <RealProfile>[];
    final busy = ref.watch(realProvider.select((s) => s.busy));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              controller: _name,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: l.realCircleName,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            // Only where a rule was already set (D-156).
            if (widget.circle?.showModes != null) ...[
              const SizedBox(height: 8),
              Text(
                l.circleRuleQuestion,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              ShowRulePicker(
                rule: _rule,
                onChanged: (r) => setState(() => _rule = r),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              l.realCircleMembers,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final f in friends)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                secondary: PersonAvatar(person: f.toPerson(), size: 36),
                title: Text(f.name),
                value: _members.contains(f.id),
                onChanged: (v) => setState(
                  () => v == true ? _members.add(f.id) : _members.remove(f.id),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy || _name.text.trim().isEmpty ? null : _save,
              child: Text(l.save),
            ),
            if (widget.circle != null)
              TextButton(
                onPressed: busy || _deleting
                    ? null
                    : () async {
                        setState(() => _deleting = true);
                        final c = ref.read(realProvider.notifier);
                        final route = ModalRoute.of(context);
                        await c.deleteCircle(widget.circle!);
                        // Once, and only this sheet (not the screen behind).
                        if (context.mounted && (route?.isCurrent ?? false)) {
                          Navigator.of(context).pop();
                        }
                      },
                child: Text(
                  l.realCircleDelete,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Always" / "Never" / "Only when: driving, break…" in words.
String showRuleLabel(AppLocalizations l, ShowRule rule) {
  final modes = rule.modes;
  if (modes == null) return l.showAlways;
  if (modes.isEmpty) return l.showNever;
  return l.showOnlyModes(
    [
      for (final m in AvailabilityMode.values)
        if (modes.contains(m)) modeLabel(l, m),
    ].join(', '),
  );
}

/// A group's card: "seen free: in every mode" / "…: driving, walking" /
/// "hidden from the group".
String circleRuleLine(AppLocalizations l, ShowRule rule) {
  final modes = rule.modes;
  if (modes == null || modes.length == AvailabilityMode.values.length) {
    return l.circleSeesAll;
  }
  if (modes.isEmpty) return l.circleSeesNone;
  return l.circleSeesSome(
    [
      for (final m in AvailabilityMode.values)
        if (modes.contains(m))
          switch (m) {
            AvailabilityMode.driving => l.modeInDriving,
            AvailabilityMode.walking => l.modeInWalking,
            AvailabilityMode.breakTime => l.modeInBreak,
            AvailabilityMode.free => l.modeInFree,
          },
    ].join(', '),
  );
}

/// Always / never / only in some modes.
class ShowRulePicker extends StatelessWidget {
  const ShowRulePicker({
    super.key,
    required this.rule,
    required this.onChanged,
  });
  final ShowRule rule;
  final ValueChanged<ShowRule> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final modes = rule.modes;
    final kind = modes == null
        ? 'always'
        : modes.isEmpty
        ? 'never'
        : 'only';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<String>(
          groupValue: kind,
          onChanged: (k) => onChanged(switch (k) {
            'always' => ShowRule.always,
            'never' => ShowRule.never,
            // A first mode so "only…" means something; change it below.
            _ => const ShowRule({AvailabilityMode.driving}),
          }),
          child: Column(
            children: [
              for (final (k, label) in [
                ('always', l.showAlways),
                ('never', l.showNever),
                ('only', l.showOnly),
              ])
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: k,
                  title: Text(label),
                ),
            ],
          ),
        ),
        if (kind == 'only')
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final m in AvailabilityMode.values)
                FilterChip(
                  avatar: Icon(modeIcon(m), size: 18),
                  label: Text(modeLabel(l, m)),
                  selected: modes!.contains(m),
                  onSelected: (on) {
                    final next = {...modes};
                    on ? next.add(m) : next.remove(m);
                    onChanged(ShowRule(next));
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// A sheet with the picker and "save".
Future<ShowRule?> pickShowRule(
  BuildContext context, {
  required String title,
  required ShowRule initial,
}) => showModalBottomSheet<ShowRule>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _RuleSheet(title: title, initial: initial),
);

class _RuleSheet extends StatefulWidget {
  const _RuleSheet({required this.title, required this.initial});
  final String title;
  final ShowRule initial;

  @override
  State<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends State<_RuleSheet> {
  late ShowRule _rule = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ShowRulePicker(
              rule: _rule,
              onChanged: (r) => setState(() => _rule = r),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, _rule),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
