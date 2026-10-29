import 'package:flutter_test/flutter_test.dart';
import 'package:pennywise_mobile/domain/capture_parser.dart';
import 'package:pennywise_mobile/domain/models.dart';

void main() {
  final received = DateTime(2026, 10, 27, 12, 30);
  test('bank debit selects transaction amount instead of available balance', () {
    final v = parseBankSms(
      'Your A/c XX1234 debited by INR 1,250.50 at ZOMATO on 26-10-2026. UPI Ref No 123456789012. Avl Bal INR 54,600.25.',
      sender: 'VM-HDFCBK',
      receivedAt: received,
    )!;
    expect(v.amountMinor, 125050);
    expect(v.kind, EntryKind.expense);
    expect(v.accountHint, '1234');
    expect(v.reference, '123456789012');
    expect(v.merchant, 'ZOMATO');
    expect(v.occurredAt, DateTime(2026, 10, 26));
    expect(v.suggestedSubcategory, 'Delivery');
  });
  test('amount before debit verb is supported', () {
    final v = parseBankSms(
      'Rs.500.00 has been debited from a/c *6789 on 27/10/26. Ref 987654321. Available balance Rs.20,000.00',
      sender: 'AD-ICICIB',
      receivedAt: received,
    )!;
    expect(v.amountMinor, 50000);
    expect(v.accountHint, '6789');
    expect(v.kind, EntryKind.expense);
  });
  test(
    'a balance-only amount after a debit verb is not a transaction amount',
    () {
      expect(
        parseBankSms(
          'Account 1234 debited. Bal INR 2000. Ref 987654.',
          sender: 'VM-BANK',
          receivedAt: received,
        ),
        isNull,
      );
    },
  );
  test('credit alert is classified by movement and salary narration', () {
    final v = parseBankSms(
      'Salary INR 95,000 credited to account ending in 4321 on 27-Oct-2026. UTR ABC123456. Avl Bal Rs 1,20,000.',
      sender: 'AX-SBIINB',
      receivedAt: received,
    )!;
    expect(v.amountMinor, 9500000);
    expect(v.kind, EntryKind.income);
    expect(v.suggestedCategory, 'Income');
    expect(v.accountHint, '4321');
    expect(v.occurredAt, DateTime(2026, 10, 27));
  });
  test('OTP, promotional, failed and not-yet-posted messages are ignored', () {
    for (final body in [
      'OTP 123456 for debit of INR 500 from A/c 1234. Do not share.',
      'INR 500 will be debited from account 1234 tomorrow.',
      'Your payment of Rs.500 from account 1234 failed.',
      'Pending debit INR 500 from account 1234.',
      'Special offer: spend INR 500 on your card 1234.',
      'Your credit card 1234 statement balance is INR 500.',
    ]) {
      expect(
        parseBankSms(body, sender: 'VM-BANK', receivedAt: received),
        isNull,
        reason: body,
      );
    }
  });
  test('foreign amounts are never interpreted as rupees', () {
    expect(
      parseBankSms(
        'USD 12.50 spent at CAFE on card 1234. Ref 987654.',
        sender: 'VM-BANK',
        receivedAt: received,
      ),
      isNull,
    );
    final receipt = parseReceiptText(
      'Cafe\n26-10-2026\nTotal USD 12.00',
      now: received,
    );
    expect(receipt.amountMinor, isNull);
    expect(receipt.questions.join(' '), contains('another currency'));
  });
  test('invalid bank dates remain unresolved', () {
    final v = parseBankSms(
      'A/c 1234 debited INR 500 on 31-02-2026 Ref 987654.',
      sender: 'VM-BANK',
      receivedAt: received,
    )!;
    expect(v.occurredAt, isNull);
    expect(v.questions.join(' '), contains('invalid date'));
  });
  test('missing bank date uses clearly labelled message receipt time', () {
    final v = parseBankSms(
      'A/c 1234 debited INR 500. Ref 987654.',
      sender: 'VM-BANK',
      receivedAt: received,
    )!;
    expect(v.occurredAt, received);
    expect(v.questions.join(' '), contains('receipt time'));
  });
  test('reference identity survives source and wording differences', () {
    final a = parseBankSms(
      'A/c 1234 debited INR 500 on 27-10-2026 Ref 987654.',
      sender: 'VM-BANK',
      receivedAt: received,
    )!;
    final b = parseBankSms(
      'Rs.500 debited from account 1234 on 27/10/2026. Reference 987654. Available balance INR 4000.',
      sender: 'AD-BANK',
      receivedAt: received,
    )!;
    final c = parseStatementText(
      'Account XX1234\n27/10/2026 UPI/DR/987654/ZOMATO 500.00 DR 4000.00',
      now: received,
    ).single;
    expect(a.evidenceKey, b.evidenceKey);
    expect(a.evidenceKey, c.evidenceKey);
  });
  test('receipt uses grand total rather than subtotal, cash or change', () {
    final v = parseReceiptText(
      'Cafe Gusto\nDate: 26/10/2026\nCoffee 200.00\nSandwich 300.00\nSubtotal 500.00\nCGST 2.5% 12.50\nSGST 2.5% 12.50\nGrand Total 525.00\nCash 1000.00\nChange 475.00',
      now: received,
    );
    expect(v.amountMinor, 52500);
    expect(v.merchant, 'Cafe Gusto');
    expect(v.items.length, 4);
    expect(v.items.fold(0, (sum, item) => sum + item.amountMinor), 52500);
    expect(v.items.where((item) => item.subcategory == 'Tax').length, 2);
  });
  test('conflicting receipt totals require correction', () {
    final v = parseReceiptText(
      'Store\n26-10-2026\nGrand Total 100.00\nGrand Total 180.00',
      now: received,
    );
    expect(v.amountMinor, isNull);
    expect(v.questions.join(' '), contains('different totals'));
  });
  test(
    'receipt allocations are not invented when discounts cause a mismatch',
    () {
      final v = parseReceiptText(
        'Store\n26-10-2026\nGrocery 100.00\nDiscount -10.00\nTotal 90.00',
        now: received,
      );
      expect(v.amountMinor, 9000);
      expect(v.items, isEmpty);
      expect(v.questions.join(' '), contains('do not equal'));
    },
  );
  test('a bare receipt date cannot become an item amount', () {
    final v = parseReceiptText(
      'Cafe Gusto\n26/10/2026\nCoffee 100.00\nTotal 100.00',
      now: received,
    );
    expect(v.items.length, 1);
    expect(v.items.single.amountMinor, 10000);
  });
  test('missing receipt date and total are never invented', () {
    final v = parseReceiptText('Store\nCoffee 100.00\nTax 5.00', now: received);
    expect(v.amountMinor, isNull);
    expect(v.occurredAt, isNull);
    expect(v.questions.join(' '), contains('No labelled total'));
  });
  test('statement debit and credit columns distinguish amounts from balance', () {
    final v = parseStatementText(
      'Account XX1234\nDate\tDescription\tDebit\tCredit\tBalance\n26/10/2026\tZomato\t500.00\t\t4000.00\n27/10/2026\tSalary\t-\t95000.00\t99000.00',
      now: received,
    );
    expect(v.length, 2);
    expect(v[0].amountMinor, 50000);
    expect(v[0].kind, EntryKind.expense);
    expect(v[1].amountMinor, 9500000);
    expect(v[1].kind, EntryKind.income);
    expect(v[1].description, 'Salary');
  });
  test(
    'single-space OCR statement retains explicit debit/credit placeholders',
    () {
      final v = parseStatementText(
        'Date Description Debit Credit Balance\n26/10/2026 ZOMATO 500.00 - 4000.00\n27/10/2026 SALARY - 95000.00 99000.00',
        now: received,
      );
      expect(v[0].kind, EntryKind.expense);
      expect(v[0].amountMinor, 50000);
      expect(v[1].kind, EntryKind.income);
      expect(v[1].amountMinor, 9500000);
    },
  );
  test('statement row without reliable direction remains unresolved', () {
    final v = parseStatementText(
      '26/10/2026 Some purchase 500.00 4000.00',
      now: received,
    ).single;
    expect(v.kind, isNull);
    expect(v.amountMinor, isNull);
    expect(v.questions.join(' '), contains('debit or credit'));
  });
  test('conflicting debit and credit columns cannot fall back to narration', () {
    final v = parseStatementText(
      'Date\tDescription\tDebit\tCredit\tBalance\n26/10/2026\tUPI/DR/987654/ZOMATO\t500.00\t100.00\t4000.00',
      now: received,
    ).single;
    expect(v.amountMinor, isNull);
    expect(v.kind, isNull);
    expect(v.questions.join(' '), contains('Both debit and credit'));
  });
  test('opening balances and undated narration do not become transactions', () {
    expect(
      parseStatementText(
        'Account 1234\nOpening Balance 4000.00\n26/10/2026 Opening Balance 4000.00\nZomato debit 500.00',
        now: received,
      ),
      isEmpty,
    );
  });
  test('future and impossible statement dates are held for review', () {
    final v = parseStatementText(
      '31/02/2026 ZOMATO 500.00 DR\n28/10/2026 ZOMATO 500.00 DR',
      now: received,
    );
    expect(v.length, 2);
    expect(v.every((capture) => capture.occurredAt == null), isTrue);
  });
  test('merchant rules distinguish known context from unknown people', () {
    expect(inferCategory('payment to UBER').subcategory, 'Cab');
    expect(
      inferCategory('SBI salary credit', kind: EntryKind.income).subcategory,
      'Salary',
    );
    expect(inferCategory('UNKNOWN-UPI-PERSON').subcategory, 'Uncategorised');
    expect(
      inferCategory('Zomato refund', kind: EntryKind.income).category,
      'Income',
    );
  });
  test('serialization preserves allocations and nullable fields', () {
    final v = parseReceiptText(
      'Cafe Gusto\n26-10-2026\nCoffee 100.00\nTotal 100.00',
      now: received,
    );
    expect(ParsedCapture.fromJson(v.toJson()).toJson(), v.toJson());
    expect(v.copyWith(amountMinor: null, occurredAt: null).amountMinor, isNull);
    expect(v.copyWith(amountMinor: null, occurredAt: null).occurredAt, isNull);
    expect(() => v.questions.add('mutate'), throwsUnsupportedError);
  });
}
