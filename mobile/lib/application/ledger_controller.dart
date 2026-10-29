import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/ledger_repository.dart';
import '../domain/ledger.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import '../domain/capture_parser.dart';
import '../data/bank_sms_bridge.dart';

class LedgerController extends ChangeNotifier {
  LedgerController(this.repository, {this.isDemo = false});
  final LedgerRepository repository;
  final bool isDemo;
  LedgerState _state = LedgerState();
  bool _saving = false;
  LedgerState get state => _state;
  bool get saving => _saving;
  String newId() => const Uuid().v4();
  Future<void> load() async {
    _state = await repository.load();
    notifyListeners();
  }

  Future<void> _commit(LedgerState next) async {
    if (_saving) {
      throw StateError('A save is already in progress. Please try again.');
    }
    _saving = true;
    notifyListeners();
    try {
      await repository.commit(_state, next);
      _state = next;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> addEntries(List<LedgerEntry> entries) =>
      _commit(LedgerRules.append(_state, entries));
  Future<void> replaceEntry(LedgerEntry entry) {
    final entries = _state.entries
        .map((e) => e.id == entry.id ? entry : e)
        .toList();
    if (!_state.entries.any((e) => e.id == entry.id)) {
      throw const FormatException('Transaction no longer exists.');
    }
    final next = LedgerRules.append(_state.copyWith(entries: []), entries);
    return _commit(
      next.copyWith(
        captures: next.captures
            .map(
              (c) => c.linkedEntryId == entry.id && !entry.metadataPending
                  ? c.copyWith(status: CaptureStatus.reviewed)
                  : c,
            )
            .toList(),
      ),
    );
  }

  Future<void> deleteEntry(String id) => _commit(
    LedgerRules.append(
      _state.copyWith(entries: []),
      _state.entries.where((e) => e.id != id).toList(),
    ).copyWith(
      captures: _state.captures
          .map(
            (c) => c.linkedEntryId == id
                ? c.copyWith(status: CaptureStatus.dismissed)
                : c,
          )
          .toList(),
    ),
  );
  Future<void> addAccount(Account account) {
    if (account.name.trim().isEmpty ||
        _state.accounts.any(
          (a) =>
              a.id == account.id ||
              a.name.toLowerCase() == account.name.trim().toLowerCase(),
        )) {
      throw const FormatException('Choose a unique account name.');
    }
    checkedAmount(account.openingMinor);
    final next = _state.copyWith(accounts: [..._state.accounts, account]);
    next.netWorthMinor;
    return _commit(next);
  }

  Future<void> saveHolding(Holding holding) {
    if (holding.name.trim().isEmpty ||
        holding.costMinor < 0 ||
        holding.valueMinor < 0 ||
        holding.valuedAt.isAfter(DateTime.now())) {
      throw const FormatException(
        'Enter a name, non-negative values and a valuation date today or earlier.',
      );
    }
    checkedAmount(holding.costMinor);
    checkedAmount(holding.valueMinor);
    final next = _state.copyWith(
      holdings: [..._state.holdings.where((h) => h.id != holding.id), holding],
    );
    next.netWorthMinor;
    return _commit(next);
  }

  Future<void> clearLocalData() => _commit(LedgerState());

  Future<void> mapBankAccount(
    String accountId,
    String lastFour,
    String sender,
  ) {
    if (!_state.accounts.any((a) => a.id == accountId)) {
      throw const FormatException('Account no longer exists.');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(lastFour) || sender.trim().isEmpty) {
      throw const FormatException(
        'Enter the last four account digits and an exact bank sender ID.',
      );
    }
    if (_state.accounts.any(
      (a) =>
          a.id != accountId &&
          a.lastFour == lastFour &&
          _senderKey(a.smsSender ?? '') == _senderKey(sender),
    )) {
      throw const FormatException(
        'This bank identifier is already assigned to another account.',
      );
    }
    return _commit(
      _state.copyWith(
        accounts: _state.accounts
            .map(
              (a) => a.id == accountId
                  ? Account(
                      id: a.id,
                      name: a.name,
                      type: a.type,
                      openingMinor: a.openingMinor,
                      lastFour: lastFour,
                      smsSender: sender.trim(),
                    )
                  : a,
            )
            .toList(),
      ),
    );
  }

  Future<int> stageCaptures(
    List<ParsedCapture> parsed, {
    String? accountId,
    String? sender,
    bool bankEvent = false,
  }) async {
    var next = _state;
    var count = 0;
    for (final p in parsed) {
      final evidenceKey = '${p.source}:${p.evidenceKey}';
      if (!p.isFinancialTransaction ||
          next.captures.any(
            (c) =>
                c.evidenceKey == evidenceKey ||
                (c.source == p.source && c.evidenceKey == p.evidenceKey),
          )) {
        continue;
      }
      String? matchedAccount = accountId;
      if (matchedAccount == null && p.accountHint != null && sender != null) {
        final matches = next.accounts
            .where(
              (a) =>
                  a.lastFour == p.accountHint &&
                  a.smsSender != null &&
                  _senderKey(a.smsSender!) == _senderKey(sender),
            )
            .toList();
        if (matches.length == 1) matchedAccount = matches.single.id;
      }
      if (matchedAccount != null &&
          !next.accounts.any((a) => a.id == matchedAccount)) {
        throw const FormatException('Account no longer exists.');
      }
      final rule = p.merchant == null
          ? null
          : next.merchantRules
                .where(
                  (r) =>
                      r.merchant == _merchantKey(p.merchant!) &&
                      r.kind == p.kind,
                )
                .firstOrNull;
      final questions = [...p.questions];
      if (matchedAccount == null) {
        questions.add(
          'Choose the account. Add its bank sender and last four digits for future automatic matching.',
        );
      }
      bool sameAccountDirection(LedgerEntry e) {
        if (matchedAccount == null) return false;
        if (e.kind == EntryKind.transfer) {
          return p.kind == EntryKind.expense
              ? e.accountId == matchedAccount
              : p.kind == EntryKind.income && e.toAccountId == matchedAccount;
        }
        if (e.accountId != matchedAccount) return false;
        return p.kind == EntryKind.expense
            ? {
                EntryKind.expense,
                EntryKind.bankDebit,
                EntryKind.lent,
                EntryKind.repaymentPaid,
              }.contains(e.kind)
            : p.kind == EntryKind.income &&
                  {
                    EntryKind.income,
                    EntryKind.bankCredit,
                    EntryKind.borrowed,
                    EntryKind.repaymentReceived,
                  }.contains(e.kind);
      }

      final referenceMatch = p.reference == null
          ? null
          : next.entries
                .where(
                  (e) =>
                      sameAccountDirection(e) &&
                      e.externalReference != null &&
                      _referenceKey(e.externalReference!) ==
                          _referenceKey(p.reference!),
                )
                .firstOrNull;
      final exact = referenceMatch?.amountMinor == p.amountMinor
          ? referenceMatch
          : null;
      final possible =
          referenceMatch ??
          next.entries
              .where(
                (e) =>
                    sameAccountDirection(e) &&
                    p.amountMinor == e.amountMinor &&
                    p.occurredAt != null &&
                    _dateKey(e.date) == _dateKey(p.occurredAt!) &&
                    (p.reference == null || e.externalReference == null),
              )
              .firstOrNull;
      if (referenceMatch != null && exact == null) {
        questions.add(
          'This bank reference already exists with a different amount. Resolve the discrepancy; no additional movement was posted.',
        );
      }
      if (possible != null) {
        questions.add(
          'A matching amount and date already exists. Link the evidence or explicitly record a separate transaction.',
        );
      }
      var capture = CapturedTransaction(
        id: newId(),
        source: p.source,
        evidenceKey: evidenceKey,
        description: p.description,
        capturedAt: DateTime.now(),
        amountMinor: p.amountMinor,
        date: p.occurredAt,
        kind: p.kind,
        merchant: p.merchant,
        accountHint: p.accountHint,
        reference: p.reference,
        sender: sender,
        accountId: matchedAccount,
        possibleDuplicateEntryId: possible?.id,
        category: rule?.category ?? p.suggestedCategory,
        subcategory: rule?.subcategory ?? p.suggestedSubcategory,
        confidence: rule == null ? p.confidence : 1,
        questions: questions,
        items: p.items,
      );
      if (exact != null) {
        capture = capture.copyWith(
          linkedEntryId: exact.id,
          status: CaptureStatus.linked,
        );
      } else if (bankEvent &&
          p.source == 'bank_sms' &&
          matchedAccount != null &&
          possible == null &&
          p.amountMinor != null &&
          p.amountMinor! > 0 &&
          p.occurredAt != null &&
          !p.occurredAt!.isAfter(DateTime.now()) &&
          (p.kind == EntryKind.expense || p.kind == EntryKind.income)) {
        final entry = LedgerEntry(
          id: newId(),
          kind: p.kind == EntryKind.expense
              ? EntryKind.bankDebit
              : EntryKind.bankCredit,
          accountId: matchedAccount,
          amountMinor: p.amountMinor!,
          date: p.occurredAt!,
          description: p.description,
          metadataPending: true,
          merchant: p.merchant,
          externalReference: p.reference,
          sourceKey: evidenceKey,
          source: p.source,
        );
        next = LedgerRules.append(next, [entry]);
        capture = capture.copyWith(
          linkedEntryId: entry.id,
          status: CaptureStatus.posted,
        );
      }
      next = next.copyWith(captures: [...next.captures, capture]);
      count++;
    }
    if (count > 0) await _commit(next);
    return count;
  }

  Future<int> collectBankMessages() async {
    if (isDemo || saving) return 0;
    const bridge = BankSmsBridge();
    if (!bridge.supported) return 0;
    final messages = await bridge.pending();
    final acknowledged = <String>[];
    var count = 0;
    for (final message in messages) {
      final parsed = parseBankSms(
        message.body,
        sender: message.sender,
        receivedAt: message.receivedAt,
      );
      if (parsed != null) {
        count += await stageCaptures(
          [parsed],
          sender: message.sender,
          bankEvent: true,
        );
      }
      acknowledged.add(message.id);
    }
    if (acknowledged.isNotEmpty) await bridge.acknowledge(acknowledged);
    return count;
  }

  Future<void> confirmCapture(
    String id,
    LedgerEntry entry, {
    bool rememberMerchant = true,
  }) {
    final capture = _state.captures.firstWhere((c) => c.id == id);
    if (!capture.needsReview) {
      throw const FormatException('This capture has already been handled.');
    }
    if (capture.linkedEntryId == null &&
        _state.entries.any((e) => e.id == entry.id)) {
      throw const FormatException(
        'A new capture cannot overwrite another transaction.',
      );
    }
    if (capture.linkedEntryId != null && capture.linkedEntryId != entry.id) {
      throw const FormatException(
        'Review must update the original captured transaction.',
      );
    }
    final reviewed = entry.copyWith(
      metadataPending: false,
      merchant: entry.merchant ?? capture.merchant,
      externalReference: capture.reference,
      reviewedAt: DateTime.now(),
    );
    var entries = [..._state.entries];
    final originalIndex = entries.indexWhere((e) => e.id == reviewed.id);
    if (originalIndex < 0) {
      entries.add(reviewed);
    } else {
      entries[originalIndex] = reviewed;
    }
    final mergedIds = <String>{};
    if (reviewed.kind == EntryKind.transfer && capture.reference != null) {
      for (final other in entries) {
        if (other.id == reviewed.id ||
            !other.metadataPending ||
            other.amountMinor != reviewed.amountMinor ||
            other.externalReference == null ||
            _referenceKey(other.externalReference!) !=
                _referenceKey(capture.reference!) ||
            _dateKey(other.date) != _dateKey(reviewed.date)) {
          continue;
        }
        if ((other.kind == EntryKind.bankCredit &&
                other.accountId == reviewed.toAccountId) ||
            (other.kind == EntryKind.bankDebit &&
                other.accountId == reviewed.accountId)) {
          mergedIds.add(other.id);
        }
      }
      entries.removeWhere((e) => mergedIds.contains(e.id));
    }
    var next = LedgerRules.append(_state.copyWith(entries: []), entries);
    next = next.copyWith(
      captures: next.captures
          .map(
            (c) =>
                c.id == id ||
                    c.linkedEntryId == reviewed.id ||
                    mergedIds.contains(c.linkedEntryId)
                ? c.copyWith(
                    status: CaptureStatus.reviewed,
                    linkedEntryId: reviewed.id,
                    accountId: reviewed.accountId,
                  )
                : c,
          )
          .toList(),
    );
    if (rememberMerchant &&
        reviewed.merchant != null &&
        reviewed.lines.length == 1) {
      final merchant = _merchantKey(reviewed.merchant!);
      final rule = MerchantRule(
        id: '${reviewed.kind.name}:$merchant',
        merchant: merchant,
        kind: reviewed.kind,
        category: reviewed.lines.single.category,
        subcategory: reviewed.lines.single.subcategory,
      );
      next = next.copyWith(
        merchantRules: [
          ...next.merchantRules.where((r) => r.id != rule.id),
          rule,
        ],
      );
    }
    return _commit(next);
  }

  Future<void> linkCapture(String captureId, String entryId) {
    final capture = _state.captures.firstWhere((c) => c.id == captureId);
    if (!capture.needsReview || capture.linkedEntryId != null) {
      throw const FormatException('This capture is already posted or handled.');
    }
    final entry = _state.entries.firstWhere((e) => e.id == entryId);
    if (capture.kind == EntryKind.expense || capture.kind == EntryKind.income) {
      final debit = capture.kind == EntryKind.expense;
      final matchesDirection = entry.kind == EntryKind.transfer
          ? capture.accountId != null &&
                capture.accountId ==
                    (debit ? entry.accountId : entry.toAccountId)
          : (debit
                    ? {
                        EntryKind.expense,
                        EntryKind.bankDebit,
                        EntryKind.lent,
                        EntryKind.repaymentPaid,
                      }
                    : {
                        EntryKind.income,
                        EntryKind.bankCredit,
                        EntryKind.borrowed,
                        EntryKind.repaymentReceived,
                      })
                .contains(entry.kind);
      if (!matchesDirection) {
        throw const FormatException('Debit/credit direction does not match.');
      }
    }
    if (capture.accountId != null &&
        capture.accountId != entry.accountId &&
        capture.accountId != entry.toAccountId) {
      throw const FormatException('Accounts do not match.');
    }
    if (capture.amountMinor != null &&
        capture.amountMinor != entry.amountMinor) {
      throw const FormatException(
        'Amounts do not match. Review the capture instead.',
      );
    }
    return _commit(
      _state.copyWith(
        captures: _state.captures
            .map(
              (c) => c.id == captureId
                  ? c.copyWith(
                      status: CaptureStatus.linked,
                      linkedEntryId: entryId,
                      accountId: capture.accountId ?? entry.accountId,
                    )
                  : c,
            )
            .toList(),
      ),
    );
  }

  Future<void> dismissCapture(String id) {
    final capture = _state.captures.firstWhere((c) => c.id == id);
    if (!capture.needsReview) {
      throw const FormatException('This capture has already been handled.');
    }
    final entries = _state.entries
        .where((e) => !(capture.linkedEntryId == e.id && e.metadataPending))
        .toList();
    final next = LedgerRules.append(_state.copyWith(entries: []), entries);
    return _commit(
      next.copyWith(
        captures: next.captures
            .map(
              (c) =>
                  c.id == id ||
                      (c.linkedEntryId != null &&
                          !entries.any((e) => e.id == c.linkedEntryId))
                  ? c.copyWith(status: CaptureStatus.dismissed)
                  : c,
            )
            .toList(),
      ),
    );
  }

  Future<void> forgetMerchantRules() =>
      _commit(_state.copyWith(merchantRules: []));
  static String _merchantKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  static String _referenceKey(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  static String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  static String _senderKey(String value) => value
      .trim()
      .toUpperCase()
      .replaceFirst(RegExp(r'^[A-Z0-9]{2}-'), '')
      .replaceFirst(RegExp(r'-[A-Z]$'), '');
}
