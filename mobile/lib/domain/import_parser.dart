import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'models.dart';
import 'money.dart';

class TransactionDraft {
  const TransactionDraft({
    required this.description,
    this.amountMinor,
    this.date,
    this.kind = EntryKind.expense,
    this.category = 'Other',
    this.subcategory = 'Uncategorised',
    this.people = const [],
    this.questions = const [],
    this.sourceKey,
    this.source = 'description',
  });
  final String description, category, subcategory, source;
  final int? amountMinor;
  final DateTime? date;
  final EntryKind kind;
  final List<String> people, questions;
  final String? sourceKey;
}

/// A deliberately bounded, local parser. Uncertainty stays visible in review.
TransactionDraft parseDescription(
  String text, {
  DateTime? now,
  String source = 'description',
}) {
  final lower = text.toLowerCase();
  final questions = <String>[];
  final explicit = RegExp(
    r'(?:₹|rs\.?\s*|inr\s*)([\d,]+(?:\.\d{1,2})?)(?![\d.])',
    caseSensitive: false,
  ).allMatches(text).toList();
  final bare = RegExp(
    r'(?<![\d./-])\b\d+(?:,\d+)*(?:\.\d{1,2})?\b(?![\d./-])',
  ).allMatches(text).toList();
  int? amount;
  try {
    if (explicit.length == 1) {
      amount = parseMoney(explicit.single.group(1)!);
    } else if (explicit.isEmpty && bare.length == 1) {
      amount = parseMoney(bare.single.group(0)!);
    }
  } on FormatException {
    amount = null;
  }
  if (amount == null || amount <= 0) {
    questions.add('What was the total amount? Multiple numbers need review.');
  }
  var category = 'Other', subcategory = 'Uncategorised';
  final rules = <(RegExp, String, String)>[
    (
      RegExp(r'\b(grocery|groceries|supermarket|vegetables)\b'),
      'Food & groceries',
      'Groceries',
    ),
    (
      RegExp(r'\b(dinner|lunch|breakfast|restaurant|food)\b'),
      'Food & groceries',
      'Dining out',
    ),
    (RegExp(r'\b(coffee|tea|cafe)\b'), 'Food & groceries', 'Tea & coffee'),
    (RegExp(r'\b(uber|ola|cab|taxi)\b'), 'Transport', 'Cab'),
    (RegExp(r'\b(petrol|diesel|fuel)\b'), 'Transport', 'Fuel'),
    (RegExp(r'\brent\b'), 'Home', 'Rent'),
    (RegExp(r'\b(electricity|power bill)\b'), 'Home', 'Electricity'),
    (RegExp(r'\b(salary|payroll)\b'), 'Income', 'Salary'),
  ];
  for (final rule in rules) {
    if (rule.$1.hasMatch(lower)) {
      category = rule.$2;
      subcategory = rule.$3;
      break;
    }
  }
  var kind =
      category == 'Income' || RegExp(r'\b(received|earned)\b').hasMatch(lower)
      ? EntryKind.income
      : EntryKind.expense;
  if (kind == EntryKind.income && category != 'Income') {
    category = 'Income';
    subcategory = 'Other';
  }
  if (RegExp(
    r'\b(lent|borrowed|loan|transfer|repayment|refund)\b',
  ).hasMatch(lower)) {
    questions.add(
      'Confirm the transaction type. Loans, refunds and transfers need manual classification.',
    );
  }
  if (category == 'Other') {
    questions.add('Which category describes this transaction?');
  }
  final people = <String>[];
  final withMatch = RegExp(
    r'\bwith\s+([a-zA-Z ,&]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (withMatch != null && kind == EntryKind.expense) {
    people.addAll(
      withMatch
          .group(1)!
          .split(RegExp(r',|\band\b|&', caseSensitive: false))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && personKey(s) != 'you'),
    );
    questions.add(
      'Confirm who paid and each person’s share. An equal split is suggested.',
    );
  }
  final today = now ?? DateTime.now();
  DateTime? date = DateTime(
    today.year,
    today.month,
    today.day - (lower.contains('yesterday') ? 1 : 0),
  );
  final iso = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(text);
  if (iso != null) {
    try {
      date = parseDate(iso.group(0)!);
    } on FormatException {
      date = null;
      questions.add('What was the transaction date?');
    }
  } else if (!RegExp(r'\b(today|yesterday)\b').hasMatch(lower)) {
    questions.add('Date defaults to today. Confirm or change it.');
  }
  return TransactionDraft(
    description: text.trim(),
    amountMinor: amount,
    date: date,
    kind: kind,
    category: category,
    subcategory: subcategory,
    people: people,
    questions: questions,
    source: source,
  );
}

DateTime parseDate(String text) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
  if (match == null) throw const FormatException('Dates must use YYYY-MM-DD.');
  final year = int.parse(match[1]!),
      month = int.parse(match[2]!),
      day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (year < 1900 ||
      date.year != year ||
      date.month != month ||
      date.day != day) {
    throw const FormatException('Invalid calendar date.');
  }
  return date;
}

/// RFC-style quoted CSV fields, including embedded commas and newlines.
List<List<String>> readCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[], field = StringBuffer(), quoted = false, closed = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      if (field.isNotEmpty || closed) {
        throw const FormatException('Invalid CSV quoting.');
      }
      quoted = true;
    } else if (c == ',' || c == '\n' || c == '\r') {
      row.add(field.toString());
      field = StringBuffer();
      closed = false;
      if (c != ',') {
        if (row.any((s) => s.trim().isNotEmpty)) rows.add(row);
        row = [];
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      }
    } else {
      if (closed) {
        throw const FormatException(
          'Unexpected text after a quoted CSV field.',
        );
      }
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('Unclosed CSV quote.');
  row.add(field.toString());
  if (row.any((s) => s.trim().isNotEmpty)) rows.add(row);
  return rows;
}

List<TransactionDraft> parseStatementCsv(
  String text, {
  required String accountId,
}) {
  if (utf8.encode(text).length > 2 * 1024 * 1024) {
    throw const FormatException('Choose a CSV smaller than 2 MB.');
  }
  final rows = readCsv(text.replaceFirst('\uFEFF', ''));
  if (rows.length < 2 || rows.length > 2001) {
    throw const FormatException('Import between 1 and 2,000 transaction rows.');
  }
  final header = rows.first.map((s) => s.trim().toLowerCase()).toList();
  if (header.toSet().length != header.length) {
    throw const FormatException('CSV column names must be unique.');
  }
  for (final name in ['date', 'description', 'amount', 'type']) {
    if (!header.contains(name)) {
      throw FormatException(
        'Missing CSV column: $name. Use the supplied template.',
      );
    }
  }
  final documentHash = sha256.convert(utf8.encode(text)).toString();
  final output = <TransactionDraft>[];
  for (var index = 1; index < rows.length; index++) {
    final values = rows[index];
    if (values.length != header.length) {
      throw FormatException(
        'Row ${index + 1}: column count does not match the header.',
      );
    }
    String get(String key) =>
        header.contains(key) ? values[header.indexOf(key)].trim() : '';
    try {
      final date = parseDate(get('date'));
      final type = get('type').toLowerCase();
      if (type != 'income' && type != 'expense') {
        throw const FormatException(
          'Type must be income or expense. Transfers need manual entry.',
        );
      }
      final amount = parseMoney(get('amount'));
      if (amount <= 0 || get('description').isEmpty) {
        throw const FormatException(
          'A positive amount and description are required.',
        );
      }
      final inferred = parseDescription(get('description'));
      final category = get('category').isNotEmpty
          ? get('category')
          : type == 'income'
          ? 'Income'
          : inferred.category;
      final subcategory = get('subcategory').isNotEmpty
          ? get('subcategory')
          : type == 'income'
          ? 'Other'
          : inferred.subcategory;
      if (categories[category]?.contains(subcategory) != true) {
        throw const FormatException('Unknown category/subcategory.');
      }
      // Bank reference deduplicates overlapping exports; file + row is the fallback.
      final source = get('reference').isEmpty
          ? '$documentHash:$index'
          : 'reference:${get('reference')}';
      output.add(
        TransactionDraft(
          description: get('description'),
          amountMinor: amount,
          date: date,
          kind: type == 'income' ? EntryKind.income : EntryKind.expense,
          category: category,
          subcategory: subcategory,
          sourceKey: sha256
              .convert(utf8.encode('$accountId:$source'))
              .toString(),
          source: 'csv',
        ),
      );
    } on FormatException catch (e) {
      throw FormatException('Row ${index + 1}: ${e.message}');
    }
  }
  return output;
}
