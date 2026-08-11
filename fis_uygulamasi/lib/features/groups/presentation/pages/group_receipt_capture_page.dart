import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

import '../../../../src/screens/expense_screen.dart';
import '../../../transaction_draft/data/receipt_parser_client.dart';
import '../../data/group_repository.dart';
import '../../domain/prepared_group_receipt.dart';

class GroupReceiptCapturePage extends ConsumerStatefulWidget {
  const GroupReceiptCapturePage({
    required this.groupId,
    required this.parseReceipt,
    this.scanReceipt,
    super.key,
  });

  final String groupId;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler parseReceipt;

  @override
  ConsumerState<GroupReceiptCapturePage> createState() =>
      _GroupReceiptCapturePageState();
}

class _GroupReceiptCapturePageState
    extends ConsumerState<GroupReceiptCapturePage> {
  bool _loading = false;

  Future<void> _scan() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final rawText = await (widget.scanReceipt ?? _launchScanner)(context);
      if (!mounted) return;
      if (rawText == null || rawText.trim().isEmpty) {
        context.pop();
        return;
      }
      final result = await widget.parseReceipt(rawText);
      if (!mounted) return;
      PreparedGroupReceipt preparedReceipt;
      try {
        preparedReceipt = await ref
            .read(groupRepositoryProvider)
            .prepareReceiptForSharing(result.draft);
      } on Exception {
        preparedReceipt = PreparedGroupReceipt(draft: result.draft);
      }
      if (!mounted) return;
      context.push(
        '/groups/${widget.groupId}/receipt/review',
        extra: preparedReceipt,
      );
    } on ReceiptParserException catch (error) {
      if (!mounted || error.isCancelled) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fiş bilgileri alınamadı. Tekrar deneyin.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _launchScanner(BuildContext context) async {
    final result = await Navigator.of(context).push<ReceiptScanResult>(
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );
    return result?.rawOcrText;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('group_receipt_capture_page'),
    appBar: AppBar(title: const Text('Grup Masrafı Ekle')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.document_scanner_outlined, size: 72),
            const SizedBox(height: 20),
            Text(
              'Grup için fiş tara',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu akışta fiş yalnızca grupla paylaşılır. Kişisel giderlerin değişmez.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('start_group_receipt_scan_button'),
                onPressed: _loading ? null : _scan,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(_loading ? 'Fiş analiz ediliyor' : 'Fiş Tara'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
