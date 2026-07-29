import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

import '../../features/transaction_draft/data/receipt_parser_client.dart';
import '../../features/transaction_draft/presentation/transaction_draft_page.dart';

typedef ReceiptScanLauncher = Future<String?> Function(BuildContext context);
typedef ReceiptParseHandler = Future<ReceiptParseResult> Function(String text);

const _receiptApiBaseUrl = String.fromEnvironment(
  'RECEIPT_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({
    super.key,
    this.scanReceipt,
    this.parseReceipt,
    this.saveTransaction,
    this.openScannerOnStart = false,
  });

  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler? parseReceipt;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final bool openScannerOnStart;

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  bool _initialScannerOpened = false;

  @override
  void initState() {
    super.initState();
    if (widget.openScannerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _initialScannerOpened) return;
        _initialScannerOpened = true;
        unawaited(_openReceiptScanner(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gider Ekle')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Ne kadar harcadın?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '₺ ',
                  hintText: '0,00',
                  labelText: 'Tutar',
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 74,
              height: 74,
              child: FilledButton(
                key: const Key('ocr_camera_button'),
                onPressed: () => _openReceiptScanner(context),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 34),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            SizedBox(width: 6),
            Expanded(
              child: Text('Fişini tara, tutar ve kategori otomatik dolsun.'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const Key('manual_entry_button'),
          onPressed: () => _openManualEntry(context),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Fişim yok, elle gireceğim'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 30),
        Text('Abonelikler', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const _Subscription(
          Icons.play_circle_outline,
          'Netflix',
          '12 Temmuz',
          '-₺300',
        ),
        const SizedBox(height: 12),
        const _Subscription(
          Icons.home_outlined,
          'Kira',
          '4 Temmuz',
          '-₺14.000',
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(20),
      child: FilledButton(
        onPressed: () {},
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
        child: const Text('Gideri Kaydet'),
      ),
    ),
  );

  Future<void> _openReceiptScanner(BuildContext context) async {
    final rawText = await (widget.scanReceipt ?? _launchReceiptScanner)(
      context,
    );
    if (!context.mounted || rawText == null || rawText.trim().isEmpty) return;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final result = await (widget.parseReceipt ?? _parseReceipt)(rawText);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final confirmedDraft = await Navigator.of(context).push<TransactionDraft>(
        MaterialPageRoute(
          builder: (_) => TransactionDraftPage(
            initialDraft: result.draft,
            normalizedOcrText: result.normalizedOcrText,
            confidenceScore: result.confidenceScore,
            isParseSuccessful: result.isParseSuccessful,
          ),
        ),
      );
      if (!context.mounted) return;
      await _saveDraft(
        context,
        confirmedDraft,
        source: TransactionSource.ocrLlm,
      );
    } on Exception catch (error, stackTrace) {
      debugPrint('Fiş ayrıştırma hatası: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Fiş bilgileri alınamadı: $error')),
        );
    }
  }

  Future<String?> _launchReceiptScanner(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );
  }

  Future<void> _openManualEntry(BuildContext context) async {
    final confirmedDraft = await Navigator.of(context).push<TransactionDraft>(
      MaterialPageRoute(
        builder: (_) =>
            const TransactionDraftPage(mode: TransactionDraftPageMode.manual),
      ),
    );
    if (!context.mounted) return;
    await _saveDraft(context, confirmedDraft, source: TransactionSource.manual);
  }

  Future<void> _saveDraft(
    BuildContext context,
    TransactionDraft? draft, {
    required TransactionSource source,
  }) async {
    final save = widget.saveTransaction;
    if (draft == null || save == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await save(
        draft.toTransactionEntity(
          source: source,
          transactionType: TransactionType.expense,
        ),
      );
      if (!context.mounted) return;

      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Gider başarıyla kaydedildi.')),
        );
    } on Exception catch (error) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gider kaydedilemedi: $error')));
    }
  }

  Future<ReceiptParseResult> _parseReceipt(String rawText) async {
    final client = ReceiptParserClient(baseUrl: _receiptApiBaseUrl);
    try {
      return await client.parse(rawText);
    } finally {
      client.close();
    }
  }
}

class _Subscription extends StatelessWidget {
  const _Subscription(this.icon, this.title, this.date, this.amount);

  final IconData icon;
  final String title;
  final String date;
  final String amount;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.lavender,
          child: Icon(icon, color: AppColors.blue),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(date),
            ],
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: AppColors.expense,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
