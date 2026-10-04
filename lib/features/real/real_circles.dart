import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
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
                [
                  l.realCircleCount(c.memberIds.length),
                  if (c.quick) l.realCircleQuick,
                ].join(' · '),
              ),
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

  Future<void> _save() async {
    final c = ref.read(realProvider.notifier);
    final ok = await c.saveCircle(
      RealCircle(
        id: widget.circle?.id ?? '',
        name: _name.text,
        quick: _quick,
        memberIds: _members,
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
