import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

import '../../../core/network/request_id.dart';
import '../../receipt_scanning/data/receipt_gallery_picker.dart';
import '../../transaction_draft/data/receipt_parser_client.dart';
import '../../transaction_draft/model/transaction_draft.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../application/group_expense_draft_mapper.dart';
import '../application/itemized_split_calculator.dart';
import '../data/group_providers.dart';
import '../domain/group_expense_draft.dart';
import '../domain/group_models.dart';
import 'fast_split_page.dart';
import 'itemized_split_page.dart';

typedef GroupReceiptLauncher = Future<String?> Function(BuildContext context);
typedef GroupReceiptParser =
    Future<ReceiptParseResult> Function(
      String text, {
      CancelToken? cancelToken,
    });
typedef GroupFastSplitSubmit =
    Future<void> Function(
      GroupExpenseDraft draft,
      FastSplitFormValue value,
      String idempotencyKey,
    );

typedef GroupItemizedSplitSubmit =
    Future<void> Function(
      GroupExpenseDraft draft,
      ItemizedSplitFormValue value,
      String idempotencyKey,
    );

class GroupOcrPage extends ConsumerStatefulWidget {
  const GroupOcrPage({
    super.key,
    required this.group,
    required this.onFastSplitSubmit,
    required this.onItemizedSplitSubmit,
    this.scanReceipt,
    this.pickGalleryReceipt,
    this.parseReceipt,
  });

  final GroupDetail group;
  final GroupFastSplitSubmit onFastSplitSubmit;
  final GroupItemizedSplitSubmit onItemizedSplitSubmit;
  final GroupReceiptLauncher? scanReceipt;
  final GroupReceiptLauncher? pickGalleryReceipt;
  final GroupReceiptParser? parseReceipt;

  @override
  ConsumerState<GroupOcrPage> createState() => _GroupOcrPageState();
}

class _GroupOcrPageState extends ConsumerState<GroupOcrPage> {
  bool _isLoading = false;
  bool _openingSplit = false;
  String? _message;
  ReceiptParseResult? _result;
  String? _rawOcrText;
  String? _submissionKey;
  DateTime? _submissionDate;
  CancelToken? _cancelToken;
  int _flowId = 0;

  @override
  void dispose() {
    _cancelToken?.cancel('Group OCR page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return Scaffold(
      key: const Key('group_ocr_page'),
      appBar: AppBar(title: const Text('Grup Fişi Tara')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              group.name,
              key: const Key('group_ocr_group_name'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Bu fiş ${group.name} grubuyla paylaşılacak.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              _LoadingCard(onCancel: _cancelParsing)
            else if (_result != null)
              _ResultView(
                result: _result!,
                onShare: _openingSplit ? null : _shareWithGroup,
                isOpening: _openingSplit,
              )
            else ...[
              FilledButton.icon(
                key: const Key('group_ocr_camera_button'),
                onPressed: () =>
                    _runOcr(widget.scanReceipt ?? _launchReceiptScanner),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Kamerayla Fiş Çek'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('group_ocr_gallery_button'),
                onPressed: () =>
                    _runOcr(widget.pickGalleryReceipt ?? _pickGalleryReceipt),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeriden Fiş Seç'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 20),
                _MessageCard(message: _message!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runOcr(GroupReceiptLauncher launcher) async {
    if (_isLoading) return;
    final flowId = ++_flowId;
    setState(() {
      _isLoading = true;
      _openingSplit = false;
      _message = null;
      _result = null;
      _rawOcrText = null;
      _submissionKey = null;
      _submissionDate = null;
      _cancelToken = null;
    });

    String? rawText;
    try {
      rawText = await launcher(context);
    } on ReceiptImageValidationException catch (error) {
      if (flowId != _flowId) return;
      _finishWithMessage(error.message);
      return;
    } on Exception catch (error, stackTrace) {
      if (flowId != _flowId) return;
      debugPrint('Grup fişi tarama hatası: $error');
      debugPrintStack(stackTrace: stackTrace);
      _finishWithMessage('Fiş taranamadı. Lütfen tekrar deneyin.');
      return;
    }

    if (!mounted || flowId != _flowId) return;
    if (rawText == null) {
      _finishWithMessage('Fiş tarama işlemi iptal edildi.');
      return;
    }
    if (rawText.trim().isEmpty) {
      _finishWithMessage(
        'Fiş üzerinde okunabilir bir metin bulunamadı. Lütfen tekrar deneyin.',
      );
      return;
    }

    final parser = widget.parseReceipt;
    if (parser == null) {
      _finishWithMessage('OCR servisi şu anda kullanılamıyor.');
      return;
    }

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    try {
      final result = await parser(rawText, cancelToken: cancelToken);
      if (!mounted || flowId != _flowId || cancelToken.isCancelled) return;
      if (!_hasReviewableReceiptData(result.draft)) {
        _finishWithMessage(
          'Fişten doğrulanabilir bilgi çıkarılamadı. Lütfen tekrar deneyin.',
        );
        return;
      }
      final submissionDate = DateTime.now().toUtc();

      setState(() {
        _isLoading = false;
        _result = result;
        _rawOcrText = rawText;
        _submissionDate = submissionDate;
        _submissionKey = newUuidV4();
      });
    } on ReceiptParserException catch (error) {
      if (flowId != _flowId) return;
      if (error.isCancelled || cancelToken.isCancelled) {
        _finishWithMessage('Fiş analizi iptal edildi.');
      } else {
        _finishWithMessage(error.message);
      }
    } on Exception catch (error, stackTrace) {
      if (flowId != _flowId) return;
      debugPrint('Grup fişi OCR hatası: $error');
      debugPrintStack(stackTrace: stackTrace);
      _finishWithMessage('Fiş bilgileri alınamadı. Lütfen tekrar deneyin.');
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  bool _hasReviewableReceiptData(TransactionDraft draft) =>
      draft.institutionName.trim().isNotEmpty ||
      (draft.amountInMinor ?? 0) > 0 ||
      draft.transactionDate != null ||
      draft.receiptItems.any((item) => item.name.trim().isNotEmpty);

  void _cancelParsing() {
    final token = _cancelToken;
    _flowId++;
    token?.cancel('User cancelled group receipt parsing');
    _finishWithMessage('Fiş analizi iptal edildi.');
  }

  void _finishWithMessage(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _message = message;
    });
  }

  Future<String?> _launchReceiptScanner(BuildContext context) async {
    final result = await Navigator.of(context).push<ReceiptScanResult>(
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );
    return result?.rawOcrText;
  }

  Future<String?> _pickGalleryReceipt(BuildContext context) async {
    final selection = await pickReceiptFromGallery();
    return selection?.rawOcrText;
  }

  Future<void> _shareWithGroup() async {
    if (_openingSplit) return;

    final result = _result;
    final submissionKey = _submissionKey;
    final submissionDate = _submissionDate;

    if (result == null || submissionKey == null || submissionDate == null) {
      return;
    }

    final currentUserId = ref.read(currentGroupUserIdProvider)?.trim();
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aktif kullanıcı bilgisi bulunamadı. Lütfen yeniden giriş yapın.',
          ),
        ),
      );
      return;
    }

    setState(() => _openingSplit = true);

    try {
      final parsedDraft = result.draft;
      final source = TransactionDraft(
        institutionName: parsedDraft.institutionName,
        category: parsedDraft.category,
        amountInMinor: parsedDraft.amountInMinor,
        transactionDate: parsedDraft.transactionDate ?? submissionDate,
        rawOcrText:
            _rawOcrText ?? parsedDraft.rawOcrText ?? result.normalizedOcrText,
        receiptItems: parsedDraft.receiptItems,
      );

      final draft = const GroupExpenseDraftMapper().fromTransactionDraft(
        source: source,
        groupId: widget.group.id,
        payerUserId: currentUserId,
        currency: widget.group.currency,
      );

      final meaningfulItems = draft.meaningfulItems;
      final itemizedTotal = draft.resolvedItemizedTotalInMinor;

      MaterialPageRoute<bool> buildFastSplitRoute() {
        final receiptTotal = draft.totalAmountInMinor;

        return MaterialPageRoute<bool>(
          builder: (_) => FastSplitPage(
            group: widget.group,
            currentUserId: currentUserId,
            initialTitle: draft.merchantName,
            initialTotalAmountInMinor: receiptTotal != null && receiptTotal > 0
                ? receiptTotal
                : null,
            popSavedResult: true,
            onSubmit: (value) =>
                widget.onFastSplitSubmit(draft, value, submissionKey),
          ),
        );
      }

      final MaterialPageRoute<bool> initialRoute;

      if (draft.hasMeaningfulItems && itemizedTotal != null) {
        initialRoute = MaterialPageRoute<bool>(
          builder: (splitContext) => ItemizedSplitPage(
            group: widget.group,
            currentUserId: currentUserId,
            initialTitle: draft.merchantName,
            popSavedResult: true,
            receipt: ItemizedSplitReceipt(
              receiptId: null,
              totalAmountInMinor: itemizedTotal,
              lineItems: [
                for (var index = 0; index < meaningfulItems.length; index += 1)
                  ItemizedReceiptLine(
                    receiptLineItemId: null,
                    receiptLineItemPosition: index,
                    name: meaningfulItems[index].name,
                    quantityMilli: meaningfulItems[index].quantityMilli,
                    unitPriceInMinor: meaningfulItems[index].unitPriceInMinor,
                    totalAmountInMinor:
                        meaningfulItems[index].totalAmountInMinor,
                  ),
              ],
            ),
            onUseFastSplit: () => Navigator.of(splitContext).pop<bool>(false),
            onSubmit: (value) =>
                widget.onItemizedSplitSubmit(draft, value, submissionKey),
          ),
        );
      } else {
        initialRoute = buildFastSplitRoute();
      }

      var saved = await Navigator.of(context).push<bool>(initialRoute);

      if (!mounted) return;

      if (saved == false) {
        saved = await Navigator.of(context).push<bool>(buildFastSplitRoute());

        if (!mounted) return;
      }

      if (saved == true) {
        Navigator.of(context).pop<bool>(true);
      }
    } finally {
      if (mounted) {
        setState(() => _openingSplit = false);
      }
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('group_ocr_loading'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              'Fiş bilgileri okunuyor…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Kurum, tarih, toplam ve ürünler doğrulanıyor.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const Key('group_ocr_cancel_button'),
              onPressed: onCancel,
              child: const Text('İptal Et'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onShare,
    required this.isOpening,
  });

  final ReceiptParseResult result;
  final VoidCallback? onShare;
  final bool isOpening;

  @override
  Widget build(BuildContext context) {
    final draft = result.draft;
    final date = draft.transactionDate;
    final amount = draft.amountInMinor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          key: const Key('group_ocr_result'),
          child: Column(
            children: [
              _ResultRow(
                icon: Icons.storefront_outlined,
                label: 'Kurum',
                value: draft.institutionName.trim().isEmpty
                    ? 'Bulunamadı'
                    : draft.institutionName.trim(),
              ),
              const Divider(),
              _ResultRow(
                icon: Icons.calendar_today_outlined,
                label: 'Tarih',
                value: date == null
                    ? 'Bulunamadı'
                    : DateFormat('dd.MM.yyyy').format(date),
              ),
              const Divider(),
              _ResultRow(
                icon: Icons.payments_outlined,
                label: 'Toplam',
                value: amount == null
                    ? 'Bulunamadı'
                    : '₺${formatMinorAsTurkishLira(amount)}',
              ),
              const Divider(),
              _ResultRow(
                icon: Icons.shopping_basket_outlined,
                label: 'Ürün sayısı',
                value: '${draft.receiptItems.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('share_with_group_button'),
          onPressed: onShare,
          icon: isOpening
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.group_outlined),
          label: Text(isOpening ? 'Açılıyor' : 'Grupla Paylaş'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('group_ocr_message'),
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
