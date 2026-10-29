import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/finance_analytics.dart';
import '../domain/models.dart';
import 'theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.state});
  final LedgerState state;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  void _changeMonth(int step) => setState(() {
    _month = DateTime(_month.year, _month.month + step);
  });
  @override
  Widget build(BuildContext context) {
    final a = FinanceAnalytics(widget.state, month: _month);
    final today = DateTime.now(),
        currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous analytics month',
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(_month),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next analytics month',
              onPressed: _month.isBefore(currentMonth)
                  ? () => _changeMonth(1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          a.isPartialMonth
              ? 'Month to date · 1–${today.day} ${DateFormat('MMM').format(_month)}'
              : 'Full calendar month · ${a.reviewedCount} reviewed transactions',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 22),
        _responsive([
          _metric('CONFIRMED INCOME', a.incomeMinor, forest),
          _metric('YOUR CONFIRMED SPENDING', a.spendingMinor, coral),
          _metric(
            'INCOME LESS SPENDING',
            a.netCashflowMinor,
            a.netCashflowMinor >= 0 ? forest : coral,
          ),
        ]),
        const SizedBox(height: 18),
        if (a.pendingCount > 0) ...[
          Notice(
            '${a.pendingCount} captured ${a.pendingCount == 1 ? 'transaction is' : 'transactions are'} awaiting metadata review (${rupees(a.pendingAmountMinor)} in total movement). Account balances reflect posted captures. These records are excluded from confirmed categories, income and spending until reviewed.',
            icon: Icons.pending_actions_outlined,
            color: coral,
          ),
          const SizedBox(height: 18),
        ],
        _comparison(a),
        const SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Six months at a glance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _Legend(color: forest, label: 'Confirmed income'),
                  _Legend(color: coral, label: 'Personal spending'),
                ],
              ),
              const SizedBox(height: 24),
              _timeline(a.timeline),
              const SizedBox(height: 14),
              const Text(
                '* Current month is partial. Earlier months show their full calendar periods.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _responsive([
          _breakdown(
            'Where your money went',
            'Categories · your share of shared bills',
            a.categoryTotals,
            a.spendingMinor,
          ),
          _breakdown(
            'A closer look',
            'Subcategories · proportional item allocation',
            a.subcategoryTotals,
            a.spendingMinor,
          ),
        ], breakpoint: 850),
        const SizedBox(height: 22),
        _breakdown(
          'By merchant',
          'Reviewed merchant names; unspecified names stay visible',
          a.merchantTotals,
          a.spendingMinor,
        ),
        const SizedBox(height: 18),
        const Notice(
          'Transfers, loan principal, repayments and investment valuations are excluded from income and spending. The difference above is personal income less spending, not total bank cash flow. These are descriptive summaries of your records.',
        ),
      ],
    );
  }

  Widget _responsive(List<Widget> children, {double breakpoint = 780}) =>
      LayoutBuilder(
        builder: (context, c) => c.maxWidth < breakpoint
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    children[i],
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 18),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
      );

  Widget _metric(String label, int amount, Color color) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: muted, letterSpacing: 1, fontSize: 10),
        ),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            rupees(amount),
            style: TextStyle(
              color: color,
              fontSize: 29,
              fontWeight: FontWeight.w600,
              letterSpacing: -.6,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _comparison(FinanceAnalytics a) {
    final percent = a.spendingChangePercent;
    final comparison = a.isPartialMonth
        ? 'Compared with 1–${a.comparisonLastDay.day} ${DateFormat('MMM').format(a.comparisonMonth)}'
        : 'Compared with all of ${DateFormat('MMMM').format(a.comparisonMonth)}';
    final message = percent == null
        ? a.spendingMinor == 0
              ? 'No confirmed spending in either period.'
              : 'No spending baseline in the comparison period.'
        : percent == 0
        ? 'Spending is unchanged.'
        : 'Spending is ${percent.abs().toStringAsFixed(1)}% ${percent > 0 ? 'higher' : 'lower'}.';
    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.compare_arrows_rounded, color: forest),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                Text(
                  '$comparison · ${rupees(a.previousSpendingMinor)}',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(List<MonthlyFinanceTotal> months) {
    final maximum = months.fold<int>(
      1,
      (v, m) => math.max(v, math.max(m.incomeMinor, m.spendingMinor)),
    );
    return SizedBox(
      height: 174,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: months.map((m) {
          final label =
              '${DateFormat('MMM yyyy').format(m.month)}${m.partial ? ' (month to date)' : ''}: income ${rupees(m.incomeMinor)}, spending ${rupees(m.spendingMinor)}, ${m.pendingCount} awaiting review';
          return Expanded(
            child: Semantics(
              label: label,
              child: Tooltip(
                message: label,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(m.incomeMinor, maximum, forest),
                          const SizedBox(width: 4),
                          _bar(m.spendingMinor, maximum, coral),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${DateFormat('MMM').format(m.month)}${m.partial ? '*' : ''}',
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bar(int amount, int maximum, Color color) => Expanded(
    child: Container(
      height: amount == 0 ? 2 : math.max(4.0, amount * 125 / maximum),
      decoration: BoxDecoration(
        color: amount == 0 ? line : color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      ),
    ),
  );

  Widget _breakdown(
    String title,
    String subtitle,
    Map<String, int> totals,
    int grandTotal,
  ) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 22),
        if (totals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No confirmed spending for this period. Review captured transactions to include them here.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.6),
            ),
          ),
        for (final total in totals.entries) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(total.key, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Text(
                rupees(total.value),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: grandTotal <= 0
                  ? 0
                  : (total.value / grandTotal).clamp(0, 1),
              backgroundColor: canvas,
              color: forest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${grandTotal <= 0 ? '0' : (total.value * 100 / grandTotal).toStringAsFixed(1)}% of personal spending',
            style: const TextStyle(color: muted, fontSize: 10),
          ),
          const SizedBox(height: 22),
        ],
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(color: muted, fontSize: 11)),
    ],
  );
}
