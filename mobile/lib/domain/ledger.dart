import 'models.dart';
import 'money.dart';

class LedgerRules {
  static void validate(LedgerEntry entry, LedgerState state, {DateTime? now}) {
    void require(bool condition, String message) {
      if (!condition) throw FormatException(message);
    }

    require(
      entry.id.isNotEmpty && !state.entries.any((e) => e.id == entry.id),
      'This transaction already exists.',
    );
    require(entry.description.trim().isNotEmpty, 'Add a description.');
    require(
      entry.amountMinor > 0 && entry.amountMinor <= maxMinor,
      'Amount must be greater than zero.',
    );
    require(
      state.accounts.any((a) => a.id == entry.accountId),
      'Choose an existing account.',
    );
    final today = now ?? DateTime.now();
    require(
      entry.date.year >= 1900 &&
          !entry.date.isAfter(
            DateTime(today.year, today.month, today.day, 23, 59, 59),
          ),
      'Choose a valid date today or earlier.',
    );
    require(
      entry.sourceKey == null ||
          !state.entries.any((e) => e.sourceKey == entry.sourceKey),
      'This imported row has already been saved.',
    );
    if (entry.kind == EntryKind.transfer) {
      require(
        entry.toAccountId != entry.accountId &&
            state.accounts.any((a) => a.id == entry.toAccountId),
        'Choose a different destination account.',
      );
    } else {
      require(
        entry.toAccountId == null,
        'Only transfers have a destination account.',
      );
    }
    if (entry.kind == EntryKind.expense || entry.kind == EntryKind.income) {
      require(entry.lines.isNotEmpty, 'Add at least one category or item.');
      require(
        entry.lines.fold(0, (v, item) => v + item.amountMinor) ==
            entry.amountMinor,
        'Item amounts must equal the transaction total.',
      );
      for (final line in entry.lines) {
        require(
          line.amountMinor > 0 && line.description.trim().isNotEmpty,
          'Every item needs a name and a positive amount.',
        );
        require(
          categories[line.category]?.contains(line.subcategory) == true,
          'Choose a valid category and subcategory.',
        );
      }
    } else {
      require(
        entry.lines.isEmpty,
        'Transfers and debts do not count as income or expenses.',
      );
    }
    require(entry.payer.trim().isNotEmpty, 'Who paid?');
    if (entry.kind == EntryKind.bankDebit ||
        entry.kind == EntryKind.bankCredit) {
      require(
        entry.metadataPending,
        'Classify the captured bank movement before completing review.',
      );
    }
    if (entry.kind != EntryKind.expense) {
      require(
        entry.shares.isEmpty && entry.paidByMe,
        'People splits apply to expenses.',
      );
    } else if (!entry.paidByMe) {
      require(
        entry.shares.isNotEmpty,
        'Specify your share when someone else paid.',
      );
    }
    if (entry.shares.isNotEmpty) {
      require(
        entry.shares.fold(0, (sum, s) => sum + s.amountMinor) ==
            entry.amountMinor,
        'People shares must equal the total.',
      );
      final names = entry.shares.map((s) => personKey(s.person)).toSet();
      require(
        names.length == entry.shares.length && !names.contains(''),
        'Use a unique name for every person.',
      );
      require(
        names.contains(personKey(selfPerson)),
        'Include You in the split.',
      );
      require(
        names.contains(personKey(entry.payer)),
        'The payer must be included in the split.',
      );
      require(
        entry.shares.every((s) => s.amountMinor >= 0),
        'Shares cannot be negative.',
      );
    }
    final isDebt = {
      EntryKind.lent,
      EntryKind.borrowed,
      EntryKind.repaymentPaid,
      EntryKind.repaymentReceived,
    }.contains(entry.kind);
    if (isDebt) {
      require(
        entry.counterparty != null &&
            entry.counterparty!.trim().isNotEmpty &&
            personKey(entry.counterparty!) != personKey(selfPerson),
        'Name the other person.',
      );
      final debt = state.debtFor(entry.counterparty!);
      if (entry.kind == EntryKind.repaymentReceived) {
        require(
          debt > 0 && entry.amountMinor <= debt,
          'Repayment exceeds what this person owes you.',
        );
      }
      if (entry.kind == EntryKind.repaymentPaid) {
        require(
          debt < 0 && entry.amountMinor <= -debt,
          'Repayment exceeds what you owe this person.',
        );
      }
    } else {
      require(
        entry.counterparty == null,
        'Use people splits for shared expenses.',
      );
    }
  }

  static LedgerState append(LedgerState current, List<LedgerEntry> entries) {
    var next = current;
    for (final entry in entries) {
      validate(entry, next);
      next = next.copyWith(entries: [...next.entries, entry]);
    }
    // Fail before storage if any projected total overflows our safe range.
    for (final account in next.accounts) {
      next.balance(account.id);
    }
    next.netWorthMinor;
    return next;
  }
}
