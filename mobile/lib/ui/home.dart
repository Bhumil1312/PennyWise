import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../application/ledger_controller.dart';
import '../domain/import_parser.dart';
import '../domain/models.dart';
import 'forms.dart';
import 'import_dialog.dart';
import 'privacy.dart';
import 'theme.dart';
import 'capture_inbox.dart';
import 'analytics_screen.dart';
import '../data/bank_sms_bridge.dart';

const _destinations = <(IconData, String)>[
  (Icons.space_dashboard_outlined, 'Overview'),
  (Icons.swap_horiz_rounded, 'Activity'),
  (Icons.account_balance_wallet_outlined, 'Accounts'),
  (Icons.people_outline_rounded, 'People'),
  (Icons.show_chart_rounded, 'Investments'),
  (Icons.flag_outlined, 'Plans'),
  (Icons.tune_rounded, 'Settings'),
  (Icons.inbox_outlined, 'Review inbox'),
  (Icons.insights_outlined, 'Analytics'),
];

class FinanceHome extends StatefulWidget {
  const FinanceHome({
    super.key,
    required this.controller,
    required this.onLock,
  });
  final LedgerController controller;
  final VoidCallback onLock;
  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _tab = 0;
  String _search = '', _filter = 'All';
  final _quick = TextEditingController();
  Timer? _captureTimer;
  bool _collecting = false;
  String? _captureError;
  LedgerState get data => widget.controller.state;
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isDemo && const BankSmsBridge().supported) {
      scheduleMicrotask(_collectMessages);
      _captureTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _collectMessages(),
      );
    }
  }

  Future<void> _collectMessages() async {
    if (_collecting || widget.controller.saving || widget.controller.isDemo) {
      return;
    }
    _collecting = true;
    try {
      await widget.controller.collectBankMessages();
      if (mounted && _captureError != null) {
        setState(() => _captureError = null);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _captureError =
              'Bank alerts are still queued. Processing could not finish; retry after unlocking. No queued message was removed without saving.',
        );
      }
    } finally {
      _collecting = false;
    }
  }

  @override
  void dispose() {
    _quick.dispose();
    _captureTimer?.cancel();
    super.dispose();
  }

  void _select(int i) => setState(() => _tab = i);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= 1050;
      return Scaffold(
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab < 5 ? _tab : 0,
                onDestinationSelected: _select,
                destinations: _destinations
                    .take(5)
                    .map(
                      (d) =>
                          NavigationDestination(icon: Icon(d.$1), label: d.$2),
                    )
                    .toList(),
              ),
        floatingActionButton: wide
            ? null
            : FloatingActionButton(
                tooltip: 'Add transaction',
                backgroundColor: forest,
                foregroundColor: Colors.white,
                onPressed: () =>
                    showTransactionForm(context, widget.controller),
                child: const Icon(Icons.add),
              ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) _sidebar(),
              Expanded(
                child: Column(
                  children: [
                    _topbar(wide),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 36 : 20,
                          28,
                          wide ? 36 : 20,
                          100,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1220),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.controller.isDemo) ...[
                                  const Notice(
                                    'DEMO WORKSPACE  ·  Sample data only. Your changes reset when this session closes.',
                                    icon: Icons.science_outlined,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                _heading(),
                                const SizedBox(height: 26),
                                if (_captureError != null) ...[
                                  Notice(_captureError!, color: coral),
                                  const SizedBox(height: 16),
                                ],
                                if (_tab != 7) ...[
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _select(7),
                                        icon: const Icon(
                                          Icons.inbox_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'Review inbox · ${data.reviewCount}',
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _select(8),
                                        icon: const Icon(
                                          Icons.insights_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Analytics'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                switch (_tab) {
                                  0 => _overview(),
                                  1 => _activity(),
                                  2 => _accounts(),
                                  3 => _people(),
                                  4 => _investments(),
                                  5 => _plans(),
                                  7 => CaptureInbox(
                                    controller: widget.controller,
                                    onImport: () => showImportDialog(
                                      context,
                                      widget.controller,
                                    ),
                                  ),
                                  8 => AnalyticsScreen(state: data),
                                  _ => _settings(),
                                },
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _sidebar() => Container(
    width: 224,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              backgroundColor: forest,
              foregroundColor: lime,
              radius: 18,
              child: Icon(Icons.spa_outlined, size: 22),
            ),
            SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'PennyWise',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 46),
        const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text(
            'YOUR WORKSPACE',
            style: TextStyle(fontSize: 10, letterSpacing: 1.8, color: muted),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color: _tab == i
                  ? forest.withValues(alpha: .08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                dense: true,
                selected: _tab == i,
                selectedColor: forest,
                leading: Icon(_destinations[i].$1, size: 21),
                title: Text(
                  _destinations[i].$2,
                  style: TextStyle(
                    fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: i == 5
                    ? const Text(
                        '02',
                        style: TextStyle(fontSize: 11, color: muted),
                      )
                    : null,
                onTap: () => _select(i),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: canvas,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: forest, size: 24),
              SizedBox(height: 12),
              Text(
                'Your money. Your space.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'Built for a private, on-device ledger.',
                style: TextStyle(fontSize: 11, height: 1.6, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Material(
          color: Colors.white,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.tune_rounded, size: 20),
            title: const Text('Settings'),
            onTap: () => _select(6),
          ),
        ),
      ],
    ),
  );

  Widget _topbar(bool wide) => Container(
    height: 76,
    padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (!wide)
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.spa_outlined, color: forest),
          ),
        Text(
          wide ? 'Personal workspace' : 'PennyWise',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const Spacer(),
        if (wide) ...[
          const Icon(Icons.circle, color: Color(0xFF86A36D), size: 7),
          const SizedBox(width: 7),
          Text(
            widget.controller.isDemo ? 'Preview mode' : 'On-device vault',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(width: 28),
        ],
        IconButton(
          tooltip: 'Settings',
          onPressed: () => _select(6),
          icon: const Icon(Icons.tune_rounded, size: 21),
        ),
        IconButton(
          tooltip: 'Lock workspace',
          onPressed: widget.onLock,
          icon: const Icon(Icons.lock_outline, size: 21),
        ),
        const SizedBox(width: 12),
        const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFEBDDCF),
          child: Text(
            'Y',
            style: TextStyle(
              color: forest,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _heading() {
    const titles = [
      'Your money, in focus.',
      'Every detail adds up.',
      'All your accounts. One place.',
      'Money between friends.',
      'A view of what’s growing.',
      'A plan that grows with you.',
      'Make this space yours.',
      'Every capture, accounted for.',
      'Understand the whole picture.',
    ];
    const subtitles = [
      'A little perspective on where you are, and where you’re going.',
      'Your income, spending and transfers, thoughtfully organised.',
      'Track balances privately, even when you’re offline.',
      'Shared moments. Clear balances. Fewer awkward conversations.',
      'Keep an eye on your investments, with the details that matter.',
      'Dynamic financial planning is reserved for phase two.',
      'Your privacy, your data, your choices.',
      'Review categories and details without recording the bank movement twice.',
      'Confirmed spending, clear categories, and comparable monthly trends.',
    ];
    return LayoutBuilder(
      builder: (context, c) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: c.maxWidth > 760 ? c.maxWidth - 210 : c.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tab == 0
                      ? DateFormat(
                          'EEEE, d MMMM',
                        ).format(DateTime.now()).toUpperCase()
                      : _destinations[_tab].$2.toUpperCase(),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  titles[_tab],
                  style: TextStyle(
                    fontSize: c.maxWidth < 500 ? 27 : 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  subtitles[_tab],
                  style: const TextStyle(
                    color: muted,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_tab == 0 || _tab == 1)
            FilledButton.icon(
              onPressed: () => showTransactionForm(context, widget.controller),
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Add transaction'),
            ),
        ],
      ),
    );
  }

  Widget _responsiveRow(List<Widget> children, {double breakpoint = 720}) =>
      LayoutBuilder(
        builder: (context, c) => c.maxWidth < breakpoint
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children
                    .expand((child) => [child, const SizedBox(height: 16)])
                    .toList(),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
      );

  Widget _overview() {
    final month = DateTime.now(),
        income = data.incomeFor(DateTime.now()),
        expense = data.expenseFor(DateTime.now());
    final recent = [...data.entries]..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _responsiveRow([
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: forest,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'TOTAL NET WORTH',
                      style: TextStyle(
                        color: Color(0xFFC1D2C8),
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.north_east, color: lime, size: 21),
                  ],
                ),
                const SizedBox(height: 22),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    rupees(data.netWorthMinor),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      letterSpacing: -1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'A snapshot of what you own, less what you owe.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFBDCDC2),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                const Divider(color: Color(0xFF4B6C5D)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _darkStat('ACCOUNTS', data.cashMinor),
                    const SizedBox(width: 22),
                    _darkStat('INVESTMENTS', data.investmentMinor),
                  ],
                ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'This month',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('MMM yyyy').format(month),
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _cashflowRow(
                  Icons.south_west_rounded,
                  'Money in',
                  income,
                  forest,
                ),
                const SizedBox(height: 20),
                _cashflowRow(
                  Icons.north_east_rounded,
                  'Your spending',
                  expense,
                  coral,
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: income > 0 ? (expense / income).clamp(0, 1) : 0,
                    backgroundColor: const Color(0xFFEDF1E8),
                    color: forest,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  income > 0
                      ? '${((income - expense) * 100 / income).toStringAsFixed(0)}% of this month’s income remains after spending'
                      : 'Add income to see this month’s spending ratio',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, color: forest, size: 21),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Less typing. More living.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Describe what happened. We’ll help you fill in the details.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _quick,
                onSubmitted: (_) => _reviewQuick(),
                decoration: InputDecoration(
                  hintText: '“Paid ₹1,200 for dinner with Aarav and Meera”',
                  suffixIcon: IconButton(
                    tooltip: 'Review description',
                    onPressed: _reviewQuick,
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: forest,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        showImportDialog(context, widget.controller),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Import a statement or receipt'),
                  ),
                  const Text(
                    'Always reviewed before it’s saved',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _responsiveRow([
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recent activity',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _select(1),
                      child: const Text('View all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  _empty(
                    'Your story starts with the first transaction.',
                    Icons.receipt_long_outlined,
                  ),
                ...recent.take(5).map(_entryRow),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'A week in perspective',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(Icons.bar_chart_rounded, color: muted, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your daily spending · last 7 days',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 28),
                _spendingChart(),
                const SizedBox(height: 26),
                const Divider(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.people_outline, color: forest, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data.debts.length} open ${data.debts.length == 1 ? 'balance' : 'balances'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'A clear view of your shared expenses',
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'View people',
                      onPressed: () => _select(3),
                      icon: const Icon(Icons.arrow_forward, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 24),
        InkWell(
          onTap: () => _select(5),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0DF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.park_outlined, size: 32, color: forest),
                SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Big dreams deserve a little planning.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Goals, scenarios and an adaptable financial plan. Coming in phase two.',
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Icon(Icons.arrow_forward, color: forest, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _darkStat(String name, int amount) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Color(0xFFABC4B4),
            fontSize: 9,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rupees(amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
  Widget _cashflowRow(IconData icon, String label, int amount, Color color) =>
      Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: color.withValues(alpha: .08),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 13),
          Text(label, style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                rupees(amount),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _spendingChart() {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - 6 + i),
    );
    final values = days
        .map(
          (d) => data.entries
              .where((e) => dateInput(e.date) == dateInput(d))
              .fold(0, (sum, e) => sum + e.myExpense),
        )
        .toList();
    final maximum = values.fold(1, math.max);
    return SizedBox(
      height: 145,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          7,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: '${dateLabel(days[i])}: ${rupees(values[i])}',
                    child: Container(
                      height: math.max(5, 108 * values[i] / maximum),
                      decoration: BoxDecoration(
                        color: i == 6 ? forest : const Color(0xFFD5DFC9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    DateFormat('E').format(days[i]).substring(0, 1),
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reviewQuick() async {
    if (_quick.text.trim().isEmpty) return;
    await showTransactionForm(
      context,
      widget.controller,
      draft: parseDescription(_quick.text),
    );
  }

  Widget _entryRow(LedgerEntry entry) {
    final isIncome =
        entry.kind == EntryKind.income || entry.kind == EntryKind.bankCredit;
    final account = data.accounts
        .firstWhere((a) => a.id == entry.accountId)
        .name;
    return InkWell(
      onTap: () => _entryDetails(entry),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: isIncome
                    ? const Color(0xFFEDF2E5)
                    : const Color(0xFFF4EFE8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIncome
                    ? Icons.south_west
                    : entry.shares.isNotEmpty
                    ? Icons.people_outline
                    : entry.kind == EntryKind.transfer
                    ? Icons.swap_horiz
                    : Icons.receipt_long_outlined,
                color: isIncome ? forest : coral,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (entry.metadataPending)
                    const Text(
                      'Details awaiting review',
                      style: TextStyle(color: coral, fontSize: 10),
                    ),
                  Text(
                    '${entry.lines.firstOrNull?.subcategory ?? entry.kind.label} · $account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : ''}${rupees(entry.amountMinor)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isIncome ? forest : ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  DateFormat('d MMM').format(entry.date),
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _entryDetails(LedgerEntry e) async => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(e.description),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rupees(e.amountMinor),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text('${e.kind.label} · ${dateLabel(e.date)} · ${e.source}'),
              const SizedBox(height: 20),
              for (final l in e.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${l.description} · ${rupees(l.amountMinor)}\n${l.category} / ${l.subcategory}',
                    style: const TextStyle(height: 1.6),
                  ),
                ),
              if (e.shares.isNotEmpty) ...[
                Text(
                  'Paid by ${e.payer}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...e.shares.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('${s.person}: ${rupees(s.amountMinor)}'),
                  ),
                ),
              ],
              if (e.counterparty != null) Text('With ${e.counterparty}'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete this transaction?'),
                content: const Text(
                  'Balances will be recalculated. A transaction supporting a recorded repayment cannot be removed.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Keep'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            try {
              await widget.controller.deleteEntry(e.id);
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              if (context.mounted) showError(context, error);
            }
          },
          child: const Text('Delete', style: TextStyle(color: coral)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            showTransactionForm(this.context, widget.controller, existing: e);
          },
          child: const Text('Edit'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Widget _activity() {
    final entries =
        data.entries
            .where(
              (e) =>
                  (_filter == 'All' || e.kind.label == _filter) &&
                  '${e.description} ${e.counterparty ?? ''} ${e.shares.map((s) => s.person).join(' ')} ${e.lines.map((l) => '${l.category} ${l.subcategory}').join(' ')}'
                      .toLowerCase()
                      .contains(_search.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search transactions, categories or people…',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', ...EntryKind.values.map((k) => k.label)]
                .map(
                  (f) => ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Text(
            '${entries.length} transactions',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          if (entries.isEmpty)
            _empty('No transactions match yet.', Icons.search_off_outlined),
          ...entries.map(_entryRow),
        ],
      ),
    );
  }

  Widget _accounts() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: () => showAccountForm(context, widget.controller),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add manual account'),
        ),
      ),
      const SizedBox(height: 20),
      ...data.accounts.map(
        (a) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Panel(
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: canvas,
                  child: Icon(Icons.account_balance_outlined, color: forest),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${a.type} · Manual account · INR',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  rupees(data.balance(a.id)),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (data.accounts.isEmpty)
        _empty(
          'Add a bank account, wallet or cash balance to get started.',
          Icons.account_balance_outlined,
        ),
      const SizedBox(height: 10),
      const Notice(
        'Bank linking is not connected yet. India’s Account Aggregator network requires supported providers, a consent flow and an eligible operating arrangement. Manual accounts work offline.',
      ),
    ],
  );

  Widget _people() {
    final debts = data.debts;
    final receivable = debts.values
        .where((n) => n > 0)
        .fold(0, (a, b) => a + b);
    final payable = -debts.values.where((n) => n < 0).fold(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _responsiveRow([
          _stat('OWED TO YOU', receivable, forest),
          _stat('YOU OWE', payable, coral),
        ]),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => showTransactionForm(
                context,
                widget.controller,
                kind: EntryKind.lent,
              ),
              icon: const Icon(Icons.north_east, size: 18),
              label: const Text('Log money lent'),
            ),
            OutlinedButton.icon(
              onPressed: () => showTransactionForm(
                context,
                widget.controller,
                kind: EntryKind.borrowed,
              ),
              icon: const Icon(Icons.south_west, size: 18),
              label: const Text('Log money borrowed'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (debts.isEmpty)
          _empty(
            'All settled. Shared expenses and loans will appear here.',
            Icons.check_circle_outline,
          ),
        ...debts.entries.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFEDF0E7),
                        child: Text(
                          d.key.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: forest),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              d.value > 0
                                  ? 'owes you ${rupees(d.value)}'
                                  : 'you owe ${rupees(-d.value)}',
                              style: TextStyle(
                                color: d.value > 0 ? forest : coral,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => showTransactionForm(
                          context,
                          widget.controller,
                          kind: d.value > 0
                              ? EntryKind.repaymentReceived
                              : EntryKind.repaymentPaid,
                          person: d.key,
                          amount: d.value.abs(),
                        ),
                        child: const Text('Record repayment'),
                      ),
                      TextButton.icon(
                        onPressed: () => _shareBalance(d.key, d.value),
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text('Share balance'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const Notice(
          'Names are stored locally. Sharing opens your device’s share sheet; you choose the recipient and send. App-to-app invitations and automatic reminders are not connected.',
        ),
      ],
    );
  }

  Future<void> _shareBalance(String person, int amount) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      await PrivacySession.external(
        () => SharePlus.instance.share(
          ShareParams(
            text:
                'Hi $person, my PennyWise record shows ${amount > 0 ? 'you owe me' : 'I owe you'} ${rupees(amount.abs())} as of ${dateLabel(DateTime.now())}. Please let me know if we need to correct anything.',
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _investments() {
    final cost = data.holdings.fold(0, (sum, h) => sum + h.costMinor),
        gain = data.investmentMinor - cost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _responsiveRow([
          _stat('PORTFOLIO VALUE', data.investmentMinor, forest),
          _stat('UNREALISED GAIN / LOSS', gain, gain >= 0 ? forest : coral),
        ]),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => showHoldingForm(context, widget.controller),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add investment'),
          ),
        ),
        const SizedBox(height: 22),
        ...data.holdings.map(
          (h) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          h.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Update valuation',
                        onPressed: () => showHoldingForm(
                          context,
                          widget.controller,
                          holding: h,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                    ],
                  ),
                  Text(
                    '${h.assetClass} · Manual valuation · ${dateLabel(h.valuedAt)}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 26,
                    runSpacing: 12,
                    children: [
                      Text(
                        rupees(h.valueMinor),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${rupees(h.gainMinor)}  (${h.returnPercent?.toStringAsFixed(2) ?? 'N/A'}${h.returnPercent == null ? '' : '%'})',
                        style: TextStyle(
                          fontSize: 14,
                          color: h.gainMinor >= 0 ? forest : coral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Cost: ${rupees(h.costMinor)}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (data.holdings.isEmpty)
          _empty(
            'Add an existing holding to track its value over time.',
            Icons.show_chart,
          ),
        const Notice(
          'Values are manually entered, not live prices. Returns are simple unrealised gains, excluding dividends, fees and tax; they are not annualised. Broker connections and cash-flow-based performance are planned.',
        ),
      ],
    );
  }

  Widget _stat(String title, int amount, Color color) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          rupees(amount),
          style: TextStyle(
            color: color,
            fontSize: 30,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
  Widget _plans() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFFEAF0DF),
          child: Icon(Icons.park_outlined, color: forest, size: 32),
        ),
        const SizedBox(height: 24),
        const Text(
          'The next chapter: a living financial plan.',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Phase two will connect goals with your real cash flow, debts, investments and changing circumstances.',
          style: TextStyle(color: muted, height: 1.7),
        ),
        const SizedBox(height: 24),
        for (final feature in [
          'Emergency funds, major purchases and retirement goals',
          'Scenarios for income changes, inflation, interest and life events',
          'Debt payoff and investment contribution schedules',
          'Transparent assumptions and sensitivity analysis',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 20, color: forest),
                const SizedBox(width: 12),
                Expanded(child: Text(feature)),
              ],
            ),
          ),
        const Notice(
          'Planning is not implemented in this milestone. Investment recommendations will require a separate suitability and regulatory design.',
        ),
      ],
    ),
  );

  Widget _settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy & storage',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _settingRow(
              Icons.phone_android,
              'Storage',
              widget.controller.isDemo
                  ? 'Demo data in memory. Refreshing clears changes.'
                  : 'SQLCipher database on this device; key held in platform secure storage.',
            ),
            _settingRow(
              Icons.cloud_off_outlined,
              'Cloud backup',
              'Not enabled. A lost or reset device can mean lost data. Encrypted recovery is a release requirement.',
            ),
            _settingRow(
              Icons.account_circle_outlined,
              'Online account',
              'Not connected. Device unlock is separate from online sign-in.',
            ),
            _settingRow(
              Icons.link,
              'Bank & broker connections',
              'Not configured. No bank credentials are requested or stored.',
            ),
            _settingRow(
              Icons.currency_rupee,
              'Currency',
              'INR · amounts are stored as integer paise.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onLock,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Lock workspace'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showSmsSettings(context, widget.controller),
              icon: const Icon(Icons.sms_outlined, size: 18),
              label: const Text('Configure bank SMS capture'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await widget.controller.forgetMerchantRules();
                } catch (e) {
                  if (mounted) showError(context, e);
                }
              },
              child: Text(
                'Forget learned categories (${data.merchantRules.length})',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Local data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Remove all accounts, transactions, people balances and investments from this workspace.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline, color: coral, size: 19),
              label: const Text(
                'Delete local data',
                style: TextStyle(color: coral),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _settingRow(IconData icon, String title, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: forest, size: 23),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                detail,
                style: const TextStyle(color: muted, height: 1.6, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all local data?'),
        content: const Text(
          'This removes all records in this workspace. There is no cloud backup and this cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my data'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete everything',
              style: TextStyle(color: coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        if (!widget.controller.isDemo && const BankSmsBridge().supported) {
          const bridge = BankSmsBridge();
          await bridge.configure(enabled: false, senders: []);
          await bridge.clear();
        }
        await widget.controller.clearLocalData();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  Widget _empty(String text, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Column(
      children: [
        Icon(icon, color: muted, size: 38),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.6),
        ),
      ],
    ),
  );
}
