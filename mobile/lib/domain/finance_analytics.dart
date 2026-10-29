import 'models.dart';

/// Confirmed summaries. Pending metadata can already affect account balances.
class FinanceAnalytics {
  FinanceAnalytics(this.state, {required DateTime month, DateTime? now})
    : month = DateTime(month.year, month.month),
      now = now ?? DateTime.now() {
    _build();
  }
  final LedgerState state;
  final DateTime month, now;
  late final DateTime periodEndExclusive,
      comparisonMonth,
      comparisonEndExclusive;
  late final bool isPartialMonth;
  int incomeMinor = 0, spendingMinor = 0, reviewedCount = 0;
  int pendingCount = 0, pendingAmountMinor = 0;
  int previousIncomeMinor = 0, previousSpendingMinor = 0;
  late final Map<String, int> categoryTotals, subcategoryTotals, merchantTotals;
  late final List<MonthlyFinanceTotal> timeline;

  /// Income less personal spending; not total account cash movement.
  int get netCashflowMinor => incomeMinor - spendingMinor;
  double? get spendingChangePercent => previousSpendingMinor == 0
      ? null
      : (spendingMinor - previousSpendingMinor) * 100 / previousSpendingMinor;
  DateTime get periodLastDay => DateTime(
    periodEndExclusive.year,
    periodEndExclusive.month,
    periodEndExclusive.day - 1,
  );
  DateTime get comparisonLastDay => DateTime(
    comparisonEndExclusive.year,
    comparisonEndExclusive.month,
    comparisonEndExclusive.day - 1,
  );
  bool _inPeriod(LedgerEntry entry, DateTime start, DateTime end) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    return !day.isBefore(start) && day.isBefore(end);
  }

  void _build() {
    final thisMonth = DateTime(now.year, now.month);
    isPartialMonth = month == thisMonth;
    periodEndExclusive = month.isAfter(thisMonth)
        ? month
        : isPartialMonth
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(month.year, month.month + 1);
    comparisonMonth = DateTime(month.year, month.month - 1);
    final previousDays = DateTime(month.year, month.month, 0).day;
    final comparisonDays = isPartialMonth && now.day < previousDays
        ? now.day
        : previousDays;
    comparisonEndExclusive = DateTime(
      comparisonMonth.year,
      comparisonMonth.month,
      comparisonDays + 1,
    );
    final category = <String, int>{},
        subcategory = <String, int>{},
        merchants = <String, int>{};
    final merchantNames = <String, String>{};
    for (final entry in state.entries) {
      if (_inPeriod(entry, month, periodEndExclusive)) {
        if (entry.metadataPending) {
          pendingCount++;
          pendingAmountMinor += entry.amountMinor;
        } else {
          reviewedCount++;
          if (entry.kind == EntryKind.income) incomeMinor += entry.amountMinor;
          if (entry.kind == EntryKind.expense) {
            final mine = entry.myExpense;
            spendingMinor += mine;
            final allocations = allocatePersonalItems(entry);
            if (allocations.isEmpty) {
              _add(category, 'Other', mine);
              _add(subcategory, 'Other / Uncategorised', mine);
            } else {
              for (var i = 0; i < entry.lines.length; i++) {
                final line = entry.lines[i];
                _add(category, line.category, allocations[i]);
                _add(
                  subcategory,
                  '${line.category} / ${line.subcategory}',
                  allocations[i],
                );
              }
            }
            final raw = entry.merchant?.trim().replaceAll(RegExp(r'\s+'), ' ');
            final merchant = raw == null || raw.isEmpty ? 'Not specified' : raw;
            final name = merchantNames.putIfAbsent(
              merchant.toLowerCase(),
              () => merchant,
            );
            _add(merchants, name, mine);
          }
        }
      }
      if (!entry.metadataPending &&
          _inPeriod(entry, comparisonMonth, comparisonEndExclusive)) {
        if (entry.kind == EntryKind.income) {
          previousIncomeMinor += entry.amountMinor;
        }
        if (entry.kind == EntryKind.expense) {
          previousSpendingMinor += entry.myExpense;
        }
      }
    }
    categoryTotals = _sorted(category);
    subcategoryTotals = _sorted(subcategory);
    merchantTotals = _sorted(merchants);
    timeline = List.unmodifiable(
      List.generate(6, (index) {
        final start = DateTime(month.year, month.month - 5 + index);
        final end = start == month
            ? periodEndExclusive
            : DateTime(start.year, start.month + 1);
        var income = 0, spending = 0, pending = 0;
        for (final entry in state.entries) {
          if (!_inPeriod(entry, start, end)) continue;
          if (entry.metadataPending) {
            pending++;
          } else if (entry.kind == EntryKind.income) {
            income += entry.amountMinor;
          } else if (entry.kind == EntryKind.expense) {
            spending += entry.myExpense;
          }
        }
        return MonthlyFinanceTotal(
          month: start,
          incomeMinor: income,
          spendingMinor: spending,
          pendingCount: pending,
          partial: start == thisMonth,
        );
      }),
    );
  }

  static void _add(Map<String, int> values, String key, int amount) {
    if (amount != 0) values[key] = (values[key] ?? 0) + amount;
  }

  static Map<String, int> _sorted(Map<String, int> values) {
    final entries = values.entries.toList()
      ..sort((a, b) {
        final amount = b.value.compareTo(a.value);
        return amount == 0 ? a.key.compareTo(b.key) : amount;
      });
    return Map.unmodifiable(Map.fromEntries(entries));
  }
}

class MonthlyFinanceTotal {
  const MonthlyFinanceTotal({
    required this.month,
    required this.incomeMinor,
    required this.spendingMinor,
    required this.pendingCount,
    required this.partial,
  });
  final DateTime month;
  final int incomeMinor, spendingMinor, pendingCount;
  final bool partial;
}

/// Exact proportional item allocation of my share. Largest remainders get
/// leftover paise; ties preserve receipt order. BigInt preserves Web precision.
List<int> allocatePersonalItems(LedgerEntry entry) {
  if (entry.kind != EntryKind.expense || entry.lines.isEmpty) return const [];
  final mine = entry.myExpense;
  final weights = entry.lines
      .map((line) => line.amountMinor > 0 ? line.amountMinor : 0)
      .toList();
  final total = weights.fold<BigInt>(
    BigInt.zero,
    (sum, value) => sum + BigInt.from(value),
  );
  if (total == BigInt.zero || mine < 0) return const [];
  final allocations = <int>[], remainders = <BigInt>[];
  for (final weight in weights) {
    final product = BigInt.from(mine) * BigInt.from(weight);
    allocations.add((product ~/ total).toInt());
    remainders.add(product % total);
  }
  final order = List.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final remainder = remainders[b].compareTo(remainders[a]);
      return remainder == 0 ? a.compareTo(b) : remainder;
    });
  var remaining = mine - allocations.fold(0, (a, b) => a + b);
  for (final index in order) {
    if (remaining == 0) break;
    allocations[index]++;
    remaining--;
  }
  return List.unmodifiable(allocations);
}
