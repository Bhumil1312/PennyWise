import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywise_mobile/application/ledger_controller.dart';
import 'package:pennywise_mobile/data/ledger_repository.dart';
import 'package:pennywise_mobile/domain/capture_parser.dart';
import 'package:pennywise_mobile/domain/models.dart';
import 'package:pennywise_mobile/domain/money.dart';

final eventDate = DateTime(2026, 1, 10, 12);
LedgerState bankAccounts() => LedgerState(
  accounts: const [
    Account(
      id: 'a',
      name: 'HDFC',
      type: 'Bank',
      openingMinor: 500000,
      lastFour: '1111',
      smsSender: 'HDFCBK',
    ),
    Account(
      id: 'b',
      name: 'ICICI',
      type: 'Bank',
      lastFour: '2222',
      smsSender: 'ICICIB',
    ),
  ],
);
ParsedCapture parsed({
  String key = 'sms-a',
  String source = 'bank_sms',
  int amount = 120000,
  String hint = '1111',
  EntryKind kind = EntryKind.expense,
  String? reference = 'UPI123456789',
  DateTime? date,
}) => ParsedCapture(
  source: source,
  description: 'Cafe payment',
  evidenceKey: key,
  amountMinor: amount,
  occurredAt: date ?? eventDate,
  kind: kind,
  accountHint: hint,
  reference: reference,
  merchant: 'Cafe',
  confidence: .98,
  suggestedCategory: 'Food & groceries',
  suggestedSubcategory: 'Dining out',
);
LedgerEntry reviewedExpense(LedgerEntry original) => original.copyWith(
  kind: EntryKind.expense,
  metadataPending: false,
  lines: [
    LineItem(
      description: 'Meal',
      amountMinor: original.amountMinor,
      category: 'Food & groceries',
      subcategory: 'Dining out',
    ),
  ],
);
Future<LedgerController> controller([LedgerRepository? repository]) async {
  final result = LedgerController(
    repository ?? MemoryLedgerRepository(bankAccounts()),
  );
  await result.load();
  return result;
}

void main() {
  test(
    'same reference from another source links evidence without reposting',
    () async {
      final c = await controller();
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      await c.stageCaptures([parsed(source: 'receipt')], accountId: 'a');
      expect(c.state.captures.length, 2);
      expect(c.state.entries.length, 1);
      expect(c.state.captures.last.status, CaptureStatus.linked);
      await c.dismissCapture(c.state.captures.first.id);
      expect(c.state.entries, isEmpty);
      expect(
        c.state.captures.every((e) => e.status == CaptureStatus.dismissed),
        isTrue,
      );
      expect(c.state.balance('a'), 500000);
    },
  );

  test('linking rejects an opposite direction movement', () async {
    final c = await controller();
    await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
    final entryId = c.state.entries.single.id;
    await c.stageCaptures([
      parsed(key: 'credit', kind: EntryKind.income, reference: 'OTHER'),
    ], accountId: 'a');
    expect(
      () => c.linkCapture(c.state.captures.last.id, entryId),
      throwsFormatException,
    );
    expect(c.state.balance('a'), 380000);
    expect(c.state.captures.last.status, CaptureStatus.pending);
  });
  test(
    'mapped bank debit changes balance immediately while metadata awaits review',
    () async {
      final c = await controller();
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      expect(c.state.balance('a'), 380000);
      expect(c.state.entries.single.kind, EntryKind.bankDebit);
      expect(c.state.entries.single.metadataPending, isTrue);
      expect(c.state.captures.single.status, CaptureStatus.posted);
      expect(c.state.reviewCount, 1);
      expect(c.state.expenseFor(eventDate), 0);
      expect(c.state.incomeFor(eventDate), 0);
    },
  );
  test(
    'metadata confirmation updates the original record without applying money twice',
    () async {
      final c = await controller();
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      final capture = c.state.captures.single,
          original = c.state.entries.single;
      await c.confirmCapture(capture.id, reviewedExpense(original));
      expect(c.state.entries.single.id, original.id);
      expect(c.state.balance('a'), 380000);
      expect(c.state.entries.single.metadataPending, isFalse);
      expect(c.state.expenseFor(eventDate), 120000);
      expect(c.state.captures.single.status, CaptureStatus.reviewed);
      expect(
        () => c.confirmCapture(capture.id, reviewedExpense(original)),
        throwsFormatException,
      );
      expect(c.state.entries.length, 1);
    },
  );
  test(
    'retry deduplicates a posted message even after reloading the repository',
    () async {
      final repository = MemoryLedgerRepository(bankAccounts());
      final c = await controller(repository);
      expect(
        await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true),
        1,
      );
      final restored = await controller(repository);
      expect(
        await restored.stageCaptures(
          [parsed()],
          sender: 'VM-HDFCBK',
          bankEvent: true,
        ),
        0,
      );
      expect(restored.state.entries.length, 1);
      expect(restored.state.balance('a'), 380000);
    },
  );
  test(
    'receipt with same reference attaches evidence to the captured movement',
    () async {
      final c = await controller();
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      final bankEntry = c.state.entries.single;
      await c.stageCaptures([
        parsed(key: 'receipt-a', source: 'receipt'),
      ], accountId: 'a');
      expect(c.state.entries.length, 1);
      expect(c.state.balance('a'), 380000);
      expect(c.state.captures.last.status, CaptureStatus.linked);
      expect(c.state.captures.last.linkedEntryId, bankEntry.id);
    },
  );
  test(
    'unknown or ambiguous bank account stays in review without a money movement',
    () async {
      final c = await controller();
      await c.stageCaptures(
        [parsed(hint: '9999')],
        sender: 'VM-HDFCBK',
        bankEvent: true,
      );
      expect(c.state.entries, isEmpty);
      expect(c.state.captures.single.status, CaptureStatus.pending);
      expect(c.state.captures.single.accountId, isNull);
      expect(c.state.balance('a'), 500000);
      final ambiguous = await controller(
        MemoryLedgerRepository(
          LedgerState(
            accounts: const [
              Account(
                id: 'a',
                name: 'One',
                type: 'Bank',
                lastFour: '1111',
                smsSender: 'HDFCBK',
              ),
              Account(
                id: 'b',
                name: 'Two',
                type: 'Bank',
                lastFour: '1111',
                smsSender: 'HDFCBK',
              ),
            ],
          ),
        ),
      );
      await ambiguous.stageCaptures(
        [parsed()],
        sender: 'VM-HDFCBK',
        bankEvent: true,
      );
      expect(ambiguous.state.entries, isEmpty);
      expect(ambiguous.state.captures.single.accountId, isNull);
    },
  );
  test(
    'own-account transfer collapses two captured SMS legs to one transfer',
    () async {
      final c = await controller();
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      await c.stageCaptures(
        [parsed(key: 'sms-b', hint: '2222', kind: EntryKind.income)],
        sender: 'VM-ICICIB',
        bankEvent: true,
      );
      final debit = c.state.entries.first,
          debitCapture = c.state.captures.first;
      expect(c.state.balance('a'), 380000);
      expect(c.state.balance('b'), 120000);
      expect(c.state.cashMinor, 500000);
      final transfer = LedgerEntry(
        id: debit.id,
        kind: EntryKind.transfer,
        accountId: 'a',
        toAccountId: 'b',
        amountMinor: 120000,
        date: eventDate,
        description: 'Savings transfer',
        source: 'bank_sms',
        sourceKey: debit.sourceKey,
        externalReference: debit.externalReference,
      );
      await c.confirmCapture(debitCapture.id, transfer);
      expect(c.state.entries.length, 1);
      expect(c.state.entries.single.kind, EntryKind.transfer);
      expect(c.state.balance('a'), 380000);
      expect(c.state.balance('b'), 120000);
      expect(c.state.cashMinor, 500000);
      expect(
        c.state.captures.every(
          (capture) =>
              capture.status == CaptureStatus.reviewed &&
              capture.linkedEntryId == debit.id,
        ),
        isTrue,
      );
      expect(c.state.incomeFor(eventDate), 0);
      expect(c.state.expenseFor(eventDate), 0);
    },
  );
  test(
    'same amount on same day with distinct bank references posts both real debits',
    () async {
      final c = await controller();
      await c.stageCaptures(
        [parsed(reference: 'REF001')],
        sender: 'VM-HDFCBK',
        bankEvent: true,
      );
      await c.stageCaptures(
        [parsed(key: 'second', reference: 'REF002')],
        sender: 'VM-HDFCBK',
        bankEvent: true,
      );
      expect(c.state.entries.length, 2);
      expect(c.state.balance('a'), 260000);
    },
  );
  test(
    'repeated bank reference with changed amount becomes discrepancy review, not another debit',
    () async {
      final c = await controller();
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      await c.stageCaptures(
        [parsed(key: 'changed-export', amount: 125000)],
        sender: 'VM-HDFCBK',
        bankEvent: true,
      );
      expect(c.state.entries.length, 1);
      expect(c.state.balance('a'), 380000);
      expect(c.state.captures.last.status, CaptureStatus.pending);
      expect(
        c.state.captures.last.possibleDuplicateEntryId,
        c.state.entries.single.id,
      );
    },
  );
  test(
    'bank SMS arriving after a recorded own-account transfer links without duplicating either leg',
    () async {
      final c = await controller();
      await c.addEntries([
        LedgerEntry(
          id: 'manual-transfer',
          kind: EntryKind.transfer,
          accountId: 'a',
          toAccountId: 'b',
          amountMinor: 120000,
          date: eventDate,
          description: 'Recorded transfer',
          externalReference: 'UPI123456789',
        ),
      ]);
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      await c.stageCaptures(
        [
          parsed(
            key: 'credit-after-transfer',
            hint: '2222',
            kind: EntryKind.income,
          ),
        ],
        sender: 'VM-ICICIB',
        bankEvent: true,
      );
      expect(c.state.entries.length, 1);
      expect(c.state.balance('a'), 380000);
      expect(c.state.balance('b'), 120000);
      expect(
        c.state.captures.every(
          (capture) =>
              capture.linkedEntryId == 'manual-transfer' &&
              capture.status == CaptureStatus.linked,
        ),
        isTrue,
      );
    },
  );
  test(
    'a merely linked receipt cannot dismiss the primary posted bank movement',
    () async {
      final c = await controller();
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      await c.stageCaptures([
        parsed(key: 'receipt', source: 'receipt'),
      ], accountId: 'a');
      expect(
        () => c.dismissCapture(c.state.captures.last.id),
        throwsFormatException,
      );
      expect(c.state.entries.length, 1);
      expect(c.state.balance('a'), 380000);
    },
  );
  test(
    'unposted capture cannot overwrite an unrelated transaction ID during confirmation',
    () async {
      final c = await controller();
      await c.addEntries([
        LedgerEntry(
          id: 'existing',
          kind: EntryKind.income,
          accountId: 'a',
          amountMinor: 50000,
          date: eventDate,
          description: 'Salary',
          lines: const [
            LineItem(
              description: 'Salary',
              amountMinor: 50000,
              category: 'Income',
              subcategory: 'Salary',
            ),
          ],
        ),
      ]);
      await c.stageCaptures([
        parsed(key: 'draft', source: 'receipt'),
      ], accountId: 'a');
      final fake = LedgerEntry(
        id: 'existing',
        kind: EntryKind.expense,
        accountId: 'a',
        amountMinor: 120000,
        date: eventDate,
        description: 'Receipt',
        lines: const [
          LineItem(
            description: 'Meal',
            amountMinor: 120000,
            category: 'Food & groceries',
            subcategory: 'Dining out',
          ),
        ],
      );
      expect(
        () => c.confirmCapture(c.state.captures.single.id, fake),
        throwsFormatException,
      );
      expect(c.state.entries.single.kind, EntryKind.income);
      expect(c.state.balance('a'), 550000);
    },
  );
  test(
    'invalid batch cannot partially commit a bank movement or capture',
    () async {
      final c = await controller();
      await expectLater(
        c.stageCaptures(
          [
            parsed(),
            parsed(
              key: 'invalid',
              reference: 'TOO-LARGE',
              amount: maxMinor + 1,
            ),
          ],
          sender: 'VM-HDFCBK',
          bankEvent: true,
        ),
        throwsFormatException,
      );
      expect(c.state.entries, isEmpty);
      expect(c.state.captures, isEmpty);
      expect(c.state.balance('a'), 500000);
    },
  );
  test(
    'concurrent capture save is rejected safely and can be retried without lost writes',
    () async {
      final repository = GatedRepository(bankAccounts()),
          c = await controller(repository);
      final first = c.stageCaptures(
        [parsed(reference: 'FIRST')],
        sender: 'VM-HDFCBK',
        bankEvent: true,
      );
      try {
        await expectLater(
          c.stageCaptures(
            [parsed(key: 'second', reference: 'SECOND', amount: 10000)],
            sender: 'VM-HDFCBK',
            bankEvent: true,
          ),
          throwsStateError,
        );
      } finally {
        repository.gate.complete();
      }
      await first;
      expect(c.state.entries.length, 1);
      await c.stageCaptures(
        [parsed(key: 'second', reference: 'SECOND', amount: 10000)],
        sender: 'VM-HDFCBK',
        bankEvent: true,
      );
      expect(c.state.entries.length, 2);
      expect(c.state.balance('a'), 370000);
    },
  );
  test(
    'failed storage commit preserves prior state and makes retry safe',
    () async {
      final repository = FailOnceRepository(bankAccounts()),
          c = await controller(repository);
      await expectLater(
        c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true),
        throwsStateError,
      );
      expect(c.state.entries, isEmpty);
      expect(c.state.captures, isEmpty);
      expect(c.saving, isFalse);
      await c.stageCaptures([parsed()], sender: 'VM-HDFCBK', bankEvent: true);
      expect(c.state.entries.length, 1);
      expect(c.state.balance('a'), 380000);
    },
  );
}

class GatedRepository extends MemoryLedgerRepository {
  GatedRepository(super.initial);
  final gate = Completer<void>();
  @override
  Future<void> commit(LedgerState before, LedgerState after) async {
    await gate.future;
    await super.commit(before, after);
  }
}

class FailOnceRepository extends MemoryLedgerRepository {
  FailOnceRepository(super.initial);
  bool fail = true;
  @override
  Future<void> commit(LedgerState before, LedgerState after) async {
    if (fail) {
      fail = false;
      throw StateError('Disk full');
    }
    await super.commit(before, after);
  }
}
