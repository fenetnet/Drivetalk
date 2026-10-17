import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../domain/models.dart';
import '../common/labels.dart';

/// Block with confirmation. Available from day one, everywhere a person appears.
Future<void> confirmBlock(
  BuildContext context,
  WidgetRef ref,
  Person person, {
  required Future<void> Function() onBlock,
}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(l.personBlockConfirm(person.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(c, true),
          child: Text(l.block),
        ),
      ],
    ),
  );
  if (ok ?? false) await onBlock();
}

/// Report with a short reason list, and an option to block too.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref,
  Person person, {
  required Future<void> Function(ReportReason reason, bool alsoBlock) onReport,
}) async {
  final result = await showModalBottomSheet<(ReportReason, bool)>(
    context: context,
    showDragHandle: true,
    // Full height when needed and scrollable: "send" is always reachable.
    isScrollControlled: true,
    builder: (c) => _ReportSheet(person: person),
  );
  if (result != null) await onReport(result.$1, result.$2);
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.person});
  final Person person;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  var _alsoBlock = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = {
      ReportReason.inappropriate: l.reportInappropriate,
      ReportReason.harassment: l.reportHarassment,
      ReportReason.spam: l.reportSpam,
      ReportReason.underage: l.reportUnderage,
      ReportReason.other: l.reportOther,
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.reportTitle(widget.person.name),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final e in labels.entries)
                    RadioListTile<ReportReason>(
                      value: e.key,
                      title: Text(e.value),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            CheckboxListTile(
              value: _alsoBlock,
              onChanged: (v) => setState(() => _alsoBlock = v ?? false),
              title: Text(l.reportAlsoBlock),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _reason == null
                  ? null
                  : () => Navigator.pop(context, (_reason!, _alsoBlock)),
              child: Text(l.reportSend),
            ),
          ],
        ),
      ),
    );
  }
}
