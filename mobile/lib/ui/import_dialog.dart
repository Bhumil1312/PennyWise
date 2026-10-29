import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../application/ledger_controller.dart';
import '../data/document_text_service.dart';
import '../domain/capture_parser.dart';
import '../domain/import_parser.dart';
import 'forms.dart';
import 'privacy.dart';
import 'theme.dart';

Future<void> showImportDialog(
  BuildContext context,
  LedgerController controller,
) => showDialog<void>(
  context: context,
  builder: (_) => ImportDialog(controller: controller),
);

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _text = TextEditingController(),
      _sender = TextEditingController(),
      _password = TextEditingController();
  String _mode = 'Receipt';
  String? _account, _error, _progress;
  bool _busy = false;
  List<ParsedCapture> _parsed = [];
  @override
  void initState() {
    super.initState();
    _account = widget.controller.state.accounts.firstOrNull?.id;
  }

  @override
  void dispose() {
    _text.dispose();
    _sender.dispose();
    _password.dispose();
    super.dispose();
  }

  List<ParsedCapture> _parse() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      throw const FormatException('Choose a file or paste its text first.');
    }
    if (text.length > 1000000) {
      throw const FormatException(
        'Use a smaller statement or split it into sections.',
      );
    }
    switch (_mode) {
      case 'Receipt':
        return [parseReceiptText(text)];
      case 'Statement':
        return parseStatementText(text);
      case 'Bank SMS':
        final capture = parseBankSms(
          text,
          sender: _sender.text.trim(),
          receivedAt: DateTime.now(),
        );
        if (capture == null) {
          throw const FormatException(
            'No completed bank transaction was recognised. OTPs, offers and pending or failed payments are ignored.',
          );
        }
        return [capture];
      default:
        final draft = parseDescription(text);
        final suggested = inferCategory(text, kind: draft.kind);
        return [
          ParsedCapture(
            source: 'description',
            description: draft.description,
            amountMinor: draft.amountMinor,
            occurredAt: draft.date,
            kind: draft.kind,
            suggestedCategory: suggested.category,
            suggestedSubcategory: suggested.subcategory,
            questions: draft.questions,
            confidence: suggested.confidence,
            evidenceKey: sha256
                .convert(
                  utf8.encode(
                    '$text|${dateInput(draft.date ?? DateTime.now())}',
                  ),
                )
                .toString(),
          ),
        ];
    }
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 'Reading document…';
    });
    try {
      final result = await PrivacySession.external(
        () => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'csv', 'txt'],
          withData: true,
        ),
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 15 * 1024 * 1024) {
        throw const FormatException('Choose a document smaller than 15 MB.');
      }
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('This file could not be read.');
      }
      final extension = file.extension?.toLowerCase();
      const documents = DocumentTextService();
      if (extension == 'csv') {
        if (_account == null) {
          throw const FormatException(
            'Create or choose an account before importing CSV.',
          );
        }
        final csv = utf8.decode(bytes);
        final drafts = parseStatementCsv(csv, accountId: _account!);
        final rows = readCsv(csv.replaceFirst('\uFEFF', ''));
        final headers = rows.first.map((h) => h.trim().toLowerCase()).toList();
        final referenceIndex = headers.indexOf('reference');
        _parsed = List.generate(drafts.length, (i) {
          final d = drafts[i];
          return ParsedCapture(
            source: 'csv',
            description: d.description,
            amountMinor: d.amountMinor,
            occurredAt: d.date,
            kind: d.kind,
            evidenceKey: d.sourceKey!,
            reference:
                referenceIndex < 0 || rows[i + 1][referenceIndex].trim().isEmpty
                ? null
                : rows[i + 1][referenceIndex].trim(),
            merchant: d.description,
            suggestedCategory: d.category,
            suggestedSubcategory: d.subcategory,
            confidence: .8,
          );
        });
        _text.text = csv;
        _mode = 'Statement';
      } else {
        if (extension == 'pdf') {
          _text.text = await documents.readPdf(
            bytes,
            password: _password.text.isEmpty ? null : _password.text,
            onProgress: (page, total) {
              if (mounted) {
                setState(() => _progress = 'Reading page $page of $total…');
              }
            },
          );
        } else if (extension == 'txt') {
          _text.text = utf8.decode(bytes);
        } else {
          _mode = 'Receipt';
          _text.text = await documents.readReceipt(bytes);
        }
        if (!mounted) return;
        _parsed = _parse();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message.toString()
              : 'Could not read this document. Check its password, try a clearer image, or paste its text.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _queue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final parsed = _parsed.isEmpty ? _parse() : _parsed;
      if (parsed.isEmpty) {
        throw const FormatException(
          'No transaction rows found. Use dated rows with debit/credit columns or paste one transaction at a time.',
        );
      }
      final count = await widget.controller.stageCaptures(
        parsed,
        accountId: _account,
        sender: _mode == 'Bank SMS' ? _sender.text.trim() : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? 'These captures are already in your inbox.'
                  : '$count capture(s) saved. Open Review inbox to complete details.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message.toString()
              : 'Capture could not be saved. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
    title: 'Capture a transaction',
    onSave: _queue,
    saving: _busy,
    saveLabel: 'Save to review inbox',
    children: [
      const Notice(
        'Receipt OCR recognises text on your device. Suggested fields and categories are editable; uncertain details stay in the review inbox. No document is sent to a cloud AI service.',
      ),
      DropdownButtonFormField<String>(
        initialValue: _mode,
        key: ValueKey(_mode),
        decoration: const InputDecoration(labelText: 'Document or text type'),
        items: [
          'Receipt',
          'Statement',
          'Bank SMS',
          'Description',
        ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: _busy
            ? null
            : (m) => setState(() {
                _mode = m!;
                _parsed = [];
              }),
      ),
      if (widget.controller.state.accounts.isNotEmpty)
        DropdownButtonFormField<String>(
          initialValue: _account,
          decoration: const InputDecoration(
            labelText: 'Account for this document',
          ),
          items: widget.controller.state.accounts
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: _busy
              ? null
              : (a) => setState(() {
                  _account = a;
                  _parsed = [];
                }),
        )
      else
        OutlinedButton(
          onPressed: () async {
            await showAccountForm(context, widget.controller);
            if (mounted) {
              setState(
                () =>
                    _account = widget.controller.state.accounts.firstOrNull?.id,
              );
            }
          },
          child: const Text('Create a manual account'),
        ),
      if (_mode == 'Bank SMS')
        TextField(
          controller: _sender,
          decoration: const InputDecoration(
            labelText: 'Bank sender',
            hintText: 'VM-HDFCBK',
          ),
        ),
      TextField(
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'PDF password (only if required)',
          helperText: 'Used for this import only; never saved.',
        ),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _pick,
        icon: const Icon(Icons.upload_file),
        label: const Text('Choose receipt, PDF, CSV or text'),
      ),
      if (_progress != null)
        Text(_progress!, style: const TextStyle(color: muted)),
      TextField(
        controller: _text,
        minLines: 4,
        maxLines: 8,
        onChanged: (_) => setState(() => _parsed = []),
        decoration: const InputDecoration(
          labelText: 'Extracted text or your description',
          hintText:
              'Paste a receipt, statement rows, bank alert, or describe what happened',
        ),
      ),
      if (_parsed.isNotEmpty) ...[
        Text(
          '${_parsed.length} extracted transaction(s)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final p in _parsed.take(50))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              p.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${p.occurredAt == null ? 'Date needs review' : dateLabel(p.occurredAt!)} · ${p.suggestedCategory}',
            ),
            trailing: Text(
              p.amountMinor == null ? 'Amount needed' : rupees(p.amountMinor!),
            ),
          ),
        if (_parsed.length > 50)
          Text('Plus ${_parsed.length - 50} more rows in the inbox.'),
      ],
      const Text(
        'Images and scanned PDFs: Android/iOS. PDFs with embedded text: all platforms. Statements need recognisable dated rows; unusual bank layouts may need a CSV export.',
        style: TextStyle(fontSize: 12, color: muted, height: 1.6),
      ),
      if (_error != null) Notice(_error!, color: coral),
    ],
  );
}
