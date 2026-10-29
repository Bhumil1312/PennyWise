import '../domain/models.dart';

LedgerState demoData({DateTime? now}) {
  final today = now ?? DateTime.now();
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day - offset);
  LedgerEntry entry(
    String id,
    EntryKind kind,
    int amount,
    String text,
    String category,
    String sub,
    int ago,
  ) => LedgerEntry(
    id: id,
    kind: kind,
    accountId: 'bank',
    amountMinor: amount,
    date: day(ago),
    description: text,
    lines: [
      LineItem(
        description: text,
        amountMinor: amount,
        category: category,
        subcategory: sub,
      ),
    ],
  );
  return LedgerState(
    accounts: const [
      Account(
        id: 'bank',
        name: 'Everyday account',
        type: 'Bank',
        openingMinor: 6245000,
      ),
      Account(
        id: 'savings',
        name: 'Rainy day fund',
        type: 'Savings',
        openingMinor: 18000000,
      ),
      Account(
        id: 'cash',
        name: 'Cash wallet',
        type: 'Cash',
        openingMinor: 250000,
      ),
    ],
    entries: [
      entry(
        'salary',
        EntryKind.income,
        9500000,
        'Monthly salary',
        'Income',
        'Salary',
        2,
      ),
      entry(
        'rent',
        EntryKind.expense,
        2200000,
        'October rent',
        'Home',
        'Rent',
        1,
      ),
      entry(
        'food',
        EntryKind.expense,
        286000,
        'Weekend groceries',
        'Food & groceries',
        'Groceries',
        1,
      ),
      entry(
        'coffee',
        EntryKind.expense,
        32000,
        'Coffee & a catch-up',
        'Food & groceries',
        'Tea & coffee',
        0,
      ),
      LedgerEntry(
        id: 'dinner',
        kind: EntryKind.expense,
        accountId: 'bank',
        amountMinor: 180000,
        date: day(0),
        description: 'Dinner with friends',
        lines: const [
          LineItem(
            description: 'Dinner',
            amountMinor: 180000,
            category: 'Food & groceries',
            subcategory: 'Dining out',
          ),
        ],
        shares: const [
          Share(person: 'You', amountMinor: 60000),
          Share(person: 'Aarav', amountMinor: 60000),
          Share(person: 'Meera', amountMinor: 60000),
        ],
      ),
      LedgerEntry(
        id: 'loan',
        kind: EntryKind.borrowed,
        accountId: 'bank',
        amountMinor: 250000,
        date: day(0),
        description: 'Trip advance',
        counterparty: 'Riya',
      ),
    ],
    holdings: [
      Holding(
        id: 'index',
        name: 'Nifty 50 index fund',
        assetClass: 'Mutual fund',
        costMinor: 15000000,
        valueMinor: 16950000,
        valuedAt: day(0),
      ),
      Holding(
        id: 'fd',
        name: 'Fixed deposit',
        assetClass: 'Fixed income',
        costMinor: 10000000,
        valueMinor: 10540000,
        valuedAt: day(0),
      ),
      Holding(
        id: 'gold',
        name: 'Gold ETF',
        assetClass: 'ETF',
        costMinor: 5000000,
        valueMinor: 5340000,
        valuedAt: day(0),
      ),
    ],
  );
}
