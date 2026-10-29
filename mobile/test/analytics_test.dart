import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pennywise_mobile/domain/finance_analytics.dart';
import 'package:pennywise_mobile/domain/models.dart';
import 'package:pennywise_mobile/ui/analytics_screen.dart';
import 'package:pennywise_mobile/ui/theme.dart';

LedgerEntry example({
  String id = 'e',
  EntryKind kind = EntryKind.expense,
  int amount = 10001,
  DateTime? date,
  List<LineItem>? lines,
  List<Share> shares = const [],
  bool pending = false,
  String? merchant,
}) => LedgerEntry(
  id: id,
  kind: kind,
  accountId: 'bank',
  amountMinor: amount,
  date: date ?? DateTime(2026, 10, 10),
  description: 'Example transaction',
  metadataPending: pending,
  merchant: merchant,
  shares: shares,
  lines:
      lines ??
      [
        LineItem(
          description: 'Item',
          amountMinor: amount,
          category: 'Food & groceries',
          subcategory: 'Dining out',
        ),
      ],
);

void main() {
  final october = DateTime(2026, 10), now = DateTime(2026, 10, 15);
  test('shared bill counts only my share and conserves category paise', () {
    final entry = example(
      shares: const [
        Share(person: 'You', amountMinor: 3334),
        Share(person: 'A', amountMinor: 3334),
        Share(person: 'B', amountMinor: 3333),
      ],
      lines: const [
        LineItem(
          description: 'Food',
          amountMinor: 6001,
          category: 'Food & groceries',
          subcategory: 'Dining out',
        ),
        LineItem(
          description: 'Cab',
          amountMinor: 4000,
          category: 'Transport',
          subcategory: 'Cab',
        ),
      ],
      merchant: 'Cafe',
    );
    final a = FinanceAnalytics(
      LedgerState(entries: [entry]),
      month: october,
      now: now,
    );
    expect(a.spendingMinor, 3334);
    expect(a.categoryTotals, {'Food & groceries': 2001, 'Transport': 1333});
    expect(a.categoryTotals.values.fold(0, (a, b) => a + b), 3334);
    expect(a.subcategoryTotals.values.fold(0, (a, b) => a + b), 3334);
    expect(a.merchantTotals.values.fold(0, (a, b) => a + b), 3334);
  });
  test(
    'allocation is deterministic and exact at the supported money limit',
    () {
      final entry = example(
        amount: 9000000000000,
        shares: const [
          Share(person: 'You', amountMinor: 3000000000001),
          Share(person: 'Friend', amountMinor: 5999999999999),
        ],
        lines: const [
          LineItem(
            description: 'One',
            amountMinor: 4500000000000,
            category: 'Home',
            subcategory: 'Rent',
          ),
          LineItem(
            description: 'Two',
            amountMinor: 4500000000000,
            category: 'Home',
            subcategory: 'Rent',
          ),
        ],
      );
      expect(allocatePersonalItems(entry), [1500000000001, 1500000000000]);
    },
  );
  test(
    'transfers, loan principal and repayments do not inflate income or spending',
    () {
      final kinds = [
        EntryKind.transfer,
        EntryKind.lent,
        EntryKind.borrowed,
        EntryKind.repaymentPaid,
        EntryKind.repaymentReceived,
      ];
      final a = FinanceAnalytics(
        LedgerState(
          entries: [
            example(id: 'salary', kind: EntryKind.income, amount: 100000),
            example(id: 'expense', amount: 10000),
            ...kinds.map(
              (kind) => example(id: kind.name, kind: kind, amount: 50000),
            ),
          ],
        ),
        month: october,
        now: now,
      );
      expect(a.incomeMinor, 100000);
      expect(a.spendingMinor, 10000);
      expect(a.netCashflowMinor, 90000);
    },
  );
  test('pending metadata is separate from confirmed analytics', () {
    final a = FinanceAnalytics(
      LedgerState(
        entries: [
          example(id: 'reviewed', amount: 10000),
          example(id: 'pending-debit', amount: 50000, pending: true),
          example(
            id: 'pending-credit',
            amount: 25000,
            kind: EntryKind.income,
            pending: true,
          ),
        ],
      ),
      month: october,
      now: now,
    );
    expect(a.pendingCount, 2);
    expect(a.pendingAmountMinor, 75000);
    expect(a.spendingMinor, 10000);
    expect(a.incomeMinor, 0);
    expect(a.categoryTotals.values.single, 10000);
    expect(a.timeline.last.pendingCount, 2);
  });
  test(
    'current-month comparison matches elapsed days and excludes future dates',
    () {
      final a = FinanceAnalytics(
        LedgerState(
          entries: [
            example(id: 'current', amount: 10000, date: DateTime(2026, 10, 15)),
            example(
              id: 'future',
              amount: 1000000,
              date: DateTime(2026, 10, 16),
            ),
            example(id: 'previous', amount: 20000, date: DateTime(2026, 9, 15)),
            example(
              id: 'previous-later',
              amount: 1000000,
              date: DateTime(2026, 9, 16),
            ),
          ],
        ),
        month: october,
        now: now,
      );
      expect(a.spendingMinor, 10000);
      expect(a.previousSpendingMinor, 20000);
      expect(a.spendingChangePercent, -50);
      expect(a.comparisonLastDay, DateTime(2026, 9, 15));
      expect(a.timeline.length, 6);
      expect(a.timeline.last.partial, isTrue);
    },
  );
  test('past month is complete and comparison clamps a shorter month', () {
    final march = FinanceAnalytics(
      LedgerState(),
      month: DateTime(2026, 3),
      now: DateTime(2026, 3, 31),
    );
    expect(march.comparisonLastDay, DateTime(2026, 2, 28));
    final past = FinanceAnalytics(
      LedgerState(
        entries: [example(date: DateTime(2026, 9, 30), amount: 5500)],
      ),
      month: DateTime(2026, 9),
      now: now,
    );
    expect(past.spendingMinor, 5500);
    expect(past.periodLastDay, DateTime(2026, 9, 30));
    expect(past.isPartialMonth, isFalse);
  });
  test(
    'zero baseline is undefined and merchant names merge case-insensitively',
    () {
      final a = FinanceAnalytics(
        LedgerState(
          entries: [
            example(id: 'one', amount: 100, merchant: ' Cafe  House '),
            example(id: 'two', amount: 200, merchant: 'cafe house'),
            example(id: 'three', amount: 300),
          ],
        ),
        month: october,
        now: now,
      );
      expect(a.spendingChangePercent, isNull);
      expect(a.merchantTotals, {'Cafe House': 300, 'Not specified': 300});
    },
  );
  testWidgets(
    'analytics fits mobile, exposes pending review and changes month',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AnalyticsScreen(
                state: LedgerState(
                  entries: [example(id: 'pending', pending: true, date: today)],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('awaiting metadata review'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Previous analytics month'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          DateFormat('MMMM yyyy').format(DateTime(today.year, today.month - 1)),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
