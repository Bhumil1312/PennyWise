import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';
import 'money.dart';

const _notProvided = Object();

/// A source observation. Missing or ambiguous fields remain unresolved.
class ParsedCapture {
  ParsedCapture({
    required this.source,
    required this.description,
    required this.evidenceKey,
    this.amountMinor,
    this.occurredAt,
    this.kind,
    this.merchant,
    this.accountHint,
    this.reference,
    this.suggestedCategory = 'Other',
    this.suggestedSubcategory = 'Uncategorised',
    List<String> questions = const [],
    List<LineItem> items = const [],
    this.confidence = 0,
    this.isFinancialTransaction = true,
  }) : questions = List.unmodifiable(questions),
       items = List.unmodifiable(items);
  final String source,
      description,
      evidenceKey,
      suggestedCategory,
      suggestedSubcategory;
  final int? amountMinor;
  final DateTime? occurredAt;
  final EntryKind? kind;
  final String? merchant, accountHint, reference;
  final List<String> questions;
  final List<LineItem> items;
  final double confidence;
  final bool isFinancialTransaction;
  ParsedCapture copyWith({
    String? source,
    String? description,
    String? evidenceKey,
    Object? amountMinor = _notProvided,
    Object? occurredAt = _notProvided,
    Object? kind = _notProvided,
    Object? merchant = _notProvided,
    Object? accountHint = _notProvided,
    Object? reference = _notProvided,
    String? suggestedCategory,
    String? suggestedSubcategory,
    List<String>? questions,
    List<LineItem>? items,
    double? confidence,
    bool? isFinancialTransaction,
  }) => ParsedCapture(
    source: source ?? this.source,
    description: description ?? this.description,
    evidenceKey: evidenceKey ?? this.evidenceKey,
    amountMinor: identical(amountMinor, _notProvided)
        ? this.amountMinor
        : amountMinor as int?,
    occurredAt: identical(occurredAt, _notProvided)
        ? this.occurredAt
        : occurredAt as DateTime?,
    kind: identical(kind, _notProvided) ? this.kind : kind as EntryKind?,
    merchant: identical(merchant, _notProvided)
        ? this.merchant
        : merchant as String?,
    accountHint: identical(accountHint, _notProvided)
        ? this.accountHint
        : accountHint as String?,
    reference: identical(reference, _notProvided)
        ? this.reference
        : reference as String?,
    suggestedCategory: suggestedCategory ?? this.suggestedCategory,
    suggestedSubcategory: suggestedSubcategory ?? this.suggestedSubcategory,
    questions: questions ?? this.questions,
    items: items ?? this.items,
    confidence: confidence ?? this.confidence,
    isFinancialTransaction:
        isFinancialTransaction ?? this.isFinancialTransaction,
  );
  Map<String, dynamic> toJson() => {
    'source': source,
    'description': description,
    'evidenceKey': evidenceKey,
    'amountMinor': amountMinor,
    'occurredAt': occurredAt?.toIso8601String(),
    'kind': kind?.name,
    'merchant': merchant,
    'accountHint': accountHint,
    'reference': reference,
    'suggestedCategory': suggestedCategory,
    'suggestedSubcategory': suggestedSubcategory,
    'questions': questions,
    'items': items.map((item) => item.toJson()).toList(),
    'confidence': confidence,
    'isFinancialTransaction': isFinancialTransaction,
  };
  factory ParsedCapture.fromJson(Map<String, dynamic> j) => ParsedCapture(
    source: j['source'],
    description: j['description'],
    evidenceKey: j['evidenceKey'],
    amountMinor: j['amountMinor'],
    occurredAt: j['occurredAt'] == null
        ? null
        : DateTime.parse(j['occurredAt']),
    kind: j['kind'] == null ? null : EntryKind.values.byName(j['kind']),
    merchant: j['merchant'],
    accountHint: j['accountHint'],
    reference: j['reference'],
    suggestedCategory: j['suggestedCategory'] ?? 'Other',
    suggestedSubcategory: j['suggestedSubcategory'] ?? 'Uncategorised',
    questions: (j['questions'] as List? ?? const []).cast<String>(),
    items: (j['items'] as List? ?? const [])
        .map((item) => LineItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    confidence: (j['confidence'] as num? ?? 0).toDouble(),
    isFinancialTransaction: j['isFinancialTransaction'] ?? true,
  );
}

/// Explainable local rules; no capture is sent to an external AI service.
({String category, String subcategory, double confidence}) inferCategory(
  String description, {
  EntryKind? kind,
}) {
  final text = description.toLowerCase();
  final rules = <(String, String, String, double)>[
    (r'\b(salary|payroll)\b', 'Income', 'Salary', .96),
    (r'\b(dividend|dividends)\b', 'Income', 'Dividends', .94),
    (
      r'\b(interest credited|interest earned|deposit interest)\b',
      'Income',
      'Interest',
      .9,
    ),
    (r'\b(freelance|freelancing)\b', 'Income', 'Freelance', .9),
    (
      r'\b(grocer(?:y|ies)|supermarket|vegetables|bigbasket|blinkit|zepto|dmart|d-mart)\b',
      'Food & groceries',
      'Groceries',
      .91,
    ),
    (r'\b(swiggy|zomato|food delivery)\b', 'Food & groceries', 'Delivery', .93),
    (
      r'\b(coffee|cafe|café|starbucks|tea)\b',
      'Food & groceries',
      'Tea & coffee',
      .88,
    ),
    (
      r'\b(dinner|lunch|breakfast|restaurant|dining|pizza|dominos|mcdonalds)\b',
      'Food & groceries',
      'Dining out',
      .86,
    ),
    (r'\b(uber|ola|taxi|cab|rapido)\b', 'Transport', 'Cab', .9),
    (
      r'\b(petrol|diesel|fuel|indianoil|bharat petroleum|hindustan petroleum)\b',
      'Transport',
      'Fuel',
      .92,
    ),
    (
      r'\b(metro|bus fare|train ticket|irctc)\b',
      'Transport',
      'Public transport',
      .85,
    ),
    (r'\b(rent|rental payment)\b', 'Home', 'Rent', .86),
    (
      r'\b(electricity|power bill|electric bill|bescom|mseb|torrent power)\b',
      'Home',
      'Electricity',
      .92,
    ),
    (r'\b(broadband|internet bill|wifi|wi-fi)\b', 'Home', 'Internet', .9),
    (
      r'\b(pharmacy|chemist|medicines|apollo pharmacy|netmeds|1mg)\b',
      'Health',
      'Pharmacy',
      .91,
    ),
    (r'\b(hospital|clinic|doctor|diagnostic)\b', 'Health', 'Medical', .88),
    (
      r'\b(netflix|spotify|prime video|hotstar|subscription)\b',
      'Leisure',
      'Subscriptions',
      .9,
    ),
    (
      r'\b(movie|cinema|pvr|inox|bookmyshow)\b',
      'Leisure',
      'Entertainment',
      .88,
    ),
    (r'\b(udemy|coursera|course|tuition)\b', 'Education', 'Courses', .86),
    (r'\b(bookshop|bookstore|textbook)\b', 'Education', 'Books', .88),
    (r'\b(clothing|apparel|myntra|fashion)\b', 'Shopping', 'Clothing', .86),
    (
      r'\b(laptop|electronics|mobile handset)\b',
      'Shopping',
      'Electronics',
      .85,
    ),
    (r'\b(cgst|sgst|igst|gst|tax|cess)\b', 'Other', 'Tax', .9),
    (
      r'\b(bank fee|service charge|convenience fee|processing fee)\b',
      'Other',
      'Fees',
      .87,
    ),
  ];
  for (final rule in rules) {
    if (!RegExp(rule.$1).hasMatch(text)) continue;
    if (kind == EntryKind.income && rule.$2 != 'Income') continue;
    if (kind == EntryKind.expense && rule.$2 == 'Income') continue;
    return (category: rule.$2, subcategory: rule.$3, confidence: rule.$4);
  }
  return kind == EntryKind.income
      ? (category: 'Income', subcategory: 'Other', confidence: .35)
      : (category: 'Other', subcategory: 'Uncategorised', confidence: .1);
}

final _currencyAmount = RegExp(
  r'(?:₹|\bINR\b|\bRs\.?)\s*[:.]?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)(?![0-9,]|\.[0-9])',
  caseSensitive: false,
);
final _foreignCurrency = RegExp(
  r'\b(?:USD|EUR|GBP|AUD|CAD|AED)\b|[$€£]',
  caseSensitive: false,
);
final _debitVerb = RegExp(
  r'\b(?:debited|deducted|withdrawn|spent|paid|purchased|sent)\b',
  caseSensitive: false,
);
final _creditVerb = RegExp(
  r'\b(?:credited|received|deposited|refunded|reversed)\b',
  caseSensitive: false,
);
final _balanceStart = RegExp(
  r'\b(?:avl\.?|avail\.?|available|closing|ledger|remaining)\s*(?:bal\.?|balance)\b|\b(?:balance|bal)\b',
  caseSensitive: false,
);
String _normalise(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');
String _digest(String text) => sha256.convert(utf8.encode(text)).toString();
int? _amount(String value) {
  try {
    final result = parseMoney(value.trim());
    return result > 0 ? result : null;
  } on FormatException {
    return null;
  }
}

String? _accountHint(String text) {
  final pattern = RegExp(
    r'\b(?:a\s*/\s*c|acct|account|card)(?:\s*(?:no\.?|number|ending(?:\s+(?:in|with))?|:|#|-))*\s*([xX*#]*[0-9xX*#]{3,})',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(text)) {
    final digits = match[1]!.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) return digits.substring(digits.length - 4);
  }
  return null;
}

String? _reference(String text) {
  final patterns = [
    RegExp(r'\bUPI/(?:DR|CR)/([A-Za-z0-9]{6,})', caseSensitive: false),
    RegExp(
      r'\b(?:UTR|(?:UPI\s*)?Ref(?:erence)?(?:\s*(?:No\.?|Number|ID))?|Txn(?:\s*(?:ID|No\.?))?|Transaction\s*(?:ID|No\.?))\s*[:#.-]?\s*([A-Za-z0-9][A-Za-z0-9/-]{4,})',
      caseSensitive: false,
    ),
    RegExp(r'\bUPI\s*[:#-]\s*([0-9]{6,})\b', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(text)) {
      final candidate = match[1]!.replaceAll(RegExp(r'[./-]+$'), '');
      if (RegExp(r'\d').hasMatch(candidate)) return candidate.toUpperCase();
    }
  }
  return null;
}

String? _merchant(String text) {
  final pattern = RegExp(
    r'\b(?:at|to|from)\s+([A-Za-z][A-Za-z0-9 .&@_/-]{1,70}?)(?=\s+(?:on|via|ref|UPI|txn|avl|avail|available|balance|using|dated|if)\b|[.;]|$)',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(text)) {
    final candidate = match[1]!.trim();
    if (!RegExp(
      r'^(?:a/c|account|your|bank|card|you\b)',
      caseSensitive: false,
    ).hasMatch(candidate)) {
      return candidate;
    }
  }
  final upi = RegExp(
    r'\bUPI/(?:DR|CR)/[A-Za-z0-9]+/([^/\n]+)',
    caseSensitive: false,
  ).firstMatch(text);
  return upi?[1]?.trim();
}

({DateTime? date, bool found}) _date(String text) {
  DateTime? checked(int year, int month, int day) {
    if (year < 1900 || year > 2200) return null;
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }

  final iso = RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b').firstMatch(text);
  if (iso != null) {
    return (
      date: checked(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!)),
      found: true,
    );
  }
  final numeric = RegExp(
    r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4}|\d{2})\b',
  ).firstMatch(text);
  if (numeric != null) {
    var year = int.parse(numeric[3]!);
    if (numeric[3]!.length == 2) year += 2000;
    return (
      date: checked(year, int.parse(numeric[2]!), int.parse(numeric[1]!)),
      found: true,
    );
  }
  final named = RegExp(
    r'\b(\d{1,2})[ -/]([A-Za-z]{3,9})[ ,/-]+(\d{4}|\d{2})\b',
  ).firstMatch(text);
  if (named != null) {
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final month = months.indexOf(named[2]!.toLowerCase().substring(0, 3)) + 1;
    var year = int.parse(named[3]!);
    if (named[3]!.length == 2) year += 2000;
    return (
      date: month == 0 ? null : checked(year, month, int.parse(named[1]!)),
      found: true,
    );
  }
  return (date: null, found: false);
}

String _evidence({
  required String source,
  required String raw,
  required EntryKind? kind,
  required int? amount,
  String? account,
  String? reference,
}) {
  if (reference != null && account != null && kind != null && amount != null) {
    return _digest(
      'bank:$account:${reference.toUpperCase()}:${kind.name}:$amount',
    );
  }
  return _digest('$source:${_normalise(raw).toLowerCase()}');
}

/// Parses posted INR movements. OTPs, requests and failures are ignored.
ParsedCapture? parseBankSms(
  String body, {
  required String sender,
  required DateTime receivedAt,
}) {
  final raw = _normalise(body);
  if (raw.isEmpty || raw.length > 12000) return null;
  if (RegExp(
    r'\b(?:otp|one[ -]time(?:\s+password)?|verification code|security code|authentication code)\b',
    caseSensitive: false,
  ).hasMatch(raw)) {
    return null;
  }
  if (RegExp(
    r'\b(?:failed|declined|unsuccessful|pending|processing|scheduled|will be (?:debited|credited)|to be (?:debited|credited)|payment request|collect request|requested|due on|pre-approved|preapproved|offer|cashback offer)\b',
    caseSensitive: false,
  ).hasMatch(raw)) {
    return null;
  }
  final main = raw.split(_balanceStart).first;
  final debit = _debitVerb.firstMatch(main),
      credit = _creditVerb.firstMatch(main);
  if (debit == null && credit == null) return null;
  final direction = debit == null
      ? credit!
      : credit == null || debit.start < credit.start
      ? debit
      : credit;
  final kind = identical(direction, debit)
      ? EntryKind.expense
      : EntryKind.income;
  final candidates = <({int value, int distance})>[];
  for (final match in _currencyAmount.allMatches(main)) {
    final value = _amount(match[1]!);
    if (value == null) continue;
    final distance = match.end <= direction.start
        ? direction.start - match.end
        : match.start >= direction.end
        ? match.start - direction.end
        : 0;
    if (distance <= 100) candidates.add((value: value, distance: distance));
  }
  candidates.sort((a, b) => a.distance.compareTo(b.distance));
  final amount =
      _foreignCurrency.hasMatch(raw) ||
          candidates.isEmpty ||
          (candidates.length > 1 &&
              candidates[0].distance == candidates[1].distance &&
              candidates[0].value != candidates[1].value)
      ? null
      : candidates.first.value;
  if (amount == null) return null;
  final account = _accountHint(main),
      reference = _reference(raw),
      merchant = _merchant(main);
  final parsedDate = _date(main);
  final occurredAt = parsedDate.found ? parsedDate.date : receivedAt;
  final questions = <String>[
    if (account == null) 'Which account does this bank message belong to?',
    if (reference == null)
      'No bank reference was found. Check for an existing transaction before posting.',
    if (parsedDate.found && parsedDate.date == null)
      'The message contains an invalid date. Confirm the transaction date.',
    if (!parsedDate.found)
      'Message receipt time is being used. Confirm the transaction date if this alert was delayed.',
    if (occurredAt != null && occurredAt.isAfter(receivedAt))
      'The transaction date is after this message. Verify the date.',
    if (debit != null && credit != null)
      'The message mentions both debit and credit. Confirm this account’s movement.',
  ];
  final description = merchant ?? raw;
  final category = inferCategory(description, kind: kind);
  if (category.confidence < .6) {
    questions.add('Confirm the category and what this movement was for.');
  }
  return ParsedCapture(
    source: 'bank_sms',
    description: description,
    evidenceKey: _evidence(
      source: 'bank_sms',
      raw:
          '$sender:$raw:${receivedAt.year}-${receivedAt.month}-${receivedAt.day}',
      kind: kind,
      amount: amount,
      account: account,
      reference: reference,
    ),
    amountMinor: amount,
    occurredAt: occurredAt,
    kind: kind,
    merchant: merchant,
    accountHint: account,
    reference: reference,
    suggestedCategory: category.category,
    suggestedSubcategory: category.subcategory,
    questions: questions,
    confidence:
        account != null &&
            reference != null &&
            occurredAt != null &&
            !occurredAt.isAfter(receivedAt) &&
            !(debit != null && credit != null)
        ? .96
        : .65,
  );
}

({String label, int amount})? _lineAmount(String line) {
  final match = RegExp(
    r'^(.*?)\s*(?:[:=]\s*)?(?:(?:₹|INR|Rs\.?)\s*)?([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:/-)?$',
    caseSensitive: false,
  ).firstMatch(line.trim());
  if (match == null) return null;
  final amount = _amount(match[2]!);
  final label = match[1]!.trim().replaceAll(RegExp(r'[:=]+$'), '').trim();
  return amount == null || label.isEmpty
      ? null
      : (label: label, amount: amount);
}

/// Extracts a labelled POS total and allocations only when every paise matches.
ParsedCapture parseReceiptText(String text, {DateTime? now}) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final questions = <String>[];
  final totals = <({int priority, int amount})>[];
  for (final line in lines) {
    final pair = _lineAmount(line);
    if (pair == null) continue;
    final label = pair.label.toLowerCase();
    if (RegExp(
      r'sub\s*total|subtotal|qty|quantity|items?\s*count|taxable|tax total|\btotal\s*(?:gst|tax|cgst|sgst|igst)\b',
    ).hasMatch(label)) {
      continue;
    }
    final priority =
        RegExp(
          r'grand\s*total|total\s*(?:amount|payable|paid)|net\s*(?:amount|payable)|amount\s*(?:due|payable)',
        ).hasMatch(label)
        ? 100
        : RegExp(r'^total\b|^bill total\b').hasMatch(label)
        ? 90
        : RegExp(r'^amount paid\b').hasMatch(label)
        ? 80
        : 0;
    if (priority > 0) totals.add((priority: priority, amount: pair.amount));
  }
  totals.sort((a, b) => b.priority.compareTo(a.priority));
  int? amount;
  if (totals.isNotEmpty) {
    final best = totals
        .where((value) => value.priority == totals.first.priority)
        .map((value) => value.amount)
        .toSet();
    if (best.length == 1) {
      amount = best.single;
    } else {
      questions.add(
        'Several different totals were found. Confirm the amount paid.',
      );
    }
  } else {
    questions.add('No labelled total was found. Enter the final amount paid.');
  }
  if (_foreignCurrency.hasMatch(text)) {
    amount = null;
    questions.add(
      'This receipt appears to use another currency. Convert or record it manually; the ledger currently uses INR.',
    );
  }
  final parsedDate = _date(text);
  var date = parsedDate.date;
  if (date == null) {
    questions.add(
      parsedDate.found
          ? 'The printed date is invalid. Confirm the date.'
          : 'No receipt date was found. Enter the purchase date.',
    );
  }
  if (date != null && date.isAfter(now ?? DateTime.now())) {
    questions.add(
      'The printed date is in the future. Confirm the purchase date.',
    );
    date = null;
  }
  String? merchant;
  for (final line in lines.take(7)) {
    if (!RegExp(r'[A-Za-z]{3}').hasMatch(line) ||
        RegExp(
          r'^(?:tax\s*invoice|receipt|invoice|bill\b|date\b|time\b|gst|phone|tel\b|pos\b|www\.|https?://)',
          caseSensitive: false,
        ).hasMatch(line) ||
        _lineAmount(line) != null ||
        _date(line).found) {
      continue;
    }
    merchant = line;
    break;
  }
  final kind =
      RegExp(
        r'\b(?:refund receipt|credit note|refund total)\b',
        caseSensitive: false,
      ).hasMatch(text)
      ? EntryKind.income
      : EntryKind.expense;
  final category = inferCategory(merchant ?? text, kind: kind);
  final items = <LineItem>[];
  for (final line in lines) {
    if (_date(line).found) continue;
    final pair = _lineAmount(line);
    if (pair == null ||
        RegExp(
          r'grand\s*total|sub\s*total|subtotal|\btotal\b|amount\s*(?:paid|due|payable)|net\s*(?:amount|payable)|cash\b|change\b|tender|card\b|balance\b|invoice\b|bill\s*(?:no|number)|phone\b|tel\b|gstin\b|discount\b|round\s*off|\bqty\b|\bquantity\b|date\b|time\b',
          caseSensitive: false,
        ).hasMatch(pair.label)) {
      continue;
    }
    if (RegExp(r'-\s*\d').hasMatch(line)) continue;
    final c = inferCategory(pair.label, kind: kind);
    items.add(
      LineItem(
        description: pair.label,
        amountMinor: pair.amount,
        category: c.category,
        subcategory: c.subcategory,
      ),
    );
  }
  if (items.isNotEmpty &&
      items.fold(0, (sum, item) => sum + item.amountMinor) != amount) {
    questions.add(
      'Extracted items do not equal the final total. Check discounts, tax, tips and OCR amounts before adding item splits.',
    );
    items.clear();
  }
  if (category.confidence < .6) questions.add('Confirm the purchase category.');
  if (merchant == null) {
    questions.add('What was the merchant or purchase description?');
  }
  return ParsedCapture(
    source: 'receipt',
    description: merchant ?? 'Receipt purchase',
    evidenceKey: _digest('receipt:${_normalise(text).toLowerCase()}'),
    amountMinor: amount,
    occurredAt: date,
    kind: kind,
    merchant: merchant,
    suggestedCategory: category.category,
    suggestedSubcategory: category.subcategory,
    questions: questions,
    items: items,
    confidence: amount != null && date != null ? .85 : .4,
  );
}

List<String> _columns(String line) => line.contains('\t')
    ? line.split('\t').map((value) => value.trim()).toList()
    : line.contains('|')
    ? line.split('|').map((value) => value.trim()).toList()
    : line
          .trim()
          .split(RegExp(r'\s{2,}'))
          .map((value) => value.trim())
          .toList();
int? _columnAmount(String cell) {
  final clean = cell.trim();
  if (clean.isEmpty ||
      clean == '-' ||
      clean == '—' ||
      clean == '0' ||
      clean == '0.00') {
    return 0;
  }
  return _amount(clean);
}

/// Dated statement rows need explicit direction or usable debit/credit columns.
/// Running-balance differences never determine a transaction's direction.
List<ParsedCapture> parseStatementText(String text, {DateTime? now}) {
  final output = <ParsedCapture>[];
  List<String>? header;
  final account = _accountHint(text);
  var tailColumns = <String>[];
  final dateAtStart = RegExp(
    r'^\s*(?:\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[/-]\d{1,2}[/-](?:\d{4}|\d{2})|\d{1,2}[ -/][A-Za-z]{3,9}[ ,/-]+(?:\d{4}|\d{2}))\b',
  );
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (!dateAtStart.hasMatch(line)) {
      final lower = line.toLowerCase();
      if (lower.contains('date') &&
          RegExp(r'\b(?:debit|withdrawal)\b').hasMatch(lower) &&
          RegExp(r'\b(?:credit|deposit)\b').hasMatch(lower)) {
        header = _columns(line);
        tailColumns = RegExp(
          r'\b(?:debit|withdrawal|credit|deposit|balance)\b',
        ).allMatches(lower).map((match) => match[0]!).toList();
      }
      continue;
    }
    final questions = <String>[];
    final parsedDate = _date(dateAtStart.firstMatch(line)![0]!);
    var date = parsedDate.date;
    if (date == null) {
      questions.add('Invalid statement date. Correct it before posting.');
    }
    if (date != null && date.isAfter(now ?? DateTime.now())) {
      questions.add('Statement date is in the future. Confirm the date.');
      date = null;
    }
    final body = line.substring(dateAtStart.firstMatch(line)!.end).trim();
    if (body.isEmpty ||
        RegExp(
          r'^\s*(?:opening|closing|brought forward|carried forward)\s*balance\b',
          caseSensitive: false,
        ).hasMatch(body)) {
      continue;
    }
    EntryKind? kind;
    int? amount;
    var description = body;
    final cols = _columns(line);
    var ambiguousColumns = false;
    if (header != null && header.length >= 3 && cols.length == header.length) {
      final di = header.indexWhere(
        (cell) => RegExp(
          r'\b(?:debit|withdrawal)\b',
          caseSensitive: false,
        ).hasMatch(cell),
      );
      final ci = header.indexWhere(
        (cell) => RegExp(
          r'\b(?:credit|deposit)\b',
          caseSensitive: false,
        ).hasMatch(cell),
      );
      if (di >= 0 && ci >= 0) {
        final debit = _columnAmount(cols[di]), credit = _columnAmount(cols[ci]);
        if (debit != null && credit != null) {
          if (debit > 0 && credit > 0) {
            ambiguousColumns = true;
            questions.add(
              'Both debit and credit columns contain amounts. Confirm this row manually.',
            );
          }
          if (debit > 0 && credit == 0) {
            kind = EntryKind.expense;
            amount = debit;
          }
          if (credit > 0 && debit == 0) {
            kind = EntryKind.income;
            amount = credit;
          }
        }
        final ni = header.indexWhere(
          (cell) => RegExp(
            r'description|narration|particulars|details',
            caseSensitive: false,
          ).hasMatch(cell),
        );
        if (ni >= 0) description = cols[ni];
      }
    }
    // OCR can collapse column spacing. Only recover a complete numeric tail
    // with retained zero/dash placeholders for both movement columns.
    if (amount == null && tailColumns.length >= 2) {
      var tail = body;
      final values = <int?>[];
      final trailing = RegExp(
        r'(?:^|\s)([0-9][0-9,]*(?:\.[0-9]{1,2})?|[-—])\s*$',
      );
      for (var i = 0; i < tailColumns.length; i++) {
        final match = trailing.firstMatch(tail);
        if (match == null) break;
        values.insert(0, _columnAmount(match[1]!));
        tail = tail.substring(0, match.start).trimRight();
      }
      if (values.length == tailColumns.length &&
          values.every((value) => value != null)) {
        final di = tailColumns.indexWhere(
          (name) => name == 'debit' || name == 'withdrawal',
        );
        final ci = tailColumns.indexWhere(
          (name) => name == 'credit' || name == 'deposit',
        );
        if (di >= 0 && ci >= 0) {
          final debit = values[di]!, credit = values[ci]!;
          if (debit > 0 && credit > 0) {
            ambiguousColumns = true;
            questions.add(
              'Both debit and credit columns contain amounts. Confirm this row manually.',
            );
          }
          if (debit > 0 && credit == 0) {
            kind = EntryKind.expense;
            amount = debit;
          }
          if (credit > 0 && debit == 0) {
            kind = EntryKind.income;
            amount = credit;
          }
          if (amount != null) description = tail;
        }
      }
    }
    if (amount == null && !ambiguousColumns) {
      final debit = RegExp(
        r'\b(?:DR|debited|debit|withdrawal|withdrawn)\b',
        caseSensitive: false,
      ).allMatches(body).toList();
      final credit = RegExp(
        r'\b(?:CR|credited|credit|deposit|deposited)\b',
        caseSensitive: false,
      ).allMatches(body).toList();
      if (debit.isNotEmpty != credit.isNotEmpty) {
        kind = debit.isNotEmpty ? EntryKind.expense : EntryKind.income;
        final directional = RegExp(
          r'([0-9][0-9,]*\.[0-9]{1,2})\s*(?:DR|CR)\b|\b(?:DR|CR)\s*(?:₹|INR|Rs\.?)?\s*([0-9][0-9,]*\.[0-9]{1,2})\b',
          caseSensitive: false,
        ).firstMatch(body);
        if (directional != null) {
          amount = _amount(directional[1] ?? directional[2]!);
        }
        if (amount == null) {
          final beforeBalance = body.split(_balanceStart).first;
          final money = _currencyAmount.allMatches(beforeBalance).toList();
          if (money.length == 1) amount = _amount(money.single[1]!);
          if (amount == null) {
            final tail = RegExp(
              r'(?:^|\s)([0-9][0-9,]*\.[0-9]{1,2})(?:\s+(?:DR|CR))?(?:\s+([0-9][0-9,]*\.[0-9]{1,2}))?\s*$',
              caseSensitive: false,
            ).firstMatch(beforeBalance);
            if (tail != null) amount = _amount(tail[1]!);
          }
        }
      }
    }
    if (_foreignCurrency.hasMatch(line)) {
      amount = null;
      questions.add(
        'This row uses a foreign currency. Convert or record it manually.',
      );
    }
    if (kind == null) {
      questions.add(
        'Is this row a debit or credit? The direction could not be read reliably.',
      );
    }
    if (amount == null) {
      questions.add(
        'Confirm the transaction amount; do not use the running balance.',
      );
    }
    final reference = _reference(line), merchant = _merchant(description);
    final category = inferCategory(description, kind: kind);
    if (category.confidence < .6) questions.add('Confirm the category.');
    output.add(
      ParsedCapture(
        source: 'statement',
        description: description,
        evidenceKey: _evidence(
          source: 'statement',
          raw: '$account:$line',
          kind: kind,
          amount: amount,
          account: account,
          reference: reference,
        ),
        amountMinor: amount,
        occurredAt: date,
        kind: kind,
        merchant: merchant,
        accountHint: account,
        reference: reference,
        suggestedCategory: category.category,
        suggestedSubcategory: category.subcategory,
        questions: questions,
        confidence: amount != null && date != null && kind != null ? .85 : .3,
      ),
    );
  }
  return output;
}
