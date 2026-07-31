import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

import '../../features/transaction_draft/data/receipt_parser_client.dart';
import '../../features/transaction_draft/presentation/receipt_analysis_page.dart';
import '../../features/transaction_draft/presentation/transaction_draft_page.dart';
import '../../core/database/database_providers.dart';

typedef ReceiptScanLauncher = Future<String?> Function(BuildContext context);
typedef ReceiptParseHandler =
    Future<ReceiptParseResult> Function(
      String text, {
      CancelToken? cancelToken,
    });

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
  bool _isFlowActive = false;
  bool _isSaving = false;

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
    key: const Key('expense_screen'),
    appBar: AppBar(title: const Text('Gider Ekle')),
    body: ListView(
      key: const Key('expense_screen_content'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text(
          'Giderini nasıl eklemek istersin?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Fişini taratarak bilgileri otomatik doldurabilir veya giderini '
          'elle girebilirsin.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('ocr_camera_button'),
          onPressed: _isFlowActive ? null : () => _openReceiptScanner(context),
          icon: const Icon(Icons.document_scanner_rounded),
          label: const Text('Fişi Tara'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('manual_entry_button'),
          onPressed: _isFlowActive ? null : () => _openManualEntry(context),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Fişim yok, elle gireceğim'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        const SizedBox(height: 32),
        Text('Abonelikler', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const AppCard(
          key: Key('subscriptions_empty_state'),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.lavender,
                  child: Icon(
                    Icons.event_repeat_outlined,
                    color: AppColors.blue,
                    size: 28,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Henüz kayıtlı aboneliğiniz yok',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Abonelikleriniz eklendiğinde burada görüntülenecek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _openReceiptScanner(
    BuildContext context, {
    String? retryOcrText,
  }) async {
    if (_isFlowActive) return;
    setState(() => _isFlowActive = true);

    String? rawText;
    try {
      rawText =
          retryOcrText ??
          await (widget.scanReceipt ?? _launchReceiptScanner)(context);
    } on Exception catch (error, stackTrace) {
      debugPrint('Fiş tarama hatası: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!context.mounted) return;
      _setFlowActive(false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Fiş tarayıcı açılamadı.')),
        );
      return;
    }

    if (!context.mounted) return;
    if (rawText == null || rawText.trim().isEmpty) {
      _setFlowActive(false);
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final cancelToken = CancelToken();
    final analysisRoute = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ReceiptAnalysisPage(
        onCancel: () => cancelToken.cancel('User cancelled receipt parsing'),
      ),
    );
    unawaited(rootNavigator.push<void>(analysisRoute));

    ReceiptParseResult? result;
    ReceiptParserException? parseFailure;
    Object? unexpectedError;
    StackTrace? unexpectedStackTrace;

    try {
      result = await (widget.parseReceipt ?? _parseReceipt)(
        rawText,
        cancelToken: cancelToken,
      );
    } on ReceiptParserException catch (error) {
      parseFailure = error;
    } on Exception catch (error, stackTrace) {
      unexpectedError = error;
      unexpectedStackTrace = stackTrace;
    }

    if (!context.mounted) return;
    _removeRouteIfMounted(rootNavigator, analysisRoute);
    _setFlowActive(false);

    if (parseFailure != null) {
      if (parseFailure.isCancelled) return;
      await _showParseFailure(context, parseFailure, rawText);
      return;
    }
    if (unexpectedError != null) {
      debugPrint('Fiş ayrıştırma hatası: $unexpectedError');
      debugPrintStack(stackTrace: unexpectedStackTrace);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Fiş bilgileri alınamadı.')),
        );
      return;
    }

    final categories = await _loadCategories(context);
    if (!context.mounted) return;
    final confirmedDraft = await Navigator.of(context).push<TransactionDraft>(
      MaterialPageRoute(
        builder: (_) => TransactionDraftPage(
          initialDraft: result!.draft,
          normalizedOcrText: result.normalizedOcrText,
          confidenceScore: result.confidenceScore,
          isParseSuccessful: result.isParseSuccessful,
          categories: categories,
        ),
      ),
    );
    if (!context.mounted) return;
    await _saveDraft(context, confirmedDraft, source: TransactionSource.ocrLlm);
  }

  void _setFlowActive(bool value) {
    if (!mounted || _isFlowActive == value) return;
    setState(() => _isFlowActive = value);
  }

  Future<void> _showParseFailure(
    BuildContext context,
    ReceiptParserException error,
    String rawText,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('receipt_parse_error_dialog'),
        title: const Text('Fiş bilgileri alınamadı'),
        content: Text(error.message),
        actions: [
          TextButton(
            key: const Key('return_to_camera_after_parse_error_button'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openReceiptScanner(context);
            },
            child: const Text('Kameraya Dön'),
          ),
          TextButton(
            key: const Key('manual_entry_after_parse_error_button'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openManualEntry(context);
            },
            child: const Text('Elle Girmeye Devam Et'),
          ),
          FilledButton(
            key: const Key('retry_parse_button'),
            onPressed: error.canRetry
                ? () {
                    Navigator.of(dialogContext).pop();
                    _openReceiptScanner(context, retryOcrText: rawText);
                  }
                : null,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  void _removeRouteIfMounted(NavigatorState navigator, Route<void>? route) {
    if (route?.navigator != null) navigator.removeRoute(route!);
  }

  Future<String?> _launchReceiptScanner(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );
  }

  Future<void> _openManualEntry(BuildContext context) async {
    if (_isFlowActive) return;
    setState(() => _isFlowActive = true);
    try {
      final categories = await _loadCategories(context);
      if (!context.mounted) return;
      final confirmedDraft = await Navigator.of(context).push<TransactionDraft>(
        MaterialPageRoute(
          builder: (_) => TransactionDraftPage(
            mode: TransactionDraftPageMode.manual,
            categories: categories,
          ),
        ),
      );
      if (!context.mounted) return;
      await _saveDraft(
        context,
        confirmedDraft,
        source: TransactionSource.manual,
      );
    } finally {
      if (mounted) setState(() => _isFlowActive = false);
    }
  }

  Future<List<CategoryEntity>> _loadCategories(BuildContext context) async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      return await container.read(categoriesProvider.future);
    } on StateError {
      return createDefaultCategoryEntities();
    }
  }

  Future<void> _saveDraft(
    BuildContext context,
    TransactionDraft? draft, {
    required TransactionSource source,
  }) async {
    if (draft == null || _isSaving) return;

    final messenger = ScaffoldMessenger.of(context);
    if (draft.amountInMinor == null || draft.amountInMinor! <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tutar sıfırdan büyük olmalıdır.')),
      );
      return;
    }

    final save = widget.saveTransaction;
    if (save == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Kayıt servisi kullanılamıyor.')),
      );
      return;
    }

    _isSaving = true;
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
    } finally {
      _isSaving = false;
    }
  }

  Future<ReceiptParseResult> _parseReceipt(
    String rawText, {
    CancelToken? cancelToken,
  }) async {
    throw const ReceiptParserException(
      'Fiş ayrıştırma istemcisi uygulama kabuğuna bağlanmamış.',
    );
  }
}
