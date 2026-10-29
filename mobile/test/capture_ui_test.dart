import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywise_mobile/application/ledger_controller.dart';
import 'package:pennywise_mobile/data/ledger_repository.dart';
import 'package:pennywise_mobile/domain/capture_parser.dart';
import 'package:pennywise_mobile/domain/models.dart';
import 'package:pennywise_mobile/ui/home.dart';
import 'package:pennywise_mobile/ui/theme.dart';

void main() {
  for (final bank in [false, true]) {
    testWidgets(
      bank
          ? 'reviewing posted SMS changes metadata without another debit'
          : 'receipt draft posts only on confirmed review',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = LedgerController(
          MemoryLedgerRepository(
            LedgerState(
              accounts: const [
                Account(
                  id: 'a',
                  name: 'Bank',
                  type: 'Bank',
                  openingMinor: 100000,
                  lastFour: '1234',
                  smsSender: 'HDFCBK',
                ),
              ],
            ),
          ),
          isDemo: true,
        );
        await c.load();
        await c.stageCaptures(
          [
            ParsedCapture(
              source: bank ? 'bank_sms' : 'receipt',
              description: 'Coffee',
              evidenceKey: 'evidence',
              amountMinor: 10001,
              occurredAt: DateTime(2026, 1, 1),
              kind: EntryKind.expense,
              merchant: 'Cafe',
              accountHint: '1234',
              suggestedCategory: 'Food & groceries',
              suggestedSubcategory: 'Tea & coffee',
            ),
          ],
          accountId: 'a',
          sender: 'VM-HDFCBK',
          bankEvent: bank,
        );
        expect(c.state.balance('a'), bank ? 89999 : 100000);
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            home: FinanceHome(controller: c, onLock: () {}),
          ),
        );
        await tester.tap(find.text('Review inbox · 1'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Review details'));
        await tester.tap(find.text('Review details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm & save transaction'));
        await tester.pumpAndSettle();
        expect(c.state.balance('a'), 89999);
        expect(c.state.entries.length, 1);
        expect(c.state.entries.single.metadataPending, isFalse);
        expect(c.state.reviewCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
