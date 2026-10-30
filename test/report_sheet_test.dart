// The report sheet must be usable on a small phone: "send" was cut off
// below the screen (owner feedback, D-085).
import 'package:drivetalk/domain/models.dart';
import 'package:drivetalk/features/match/safety_actions.dart';
import 'package:drivetalk/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('report: "send" is reachable on a small screen', (t) async {
    t.view.physicalSize = const Size(320, 560);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    (ReportReason, bool)? sent;
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('he'),
          supportedLocales: const [Locale('he')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showReportSheet(
                    context,
                    ref,
                    const Person(id: 'x', name: 'דנה', avatarColor: 0xFF000000),
                    onReport: (r, b) async => sent = (r, b),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'no overflow');
    await t.tap(find.text('הטרדה'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('שליחת דיווח'));
    await t.pumpAndSettle();
    await t.tap(find.text('שליחת דיווח'));
    await t.pumpAndSettle();
    expect(sent, (ReportReason.harassment, true));
  });
}
