import 'package:flutter/material.dart';
import '../application/ledger_controller.dart';
import '../domain/import_parser.dart';
import '../domain/models.dart';
import '../domain/money.dart';
import 'theme.dart';

Future<void> showTransactionForm(
  BuildContext context,
  LedgerController controller, {
  TransactionDraft? draft,
  LedgerEntry? existing,
  EntryKind? kind,
  String? person,
  int? amount,
  String? accountId,
  CapturedTransaction? capture,
}) async {
  if (controller.state.accounts.isEmpty) {
    await showAccountForm(context, controller);
    if (!context.mounted || controller.state.accounts.isEmpty) return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => TransactionForm(
      controller: controller,
      draft: draft,
      existing: existing,
      kind: kind,
      person: person,
      amount: amount,
      accountId: accountId,
      capture: capture,
    ),
  );
}

class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saving = false,
    this.saveLabel = 'Save',
  });
  final String title, saveLabel;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool saving;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children
                      .expand((w) => [w, const SizedBox(height: 14)])
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : onSave,
              child: Text(saving ? 'Saving…' : saveLabel),
            ),
          ],
        ),
      ),
    ),
  );
}

class TransactionForm extends StatefulWidget {
  const TransactionForm({
    super.key,
    required this.controller,
    this.draft,
    this.existing,
    this.kind,
    this.person,
    this.amount,
    this.accountId,
    this.capture,
  });
  final LedgerController controller;
  final TransactionDraft? draft;
  final LedgerEntry? existing;
  final EntryKind? kind;
  final String? person, accountId;
  final int? amount;
  final CapturedTransaction? capture;
  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _LineFields {
  _LineFields({
    String text = '',
    String amount = '',
    this.category = 'Other',
    this.subcategory = 'Uncategorised',
  }) : name = TextEditingController(text: text),
       amount = TextEditingController(text: amount);
  final TextEditingController name, amount;
  String category, subcategory;
  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _TransactionFormState extends State<TransactionForm> {
  late EntryKind _kind;
  late String _account;
  String? _destination;
  late final TextEditingController _description,
      _amount,
      _date,
      _person,
      _names,
      _merchant;
  String _category = 'Other',
      _subcategory = 'Uncategorised',
      _payer = selfPerson;
  bool _itemise = false, _split = false, _custom = false, _saving = false;
  String? _error;
  final _lines = <_LineFields>[];
  final _customShares = <String, TextEditingController>{};
  bool get _categorised =>
      _kind == EntryKind.expense || _kind == EntryKind.income;
  bool get _debt => {
    EntryKind.lent,
    EntryKind.borrowed,
    EntryKind.repaymentPaid,
    EntryKind.repaymentReceived,
  }.contains(_kind);
  List<String> get _people => [
    selfPerson,
    ..._names.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && personKey(s) != 'you'),
  ];
  @override
  void initState() {
    super.initState();
    final e = widget.existing, d = widget.draft;
    _merchant = TextEditingController(
      text: widget.capture?.merchant ?? e?.merchant ?? '',
    );
    _kind = e?.kind ?? widget.kind ?? d?.kind ?? EntryKind.expense;
    if (_kind == EntryKind.bankDebit || _kind == EntryKind.bankCredit) {
      _kind =
          d?.kind ??
          (_kind == EntryKind.bankDebit ? EntryKind.expense : EntryKind.income);
    }
    _account =
        e?.accountId ??
        widget.accountId ??
        widget.controller.state.accounts.first.id;
    _destination = e?.toAccountId;
    _description = TextEditingController(
      text:
          e?.description ??
          d?.description ??
          (widget.person == null ? '' : 'Repayment · ${widget.person}'),
    );
    final initialAmount = e?.amountMinor ?? widget.amount ?? d?.amountMinor;
    _amount = TextEditingController(
      text: initialAmount == null ? '' : moneyInput(initialAmount),
    );
    _date = TextEditingController(
      text: dateInput(e?.date ?? d?.date ?? DateTime.now()),
    );
    _person = TextEditingController(
      text: e?.counterparty ?? widget.person ?? '',
    );
    _names = TextEditingController(
      text: e != null
          ? e.shares
                .where((s) => personKey(s.person) != 'you')
                .map((s) => s.person)
                .join(', ')
          : d?.people.join(', ') ?? '',
    );
    _category =
        e?.lines.firstOrNull?.category ??
        d?.category ??
        (_kind == EntryKind.income ? 'Income' : 'Other');
    _subcategory =
        e?.lines.firstOrNull?.subcategory ??
        d?.subcategory ??
        (_kind == EntryKind.income ? 'Other' : 'Uncategorised');
    _payer = e?.payer ?? selfPerson;
    _split = _names.text.isNotEmpty;
    _itemise = (e?.lines.length ?? 0) > 1;
    if ((e?.lines.isEmpty ?? true) &&
        (widget.capture?.items.isNotEmpty ?? false)) {
      _itemise = true;
      for (final item in widget.capture!.items) {
        _lines.add(
          _LineFields(
            text: item.description,
            amount: moneyInput(item.amountMinor),
            category: item.category,
            subcategory: item.subcategory,
          ),
        );
      }
    }
    if (e != null) {
      for (final l in e.lines) {
        _lines.add(
          _LineFields(
            text: l.description,
            amount: moneyInput(l.amountMinor),
            category: l.category,
            subcategory: l.subcategory,
          ),
        );
      }
      if (e.shares.isNotEmpty) {
        _custom = true;
        for (final s in e.shares) {
          _customShares[s.person] = TextEditingController(
            text: moneyInput(s.amountMinor),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _description,
      _merchant,
      _amount,
      _date,
      _person,
      _names,
      ..._customShares.values,
    ]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    TextInputType? keyboard,
  }) => TextField(
    controller: c,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
  Widget _categoryPicker(
    String cat,
    String sub,
    void Function(String, String) change,
  ) => Column(
    children: [
      DropdownButtonFormField<String>(
        key: ValueKey('cat-$cat'),
        initialValue: cat,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Category'),
        items: categories.keys
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (c) {
          if (c != null) setState(() => change(c, categories[c]!.first));
        },
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        key: ValueKey('sub-$cat-$sub'),
        initialValue: sub,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Subcategory'),
        items: categories[cat]!
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (s) {
          if (s != null) setState(() => change(cat, s));
        },
      ),
    ],
  );
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final total = parseMoney(_amount.text);
      final lines = !_categorised
          ? <LineItem>[]
          : _itemise
          ? _lines
                .map(
                  (l) => LineItem(
                    description: l.name.text.trim(),
                    amountMinor: parseMoney(l.amount.text),
                    category: l.category,
                    subcategory: l.subcategory,
                  ),
                )
                .toList()
          : [
              LineItem(
                description: _description.text.trim(),
                amountMinor: total,
                category: _category,
                subcategory: _subcategory,
              ),
            ];
      final people = _people;
      final amounts = splitEqually(total, people.length);
      final shares = _kind != EntryKind.expense || !_split
          ? <Share>[]
          : List.generate(
              people.length,
              (i) => Share(
                person: people[i],
                amountMinor: _custom
                    ? parseMoney(_customShares[people[i]]?.text ?? '')
                    : amounts[i],
              ),
            );
      final entry = LedgerEntry(
        id: widget.existing?.id ?? widget.controller.newId(),
        kind: _kind,
        accountId: _account,
        amountMinor: total,
        date: parseDate(_date.text),
        description: _description.text.trim(),
        lines: lines,
        shares: shares,
        payer: _kind == EntryKind.expense && _split ? _payer : selfPerson,
        toAccountId: _kind == EntryKind.transfer ? _destination : null,
        counterparty: _debt ? _person.text.trim() : null,
        sourceKey: widget.existing?.sourceKey ?? widget.draft?.sourceKey,
        source: widget.existing?.source ?? widget.draft?.source ?? 'manual',
        merchant: _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
        externalReference:
            widget.capture?.reference ?? widget.existing?.externalReference,
        metadataPending: false,
        reviewedAt: DateTime.now(),
      );
      if (widget.capture != null) {
        await widget.controller.confirmCapture(widget.capture!.id, entry);
      } else if (widget.existing == null) {
        await widget.controller.addEntries([entry]);
      } else {
        await widget.controller.replaceEntry(entry);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message.toString()
              : 'Could not save. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = _people.toSet().toList();
    if (!people.contains(_payer)) _payer = selfPerson;
    return FormDialog(
      title: widget.existing != null
          ? 'Edit transaction'
          : widget.draft != null
          ? 'Review transaction'
          : 'Add a transaction',
      onSave: _save,
      saving: _saving,
      saveLabel: widget.draft != null
          ? 'Confirm & save transaction'
          : 'Save transaction',
      children: [
        if (widget.draft != null)
          Notice(
            [
              widget.capture?.linkedEntryId != null
                  ? 'The bank movement already affects your balance. Completing review updates this same transaction.'
                  : 'Review extracted details before posting this transaction.',
              ...widget.draft!.questions,
            ].join('\n'),
          ),
        DropdownButtonFormField<EntryKind>(
          isExpanded: true,
          initialValue: _kind,
          decoration: const InputDecoration(labelText: 'Transaction type'),
          items: EntryKind.values
              .where(
                (k) => k != EntryKind.bankDebit && k != EntryKind.bankCredit,
              )
              .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
              .toList(),
          onChanged: (k) => setState(() {
            if (k != null) _kind = k;
          }),
        ),
        _field(_description, 'Description', hint: 'What was this for?'),
        _field(
          _merchant,
          'Merchant or payer (optional)',
          hint: 'For automatic categories and merchant analytics',
        ),
        _field(
          _amount,
          'Total amount (₹)',
          hint: '0.00',
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        _field(
          _date,
          'Date (YYYY-MM-DD)',
          hint: '2026-10-10',
          keyboard: TextInputType.datetime,
        ),
        DropdownButtonFormField<String>(
          initialValue: _account,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _kind == EntryKind.transfer
                ? 'From account'
                : 'Your account',
          ),
          items: widget.controller.state.accounts
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (a) => setState(() {
            if (a != null) _account = a;
          }),
        ),
        if (_kind == EntryKind.transfer)
          DropdownButtonFormField<String>(
            initialValue: _destination,
            decoration: const InputDecoration(labelText: 'To account'),
            items: widget.controller.state.accounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (a) => setState(() => _destination = a),
          ),
        if (_debt)
          _field(
            _person,
            'Other person’s name',
            hint: 'Use the same name for repayments',
          ),
        if (!_categorised)
          const Notice(
            'This changes account and debt balances. It does not count as income or spending.',
          ),
        if (_categorised) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Split into items'),
            subtitle: const Text('Give each item its own category'),
            value: _itemise,
            onChanged: (value) => setState(() {
              _itemise = value;
              if (_lines.isEmpty) {
                _lines.add(
                  _LineFields(
                    text: _description.text,
                    amount: _amount.text,
                    category: _category,
                    subcategory: _subcategory,
                  ),
                );
              }
            }),
          ),
          if (!_itemise)
            _categoryPicker(_category, _subcategory, (c, s) {
              _category = c;
              _subcategory = s;
            }),
          if (_itemise) ...[
            for (var i = 0; i < _lines.length; i++)
              Panel(
                padding: 14,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Item ${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove item',
                          onPressed: () =>
                              setState(() => _lines.removeAt(i).dispose()),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    _field(_lines[i].name, 'Item description'),
                    const SizedBox(height: 10),
                    _field(
                      _lines[i].amount,
                      'Item amount (₹)',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _categoryPicker(_lines[i].category, _lines[i].subcategory, (
                      c,
                      s,
                    ) {
                      _lines[i].category = c;
                      _lines[i].subcategory = s;
                    }),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _lines.add(_LineFields())),
              icon: const Icon(Icons.add),
              label: const Text('Add another item'),
            ),
          ],
        ],
        if (_kind == EntryKind.expense) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share this expense'),
            subtitle: const Text('Track exactly who owes whom'),
            value: _split,
            onChanged: (v) => setState(() => _split = v),
          ),
          if (_split) ...[
            TextField(
              controller: _names,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Other people (comma-separated)',
                hintText: 'Aarav, Meera',
              ),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(_payer),
              initialValue: _payer,
              decoration: const InputDecoration(labelText: 'Who paid?'),
              items: people
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (p) => setState(() => _payer = p ?? selfPerson),
            ),
            if (_payer != selfPerson)
              const Notice(
                'Your account balance stays unchanged until you record a repayment. Only your share counts as your spending.',
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Custom amounts'),
              subtitle: const Text('Otherwise split equally, including you'),
              value: _custom,
              onChanged: (v) => setState(() => _custom = v),
            ),
            if (_custom)
              for (final p in people)
                _field(
                  _customShares.putIfAbsent(p, () => TextEditingController()),
                  '$p · share (₹)',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
            const Notice(
              'Names are local labels. No invitations or messages are sent when you save.',
            ),
          ],
        ],
        if (_error != null) Notice(_error!, color: coral),
      ],
    );
  }
}

Future<void> showAccountForm(
  BuildContext context,
  LedgerController controller,
) async {
  final name = TextEditingController(),
      opening = TextEditingController(text: '0');
  var type = 'Bank', saving = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, set) => FormDialog(
        title: 'Add an account',
        saving: saving,
        saveLabel: 'Create account',
        onSave: () async {
          set(() {
            saving = true;
            error = null;
          });
          try {
            await controller.addAccount(
              Account(
                id: controller.newId(),
                name: name.text.trim(),
                type: type,
                openingMinor: parseMoney(opening.text, allowNegative: true),
              ),
            );
            if (context.mounted) Navigator.pop(context);
          } catch (e) {
            if (context.mounted) {
              set(
                () => error = e is FormatException
                    ? e.message.toString()
                    : 'Unable to save account.',
              );
            }
          } finally {
            if (context.mounted) set(() => saving = false);
          }
        },
        children: [
          const Notice(
            'A manual account stays on this device. Bank connections will be added through a supported provider.',
          ),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Account nickname',
              hintText: 'Everyday account',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              'Bank',
              'Savings',
              'Cash',
              'Wallet',
              'Credit card',
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (t) => set(() => type = t!),
          ),
          TextField(
            controller: opening,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Opening balance (₹)',
              helperText:
                  'Before recorded transactions. Enter card debt as a negative balance.',
            ),
          ),
          if (error != null) Notice(error!, color: coral),
        ],
      ),
    ),
  );
  name.dispose();
  opening.dispose();
}

Future<void> showHoldingForm(
  BuildContext context,
  LedgerController controller, {
  Holding? holding,
}) async {
  final name = TextEditingController(text: holding?.name ?? ''),
      cost = TextEditingController(
        text: holding == null ? '' : moneyInput(holding.costMinor),
      ),
      value = TextEditingController(
        text: holding == null ? '' : moneyInput(holding.valueMinor),
      ),
      date = TextEditingController(
        text: dateInput(holding?.valuedAt ?? DateTime.now()),
      );
  var asset = holding?.assetClass ?? 'Mutual fund', saving = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, set) => FormDialog(
        title: holding == null ? 'Add an investment' : 'Update valuation',
        saving: saving,
        onSave: () async {
          set(() {
            saving = true;
            error = null;
          });
          try {
            await controller.saveHolding(
              Holding(
                id: holding?.id ?? controller.newId(),
                name: name.text.trim(),
                assetClass: asset,
                costMinor: parseMoney(cost.text),
                valueMinor: parseMoney(value.text),
                valuedAt: parseDate(date.text),
              ),
            );
            if (context.mounted) Navigator.pop(context);
          } catch (e) {
            if (context.mounted) {
              set(
                () => error = e is FormatException
                    ? e.message.toString()
                    : 'Unable to save investment.',
              );
            }
          } finally {
            if (context.mounted) set(() => saving = false);
          }
        },
        children: [
          const Notice(
            'Track an existing position with a manual valuation. This does not move money in your accounts. Exclude investment value from account balances to avoid counting it twice.',
          ),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Investment name'),
          ),
          DropdownButtonFormField<String>(
            initialValue: asset,
            decoration: const InputDecoration(labelText: 'Asset class'),
            items: [
              'Mutual fund',
              'Equity',
              'ETF',
              'Fixed income',
              'Gold',
              'Other',
            ].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (a) => set(() => asset = a!),
          ),
          TextField(
            controller: cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Total cost of current position (₹)',
            ),
          ),
          TextField(
            controller: value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Current market value (₹)',
            ),
          ),
          TextField(
            controller: date,
            decoration: const InputDecoration(
              labelText: 'Valuation date (YYYY-MM-DD)',
            ),
          ),
          if (error != null) Notice(error!, color: coral),
        ],
      ),
    ),
  );
  for (final c in [name, cost, value, date]) {
    c.dispose();
  }
}
