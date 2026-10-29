import 'package:flutter_test/flutter_test.dart';
import 'package:pennywise_mobile/application/ledger_controller.dart';
import 'package:pennywise_mobile/data/ledger_repository.dart';
import 'package:pennywise_mobile/domain/ledger.dart';
import 'package:pennywise_mobile/domain/models.dart';
import 'package:pennywise_mobile/domain/money.dart';

final date = DateTime(2026, 1, 1);
LedgerState initial() => LedgerState(
  accounts: const [
    Account(id: 'a', name: 'Bank', type: 'Bank', openingMinor: 100000),
    Account(id: 'b', name: 'Cash', type: 'Cash'),
  ],
);
LedgerEntry expense({
  String id = 'x',
  int amount = 10001,
  String payer = 'You',
  List<Share> shares = const [],
  List<LineItem>? lines,
}) => LedgerEntry(
  id: id,
  kind: EntryKind.expense,
  accountId: 'a',
  amountMinor: amount,
  date: date,
  description: 'Dinner',
  payer: payer,
  shares: shares,
  lines:
      lines ??
      [
        LineItem(
          description: 'Dinner',
          amountMinor: amount,
          category: 'Food & groceries',
          subcategory: 'Dining out',
        ),
      ],
);
LedgerEntry debt(String id, EntryKind kind, int amount, String person) =>
    LedgerEntry(
      id: id,
      kind: kind,
      accountId: 'a',
      amountMinor: amount,
      date: date,
      description: 'Debt',
      counterparty: person,
    );

void main() {
  test(
    'decimal parsing is exact, supports Indian grouping and rejects precision loss',
    () {
      expect(parseMoney('₹1,23,456.78'), 12345678);
      expect(parseMoney('0.01'), 1);
      expect(parseMoney('-10.25', allowNegative: true), -1025);
      for (final invalid in [
        '1.001',
        '1e5',
        'NaN',
        '1,2,3',
        '-1',
        '90000000000.01',
      ]) {
        expect(
          () => parseMoney(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
    },
  );
  test('split remainder preserves every paise', () {
    expect(splitEqually(100, 3), [34, 33, 33]);
    for (var total = 1; total < 501; total++) {
      for (var n = 1; n < 12; n++) {
        expect(splitEqually(total, n).fold(0, (a, b) => a + b), total);
      }
    }
  });
  test(
    'own-account transfer preserves net worth and is not income or spending',
    () {
      final state = LedgerRules.append(initial(), [
        LedgerEntry(
          id: 't',
          kind: EntryKind.transfer,
          accountId: 'a',
          toAccountId: 'b',
          amountMinor: 20000,
          date: date,
          description: 'ATM',
        ),
      ]);
      expect(state.balance('a'), 80000);
      expect(state.balance('b'), 20000);
      expect(state.netWorthMinor, 100000);
      expect(state.incomeFor(date), 0);
      expect(state.expenseFor(date), 0);
    },
  );
  test(
    'own-paid expense records full cash movement but only personal spending',
    () {
      final state = LedgerRules.append(initial(), [
        expense(
          shares: const [
            Share(person: 'You', amountMinor: 3335),
            Share(person: 'A', amountMinor: 3333),
            Share(person: 'B', amountMinor: 3333),
          ],
        ),
      ]);
      expect(state.balance('a'), 89999);
      expect(state.expenseFor(date), 3335);
      expect(state.debts, {'A': 3333, 'B': 3333});
      expect(state.netWorthMinor, 96665);
    },
  );
  test(
    'someone else paying creates only my payable and leaves my cash alone',
    () {
      final state = LedgerRules.append(initial(), [
        expense(
          payer: 'A',
          shares: const [
            Share(person: 'You', amountMinor: 3335),
            Share(person: 'A', amountMinor: 3333),
            Share(person: 'B', amountMinor: 3333),
          ],
        ),
      ]);
      expect(state.balance('a'), 100000);
      expect(state.debts, {'A': -3335});
      expect(state.netWorthMinor, 96665);
    },
  );
  test(
    'borrowing and repaying affect cash and liabilities, never income/expense',
    () {
      final state = LedgerRules.append(initial(), [
        debt('l', EntryKind.borrowed, 50000, 'Riya'),
        debt('p', EntryKind.repaymentPaid, 20000, 'riya'),
      ]);
      expect(state.balance('a'), 130000);
      expect(state.debtFor('RIYA'), -30000);
      expect(state.netWorthMinor, 100000);
      expect(state.expenseFor(date), 0);
      expect(state.incomeFor(date), 0);
    },
  );
  test('a repayment cannot exceed or reverse a receivable', () {
    final state = LedgerRules.append(initial(), [
      debt('l', EntryKind.lent, 5000, 'A'),
    ]);
    expect(
      () => LedgerRules.append(state, [
        debt('r', EntryKind.repaymentReceived, 5001, 'A'),
      ]),
      throwsFormatException,
    );
    expect(
      () => LedgerRules.append(state, [
        debt('r', EntryKind.repaymentPaid, 1000, 'A'),
      ]),
      throwsFormatException,
    );
    final settled = LedgerRules.append(state, [
      debt('r', EntryKind.repaymentReceived, 5000, 'A'),
    ]);
    expect(settled.debts, isEmpty);
    expect(settled.netWorthMinor, 100000);
  });
  test('item splits and people splits each must conserve the total', () {
    expect(
      () => LedgerRules.append(initial(), [
        expense(shares: const [Share(person: 'You', amountMinor: 1)]),
      ]),
      throwsFormatException,
    );
    expect(
      () => LedgerRules.append(initial(), [
        expense(
          lines: const [
            LineItem(
              description: 'Wrong',
              amountMinor: 10000,
              category: 'Home',
              subcategory: 'Rent',
            ),
          ],
        ),
      ]),
      throwsFormatException,
    );
    expect(
      () => LedgerRules.append(initial(), [
        expense(
          shares: const [
            Share(person: 'You', amountMinor: 1),
            Share(person: 'A', amountMinor: 5000),
            Share(person: 'a', amountMinor: 5000),
          ],
        ),
      ]),
      throwsFormatException,
    );
  });
  test('model round trip preserves item allocation and person shares', () {
    final e = expense(shares: const [Share(person: 'You', amountMinor: 10001)]);
    expect(LedgerEntry.fromJson(e.toJson()).toJson(), e.toJson());
  });
  test('a bad second row never partially commits a batch', () async {
    final controller = LedgerController(MemoryLedgerRepository(initial()));
    await controller.load();
    expect(
      () => controller.addEntries([expense(), expense(id: 'bad', amount: 0)]),
      throwsFormatException,
    );
    expect(controller.state.entries, isEmpty);
    expect((await controller.repository.load()).entries, isEmpty);
  });
  test('write failure preserves the prior in-memory state', () async {
    final controller = LedgerController(FailingRepository(initial()));
    await controller.load();
    await expectLater(controller.addEntries([expense()]), throwsStateError);
    expect(controller.state.entries, isEmpty);
    expect(controller.saving, isFalse);
  });
  test('removing a loan supporting a repayment is rejected', () async {
    final controller = LedgerController(MemoryLedgerRepository(initial()));
    await controller.load();
    await controller.addEntries([
      debt('l', EntryKind.lent, 5000, 'A'),
      debt('p', EntryKind.repaymentReceived, 2000, 'A'),
    ]);
    expect(() => controller.deleteEntry('l'), throwsFormatException);
    expect(controller.state.entries.length, 2);
  });
  test('a second concurrent save cannot overwrite an in-flight save', () async {
    final repository = SlowRepository(initial());
    final controller = LedgerController(repository);
    await controller.load();
    final first = controller.addEntries([expense()]);
    await expectLater(
      controller.addEntries([expense(id: 'second')]),
      throwsStateError,
    );
    await first;
    expect(controller.state.entries.single.id, 'x');
  });
}

class FailingRepository extends MemoryLedgerRepository {
  FailingRepository(super.initial);
  @override
  Future<void> commit(LedgerState before, LedgerState after) async =>
      throw StateError('Disk full');
}

class SlowRepository extends MemoryLedgerRepository {
  SlowRepository(super.initial);
  @override
  Future<void> commit(LedgerState before, LedgerState after) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await super.commit(before, after);
  }
}
