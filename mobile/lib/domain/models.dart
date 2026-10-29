import 'money.dart';

const selfPerson = 'You';
String personKey(String name) => name.trim().toLowerCase();

enum EntryKind {
  expense,
  income,
  transfer,
  lent,
  borrowed,
  repaymentReceived,
  repaymentPaid,
  bankDebit,
  bankCredit,
}

extension EntryKindLabel on EntryKind {
  String get label => switch (this) {
    EntryKind.expense => 'Expense',
    EntryKind.income => 'Income',
    EntryKind.transfer => 'Transfer',
    EntryKind.lent => 'Money lent',
    EntryKind.borrowed => 'Money borrowed',
    EntryKind.repaymentReceived => 'Repayment received',
    EntryKind.repaymentPaid => 'Repayment paid',
    EntryKind.bankDebit => 'Bank debit',
    EntryKind.bankCredit => 'Bank credit',
  };
}

const categories = <String, List<String>>{
  'Food & groceries': ['Groceries', 'Dining out', 'Delivery', 'Tea & coffee'],
  'Transport': ['Fuel', 'Public transport', 'Cab', 'Maintenance'],
  'Home': ['Rent', 'Electricity', 'Internet', 'Household'],
  'Shopping': ['Clothing', 'Electronics', 'Personal care'],
  'Health': ['Medical', 'Pharmacy', 'Insurance'],
  'Education': ['Courses', 'Books', 'Tuition'],
  'Leisure': ['Travel', 'Entertainment', 'Subscriptions'],
  'Income': ['Salary', 'Freelance', 'Interest', 'Dividends', 'Other'],
  'Other': ['Uncategorised', 'Gifts', 'Fees', 'Tax'],
};

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.openingMinor = 0,
    this.lastFour,
    this.smsSender,
  });
  final String id, name, type;
  final int openingMinor;
  final String? lastFour, smsSender;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'openingMinor': openingMinor,
    'lastFour': lastFour,
    'smsSender': smsSender,
  };
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'],
    name: j['name'],
    type: j['type'],
    openingMinor: j['openingMinor'],
    lastFour: j['lastFour'],
    smsSender: j['smsSender'],
  );
}

class LineItem {
  const LineItem({
    required this.description,
    required this.amountMinor,
    required this.category,
    required this.subcategory,
  });
  final String description, category, subcategory;
  final int amountMinor;
  Map<String, dynamic> toJson() => {
    'description': description,
    'amountMinor': amountMinor,
    'category': category,
    'subcategory': subcategory,
  };
  factory LineItem.fromJson(Map<String, dynamic> j) => LineItem(
    description: j['description'],
    amountMinor: j['amountMinor'],
    category: j['category'],
    subcategory: j['subcategory'],
  );
}

class Share {
  const Share({required this.person, required this.amountMinor});
  final String person;
  final int amountMinor;
  Map<String, dynamic> toJson() => {
    'person': person,
    'amountMinor': amountMinor,
  };
  factory Share.fromJson(Map<String, dynamic> j) =>
      Share(person: j['person'], amountMinor: j['amountMinor']);
}

class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.kind,
    required this.accountId,
    required this.amountMinor,
    required this.date,
    required this.description,
    this.toAccountId,
    this.payer = selfPerson,
    this.counterparty,
    List<LineItem> lines = const [],
    List<Share> shares = const [],
    this.sourceKey,
    this.source = 'manual',
    this.metadataPending = false,
    this.merchant,
    this.externalReference,
    this.reviewedAt,
  }) : lines = List.unmodifiable(lines),
       shares = List.unmodifiable(shares);
  final String id, accountId, description, payer, source;
  final String? toAccountId, counterparty, sourceKey;
  final EntryKind kind;
  final int amountMinor;
  final DateTime date;
  final List<LineItem> lines;
  final List<Share> shares;
  final bool metadataPending;
  final String? merchant, externalReference;
  final DateTime? reviewedAt;
  bool get paidByMe => personKey(payer) == personKey(selfPerson);
  int get myExpense => kind != EntryKind.expense
      ? 0
      : shares.isEmpty
      ? amountMinor
      : shares
            .where((s) => personKey(s.person) == personKey(selfPerson))
            .fold(0, (v, s) => v + s.amountMinor);
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'accountId': accountId,
    'amountMinor': amountMinor,
    'date': date.toIso8601String(),
    'description': description,
    'toAccountId': toAccountId,
    'payer': payer,
    'counterparty': counterparty,
    'lines': lines.map((x) => x.toJson()).toList(),
    'shares': shares.map((x) => x.toJson()).toList(),
    'sourceKey': sourceKey,
    'source': source,
    'metadataPending': metadataPending,
    'merchant': merchant,
    'externalReference': externalReference,
    'reviewedAt': reviewedAt?.toIso8601String(),
  };
  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
    id: j['id'],
    kind: EntryKind.values.byName(j['kind']),
    accountId: j['accountId'],
    amountMinor: j['amountMinor'],
    date: DateTime.parse(j['date']),
    description: j['description'],
    toAccountId: j['toAccountId'],
    payer: j['payer'] ?? selfPerson,
    counterparty: j['counterparty'],
    sourceKey: j['sourceKey'],
    source: j['source'] ?? 'manual',
    metadataPending: j['metadataPending'] ?? false,
    merchant: j['merchant'],
    externalReference: j['externalReference'],
    reviewedAt: j['reviewedAt'] == null
        ? null
        : DateTime.parse(j['reviewedAt']),
    lines: (j['lines'] as List)
        .map((x) => LineItem.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
    shares: (j['shares'] as List)
        .map((x) => Share.fromJson(Map<String, dynamic>.from(x)))
        .toList(),
  );

  LedgerEntry copyWith({
    EntryKind? kind,
    String? accountId,
    int? amountMinor,
    DateTime? date,
    String? description,
    List<LineItem>? lines,
    List<Share>? shares,
    bool? metadataPending,
    String? merchant,
    String? externalReference,
    DateTime? reviewedAt,
  }) => LedgerEntry(
    id: id,
    kind: kind ?? this.kind,
    accountId: accountId ?? this.accountId,
    amountMinor: amountMinor ?? this.amountMinor,
    date: date ?? this.date,
    description: description ?? this.description,
    lines: lines ?? this.lines,
    shares: shares ?? this.shares,
    toAccountId: toAccountId,
    payer: payer,
    counterparty: counterparty,
    sourceKey: sourceKey,
    source: source,
    metadataPending: metadataPending ?? this.metadataPending,
    merchant: merchant ?? this.merchant,
    externalReference: externalReference ?? this.externalReference,
    reviewedAt: reviewedAt ?? this.reviewedAt,
  );
}

enum CaptureStatus { pending, posted, reviewed, dismissed, linked }

class CapturedTransaction {
  CapturedTransaction({
    required this.id,
    required this.source,
    required this.evidenceKey,
    required this.description,
    required this.capturedAt,
    this.amountMinor,
    this.date,
    this.kind,
    this.merchant,
    this.accountHint,
    this.reference,
    this.sender,
    this.accountId,
    this.linkedEntryId,
    this.possibleDuplicateEntryId,
    this.category = 'Other',
    this.subcategory = 'Uncategorised',
    this.confidence = 0,
    this.status = CaptureStatus.pending,
    List<String> questions = const [],
    List<LineItem> items = const [],
  }) : questions = List.unmodifiable(questions),
       items = List.unmodifiable(items);
  final String id, source, evidenceKey, description, category, subcategory;
  final String? merchant,
      accountHint,
      reference,
      sender,
      accountId,
      linkedEntryId,
      possibleDuplicateEntryId;
  final int? amountMinor;
  final EntryKind? kind;
  final DateTime capturedAt;
  final DateTime? date;
  final double confidence;
  final CaptureStatus status;
  final List<String> questions;
  final List<LineItem> items;
  bool get needsReview =>
      status == CaptureStatus.pending || status == CaptureStatus.posted;
  CapturedTransaction copyWith({
    String? accountId,
    String? linkedEntryId,
    CaptureStatus? status,
    String? category,
    String? subcategory,
    List<String>? questions,
  }) => CapturedTransaction(
    id: id,
    source: source,
    evidenceKey: evidenceKey,
    description: description,
    capturedAt: capturedAt,
    amountMinor: amountMinor,
    date: date,
    kind: kind,
    merchant: merchant,
    accountHint: accountHint,
    reference: reference,
    sender: sender,
    accountId: accountId ?? this.accountId,
    linkedEntryId: linkedEntryId ?? this.linkedEntryId,
    possibleDuplicateEntryId: possibleDuplicateEntryId,
    category: category ?? this.category,
    subcategory: subcategory ?? this.subcategory,
    confidence: confidence,
    status: status ?? this.status,
    questions: questions ?? this.questions,
    items: items,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'evidenceKey': evidenceKey,
    'description': description,
    'capturedAt': capturedAt.toIso8601String(),
    'amountMinor': amountMinor,
    'date': date?.toIso8601String(),
    'kind': kind?.name,
    'merchant': merchant,
    'accountHint': accountHint,
    'reference': reference,
    'sender': sender,
    'accountId': accountId,
    'linkedEntryId': linkedEntryId,
    'possibleDuplicateEntryId': possibleDuplicateEntryId,
    'category': category,
    'subcategory': subcategory,
    'confidence': confidence,
    'status': status.name,
    'questions': questions,
    'items': items.map((i) => i.toJson()).toList(),
  };
  factory CapturedTransaction.fromJson(Map<String, dynamic> j) =>
      CapturedTransaction(
        id: j['id'],
        source: j['source'],
        evidenceKey: j['evidenceKey'],
        description: j['description'],
        capturedAt: DateTime.parse(j['capturedAt']),
        amountMinor: j['amountMinor'],
        date: j['date'] == null ? null : DateTime.parse(j['date']),
        kind: j['kind'] == null ? null : EntryKind.values.byName(j['kind']),
        merchant: j['merchant'],
        accountHint: j['accountHint'],
        reference: j['reference'],
        sender: j['sender'],
        accountId: j['accountId'],
        linkedEntryId: j['linkedEntryId'],
        possibleDuplicateEntryId: j['possibleDuplicateEntryId'],
        category: j['category'] ?? 'Other',
        subcategory: j['subcategory'] ?? 'Uncategorised',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        status: CaptureStatus.values.byName(j['status'] ?? 'pending'),
        questions: List<String>.from(j['questions'] ?? []),
        items: (j['items'] as List? ?? [])
            .map((i) => LineItem.fromJson(Map<String, dynamic>.from(i)))
            .toList(),
      );
}

class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.merchant,
    required this.kind,
    required this.category,
    required this.subcategory,
  });
  final String id, merchant, category, subcategory;
  final EntryKind kind;
  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant': merchant,
    'kind': kind.name,
    'category': category,
    'subcategory': subcategory,
  };
  factory MerchantRule.fromJson(Map<String, dynamic> j) => MerchantRule(
    id: j['id'],
    merchant: j['merchant'],
    kind: EntryKind.values.byName(j['kind']),
    category: j['category'],
    subcategory: j['subcategory'],
  );
}

class Holding {
  const Holding({
    required this.id,
    required this.name,
    required this.assetClass,
    required this.costMinor,
    required this.valueMinor,
    required this.valuedAt,
  });
  final String id, name, assetClass;
  final int costMinor, valueMinor;
  final DateTime valuedAt;
  int get gainMinor => valueMinor - costMinor;
  double? get returnPercent =>
      costMinor == 0 ? null : gainMinor * 100 / costMinor;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'assetClass': assetClass,
    'costMinor': costMinor,
    'valueMinor': valueMinor,
    'valuedAt': valuedAt.toIso8601String(),
  };
  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
    id: j['id'],
    name: j['name'],
    assetClass: j['assetClass'],
    costMinor: j['costMinor'],
    valueMinor: j['valueMinor'],
    valuedAt: DateTime.parse(j['valuedAt']),
  );
}

class LedgerState {
  LedgerState({
    List<Account> accounts = const [],
    List<LedgerEntry> entries = const [],
    List<Holding> holdings = const [],
    List<CapturedTransaction> captures = const [],
    List<MerchantRule> merchantRules = const [],
  }) : accounts = List.unmodifiable(accounts),
       entries = List.unmodifiable(entries),
       holdings = List.unmodifiable(holdings),
       captures = List.unmodifiable(captures),
       merchantRules = List.unmodifiable(merchantRules);
  final List<Account> accounts;
  final List<LedgerEntry> entries;
  final List<Holding> holdings;
  final List<CapturedTransaction> captures;
  final List<MerchantRule> merchantRules;
  int get reviewCount => captures.where((c) => c.needsReview).length;
  LedgerState copyWith({
    List<Account>? accounts,
    List<LedgerEntry>? entries,
    List<Holding>? holdings,
    List<CapturedTransaction>? captures,
    List<MerchantRule>? merchantRules,
  }) => LedgerState(
    accounts: accounts ?? this.accounts,
    entries: entries ?? this.entries,
    holdings: holdings ?? this.holdings,
    captures: captures ?? this.captures,
    merchantRules: merchantRules ?? this.merchantRules,
  );

  int balance(String accountId) {
    var result = accounts.firstWhere((a) => a.id == accountId).openingMinor;
    for (final e in entries) {
      if (e.kind == EntryKind.transfer && e.toAccountId == accountId) {
        result = checkedAmount(result + e.amountMinor);
      }
      if (e.accountId != accountId) continue;
      result = checkedAmount(
        result +
            switch (e.kind) {
              EntryKind.income ||
              EntryKind.borrowed ||
              EntryKind.repaymentReceived => e.amountMinor,
              EntryKind.bankCredit => e.amountMinor,
              EntryKind.expense => e.paidByMe ? -e.amountMinor : 0,
              EntryKind.transfer ||
              EntryKind.lent ||
              EntryKind.repaymentPaid => -e.amountMinor,
              EntryKind.bankDebit => -e.amountMinor,
            },
      );
    }
    return result;
  }

  /// Positive = owed to the local user. Negative = the local user owes them.
  Map<String, int> get debts {
    final result = <String, int>{};
    final displayNames = <String, String>{};
    void add(String name, int minor) {
      final key = personKey(name);
      if (key == personKey(selfPerson)) return;
      final display = displayNames.putIfAbsent(key, () => name.trim());
      result[display] = checkedAmount((result[display] ?? 0) + minor);
    }

    for (final e in entries) {
      if (e.kind == EntryKind.expense && e.shares.isNotEmpty) {
        if (e.paidByMe) {
          for (final share in e.shares) {
            add(share.person, share.amountMinor);
          }
        } else {
          add(e.payer, -e.myExpense);
        }
      }
      if (e.counterparty != null) {
        final sign = switch (e.kind) {
          EntryKind.lent || EntryKind.repaymentPaid => 1,
          EntryKind.borrowed || EntryKind.repaymentReceived => -1,
          _ => 0,
        };
        add(e.counterparty!, sign * e.amountMinor);
      }
    }
    result.removeWhere((_, value) => value == 0);
    return result;
  }

  int debtFor(String name) => debts.entries
      .where((x) => personKey(x.key) == personKey(name))
      .fold(0, (a, b) => a + b.value);
  int get cashMinor =>
      accounts.fold(0, (sum, a) => checkedAmount(sum + balance(a.id)));
  int get investmentMinor =>
      holdings.fold(0, (sum, h) => checkedAmount(sum + h.valueMinor));
  int get netWorthMinor => checkedAmount(
    cashMinor + investmentMinor + debts.values.fold(0, (a, b) => a + b),
  );
  int incomeFor(DateTime month) => entries
      .where(
        (e) =>
            !e.metadataPending &&
            e.kind == EntryKind.income &&
            sameMonth(e.date, month),
      )
      .fold(0, (sum, e) => sum + e.amountMinor);
  int expenseFor(DateTime month) => entries
      .where((e) => !e.metadataPending && sameMonth(e.date, month))
      .fold(0, (sum, e) => sum + e.myExpense);
}

bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;
