import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../real/real_controller.dart';
import '../../real/real_models.dart';
import '../common/labels.dart';
import '../common/widgets.dart';

/// "Circles" block in My people: private groups, optional quick connect.
class RealCirclesSection extends ConsumerWidget {
  const RealCirclesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final snap = ref.watch(realProvider.select((s) => s.snapshot));
    final circles = snap?.circles ?? const <RealCircle>[];
    final friends = snap?.friends ?? const <RealProfile>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          l.realCirclesTitle,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l.realCirclesIntro,
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
        ),
        const SizedBox(height: 10),
        for (final c in circles)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(
                c.quick ? Icons.bolt_rounded : Icons.group_work_rounded,
                color: c.quick ? AppColors.terracotta : AppColors.sageDark,
              ),
              title: Text(
                c.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${[l.realCircleCount(c.memberIds.length), if (c.quick) l.realCircleQuick].join(' · ')}'
                '\n${l.showRuleSeen(showRuleLabel(l, ShowRule(c.showModes)))}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.edit_rounded),
              onTap: () => openCircleEditor(context, c),
            ),
          ),
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
  late bool _quick = widget.circle?.quick ?? false;
  late final Set<String> _members = {...?widget.circle?.memberIds};
  late ShowRule _rule = ShowRule(widget.circle?.showModes);

  Future<void> _save() async {
    final c = ref.read(realProvider.notifier);
    final ok = await c.saveCircle(
      RealCircle(
        id: widget.circle?.id ?? '',
        name: _name.text,
        quick: _quick,
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.bolt_rounded,
                color: AppColors.terracotta,
              ),
              title: Text(l.realCircleQuick),
              subtitle: Text(l.realCircleQuickBody),
              value: _quick,
              onChanged: (v) => setState(() => _quick = v),
            ),
            const SizedBox(height: 8),
            Text(
              l.showRuleTitle(
                _name.text.trim().isEmpty ? l.realCircleNew : _name.text.trim(),
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            ShowRulePicker(
              rule: _rule,
              onChanged: (r) => setState(() => _rule = r),
            ),
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
                onPressed: () async {
                  await ref
                      .read(realProvider.notifier)
                      .deleteCircle(widget.circle!);
                  if (context.mounted) Navigator.of(context).pop();
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

/// Settings → "Who sees that I'm free": every circle and "everyone else".
class WhoSeesMeScreen extends ConsumerWidget {
  const WhoSeesMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final snap = ref.watch(realProvider.select((s) => s.snapshot));
    final c = ref.read(realProvider.notifier);
    final circles = snap?.circles ?? const <RealCircle>[];
    final others = ShowRule(snap?.othersModes);
    final friends = snap?.friends ?? const <RealProfile>[];
    final inNone = [
      for (final f in friends)
        if (!circles.any((x) => x.memberIds.contains(f.id))) f,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.whoSeesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(l.whoSeesBody, style: const TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 12),
          for (final circle in circles)
            Card(
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
                  '${showRuleLabel(l, ShowRule(circle.showModes))}'
                  ' · ${l.realCircleCount(circle.memberIds.length)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final r = await pickShowRule(
                    context,
                    title: l.showRuleTitle(circle.name),
                    initial: ShowRule(circle.showModes),
                  );
                  if (r != null) await c.setCircleRule(circle, r);
                },
              ),
            ),
          Card(
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
                '${showRuleLabel(l, others)}'
                ' · ${l.realCircleCount(inNone.length)}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final r = await pickShowRule(
                  context,
                  title: l.showRuleTitle(l.whoSeesOthers),
                  initial: others,
                );
                if (r != null) await c.setOthersRule(r);
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(l.whoSeesTwo, style: const TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 16),
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
      ),
    );
  }
}
