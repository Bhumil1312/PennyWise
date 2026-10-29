import 'package:flutter_test/flutter_test.dart';
import 'package:pennywise_mobile/domain/import_parser.dart';
import 'package:pennywise_mobile/domain/ledger.dart';
import 'package:pennywise_mobile/domain/models.dart';

void main() {
  test(
    'description extracts a reviewable amount, category, date and people',
    () {
      final d = parseDescription(
        'Paid ₹1,200 for dinner with Aarav and Meera',
        now: DateTime(2026, 1, 5),
      );
      expect(d.amountMinor, 120000);
      expect(d.category, 'Food & groceries');
      expect(d.people, ['Aarav', 'Meera']);
      expect(d.date, DateTime(2026, 1, 5));
      expect(d.questions, isNotEmpty);
    },
  );
  test('ambiguous amounts produce a question instead of an invented total', () {
    final d = parseDescription('Paid 200 for 2 coffees');
    expect(d.amountMinor, isNull);
    expect(d.questions.first, contains('total amount'));
  });
  test(
    'invalid dates are rejected instead of normalised into another month',
    () {
      expect(() => parseDate('2026-02-30'), throwsFormatException);
      expect(() => parseDate('01/02/2026'), throwsFormatException);
      expect(parseDate('2024-02-29'), DateTime(2024, 2, 29));
    },
  );
  test('CSV handles quoted commas, escaped quotes and CRLF', () {
    final d = parseStatementCsv(
      'date,description,amount,type,reference\r\n2026-01-01,"Dinner, \'A\'",1200,expense,ref1\r\n',
      accountId: 'bank',
    );
    expect(d.single.description, "Dinner, 'A'");
    expect(d.single.amountMinor, 120000);
    expect(readCsv('a,b\n"one""two","line1\nline2"')[1], [
      'one"two',
      'line1\nline2',
    ]);
  });
  test('overlapping bank exports deduplicate by reference and account', () {
    const one =
        'date,description,amount,type,reference\n2026-01-01,Dinner,1200,expense,abc';
    const two =
        'date,description,amount,type,reference\n2026-01-01,Dinner revised,1200,expense,abc';
    final a = parseStatementCsv(one, accountId: 'bank').single;
    final b = parseStatementCsv(two, accountId: 'bank').single;
    expect(a.sourceKey, b.sourceKey);
    expect(
      a.sourceKey,
      isNot(parseStatementCsv(one, accountId: 'cash').single.sourceKey),
    );
  });
  test('re-importing the exact same row is blocked by ledger rules', () {
    final d = parseStatementCsv(
      'date,description,amount,type\n2026-01-01,Coffee,100,expense',
      accountId: 'a',
    ).single;
    LedgerEntry entry(String id) => LedgerEntry(
      id: id,
      kind: d.kind,
      accountId: 'a',
      amountMinor: d.amountMinor!,
      date: d.date!,
      description: d.description,
      sourceKey: d.sourceKey,
      lines: [
        LineItem(
          description: d.description,
          amountMinor: d.amountMinor!,
          category: d.category,
          subcategory: d.subcategory,
        ),
      ],
    );
    final state = LedgerRules.append(
      LedgerState(
        accounts: const [Account(id: 'a', name: 'Bank', type: 'Bank')],
      ),
      [entry('one')],
    );
    expect(
      () => LedgerRules.append(state, [entry('two')]),
      throwsFormatException,
    );
  });
  test('malformed statement fails with a row-specific explanation', () {
    expect(
      () => parseStatementCsv(
        'date,description,amount,type\n2026-02-30,Food,100,expense',
        accountId: 'a',
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Row 2'),
        ),
      ),
    );
    expect(() => readCsv('a,b\n"unclosed,foo'), throwsFormatException);
    expect(
      () => parseStatementCsv(
        'date,description,amount,type\n2026-01-01,Transfer,100,transfer',
        accountId: 'a',
      ),
      throwsFormatException,
    );
  });
}
