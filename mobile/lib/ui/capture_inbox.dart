import 'package:flutter/material.dart';
import '../application/ledger_controller.dart';
import '../data/bank_sms_bridge.dart';
import '../domain/import_parser.dart';
import '../domain/models.dart';
import 'forms.dart';
import 'privacy.dart';
import 'theme.dart';

class CaptureInbox extends StatefulWidget {
  const CaptureInbox({
    super.key,
    required this.controller,
    required this.onImport,
  });
  final LedgerController controller;
  final VoidCallback onImport;
  @override
  State<CaptureInbox> createState() => _CaptureInboxState();
}

class _CaptureInboxState extends State<CaptureInbox> {
  bool _all = false;
  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final captures = state.captures.where((c) => _all || c.needsReview).toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Notice(
          'Recognised bank movements affect the matched account once. Pending review is for their details. Uncertain document extractions wait here before posting.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Capture a transaction'),
            ),
            OutlinedButton.icon(
              onPressed: () => showSmsSettings(context, widget.controller),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Bank SMS settings'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show handled captures'),
          value: _all,
          onChanged: (v) => setState(() => _all = v),
        ),
        if (captures.isEmpty)
          const Panel(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nothing waiting for review. Import a receipt, statement, or bank message to get started.',
              ),
            ),
          ),
        for (final c in captures)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.merchant ?? c.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        c.amountMinor == null
                            ? 'Amount needed'
                            : rupees(c.amountMinor!),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${c.source.replaceAll('_', ' ')} · ${c.date == null ? 'Date needed' : dateLabel(c.date!)}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.status == CaptureStatus.posted
                        ? 'Movement recorded · details awaiting review'
                        : c.status == CaptureStatus.pending
                        ? 'Draft · account balance unchanged'
                        : c.status.name,
                    style: const TextStyle(
                      color: forest,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (c.accountHint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Account ending ${c.accountHint!}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Suggested: ${c.category} / ${c.subcategory}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (c.questions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        c.questions.join('\n'),
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                  if (c.needsReview) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () => _review(c),
                          child: const Text('Review details'),
                        ),
                        if (c.possibleDuplicateEntryId != null &&
                            c.linkedEntryId == null)
                          OutlinedButton(
                            onPressed: () async {
                              try {
                                await widget.controller.linkCapture(
                                  c.id,
                                  c.possibleDuplicateEntryId!,
                                );
                              } catch (e) {
                                if (context.mounted) showError(context, e);
                              }
                            },
                            child: const Text('Link existing transaction'),
                          ),
                        TextButton(
                          onPressed: () => _dismiss(c),
                          child: Text(
                            c.linkedEntryId == null
                                ? 'Dismiss'
                                : 'Remove captured movement',
                            style: const TextStyle(color: coral),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _review(CapturedTransaction capture) async {
    final existing = widget.controller.state.entries
        .where((e) => e.id == capture.linkedEntryId)
        .firstOrNull;
    final draft = TransactionDraft(
      description: capture.description,
      amountMinor: capture.amountMinor,
      date: capture.date,
      kind: capture.kind ?? EntryKind.expense,
      category: capture.category,
      subcategory: capture.subcategory,
      questions: capture.questions,
      source: capture.source,
      sourceKey: capture.evidenceKey,
    );
    await showTransactionForm(
      context,
      widget.controller,
      draft: draft,
      existing: existing,
      accountId: capture.accountId,
      capture: capture,
    );
  }

  Future<void> _dismiss(CapturedTransaction c) async {
    if (c.linkedEntryId != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove the captured movement?'),
          content: const Text(
            'This reverses its effect on your local account balance. Use this only for an incorrect capture or duplicate, not to postpone categorisation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await widget.controller.dismissCapture(c.id);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}

Future<void> showSmsSettings(
  BuildContext context,
  LedgerController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => SmsSettingsDialog(controller: controller),
);

class SmsSettingsDialog extends StatefulWidget {
  const SmsSettingsDialog({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<SmsSettingsDialog> createState() => _SmsSettingsDialogState();
}

class _SmsSettingsDialogState extends State<SmsSettingsDialog> {
  static const _bridge = BankSmsBridge();
  final _senders = TextEditingController(),
      _lastFour = TextEditingController(),
      _sender = TextEditingController();
  BankSmsStatus _status = const BankSmsStatus();
  String? _account, _message;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _account = widget.controller.state.accounts.firstOrNull?.id;
    _refresh();
  }

  @override
  void dispose() {
    _senders.dispose();
    _lastFour.dispose();
    _sender.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await _bridge.status();
      if (mounted) {
        setState(() {
          _status = status;
          _senders.text = status.senders.join(', ');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not read SMS capture status. No messages were removed.',
        );
      }
    }
  }

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (widget.controller.isDemo) {
        throw const FormatException(
          'Unlock your real local vault to enable bank SMS capture.',
        );
      }
      final senders = _senders.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      if (senders.isEmpty) {
        throw const FormatException(
          'Add exact bank sender IDs, for example HDFCBK or ICICIB.',
        );
      }
      final allowed = await PrivacySession.external(
        () => _bridge.requestPermission(),
      );
      if (!allowed) {
        throw const FormatException(
          'SMS permission was not granted. Manual imports remain available.',
        );
      }
      await _bridge.configure(enabled: true, senders: senders);
      await _refresh();
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = e is FormatException
              ? e.message.toString()
              : 'Unable to enable capture. Check Android app permissions.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _map() async {
    try {
      if (_account == null) {
        throw const FormatException('Create a manual bank account first.');
      }
      await widget.controller.mapBankAccount(
        _account!,
        _lastFour.text.trim(),
        _sender.text.trim(),
      );
      if (mounted) {
        setState(
          () => _message =
              'Bank identifier linked. Set opening balance before the first captured movement to avoid counting existing transactions twice.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = e is FormatException
              ? e.message.toString()
              : 'Could not link this account.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: 'Bank SMS capture',
    saving: _busy,
    onSave: () => Navigator.pop(context),
    saveLabel: 'Done',
    children: [
      const Notice(
        'Optional, on-device capture of new debit/credit SMS from the exact bank senders you allow. Matching messages are stored encrypted and processed when you unlock PennyWise. Personal messages and OTPs are excluded. You can disable capture anytime.',
      ),
      if (!_bridge.supported)
        const Notice(
          'Automatic SMS capture is available on Android. On iPhone and in this browser, import a statement or paste a bank alert instead.',
        ),
      if (_bridge.supported) ...[
        Text(
          'Capture: ${_status.enabled && _status.permissionGranted ? 'Enabled' : 'Disabled'} · Queued: ${_status.pendingCount}',
        ),
        if (_status.overflowCount > 0)
          Notice(
            '${_status.overflowCount} alerts could not be queued. Reconcile your statement.',
            color: coral,
          ),
        if (_status.error != null) Notice(_status.error!, color: coral),
        TextField(
          controller: _senders,
          decoration: const InputDecoration(
            labelText: 'Allowed sender IDs (comma-separated)',
            hintText: 'HDFCBK, ICICIB',
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : _enable,
              child: const Text('Allow SMS & enable capture'),
            ),
            TextButton(
              onPressed: () async {
                await _bridge.configure(
                  enabled: false,
                  senders: _status.senders,
                );
                await _refresh();
              },
              child: const Text('Disable capture'),
            ),
          ],
        ),
      ],
      const Divider(),
      const Text(
        'Match alerts to an account',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      if (widget.controller.state.accounts.isNotEmpty)
        DropdownButtonFormField<String>(
          initialValue: _account,
          decoration: const InputDecoration(labelText: 'Your account'),
          items: widget.controller.state.accounts
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (a) => setState(() => _account = a),
        ),
      TextField(
        controller: _lastFour,
        keyboardType: TextInputType.number,
        maxLength: 4,
        decoration: const InputDecoration(
          labelText: 'Last four account/card digits',
          hintText: '1234',
        ),
      ),
      TextField(
        controller: _sender,
        decoration: const InputDecoration(
          labelText: 'Bank sender for this account',
          hintText: 'HDFCBK',
        ),
      ),
      OutlinedButton(onPressed: _map, child: const Text('Save account match')),
      if (widget.controller.state.accounts.any((a) => a.lastFour != null)) ...[
        const Text(
          'Current account matches',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final a in widget.controller.state.accounts.where(
          (a) => a.lastFour != null,
        ))
          Text('${a.name} · ${a.smsSender ?? ''} · ending ${a.lastFour!}'),
      ],
      if (_message != null) Notice(_message!),
      const Text(
        'Android captures new SMS only, not your message history. Delivery can be delayed or stopped by Android, force-stop, or battery policies. Check your statement for completeness.',
        style: TextStyle(fontSize: 12, color: muted, height: 1.6),
      ),
    ],
  );
}
