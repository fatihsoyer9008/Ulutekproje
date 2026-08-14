import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

import '../../receipt_scanning/data/receipt_gallery_picker.dart';
import '../../transaction_draft/data/receipt_parser_client.dart';
import '../../transaction_draft/model/transaction_draft.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../data/group_api_failure.dart';
import '../data/group_providers.dart';

typedef GroupReceiptLauncher = Future<String?> Function(BuildContext context);
typedef GroupReceiptParser =
    Future<ReceiptParseResult> Function(
      String text, {
      CancelToken? cancelToken,
    });

class GroupOcrPage extends ConsumerStatefulWidget {
  const GroupOcrPage({
    super.key,
    required this.groupId,
    this.scanReceipt,
    this.pickGalleryReceipt,
    this.parseReceipt,
  });

  final String groupId;
  final GroupReceiptLauncher? scanReceipt;
  final GroupReceiptLauncher? pickGalleryReceipt;
  final GroupReceiptParser? parseReceipt;

  @override
  ConsumerState<GroupOcrPage> createState() => _GroupOcrPageState();
}

class _GroupOcrPageState extends ConsumerState<GroupOcrPage> {
  bool _isLoading = false;
  String? _message;
  ReceiptParseResult? _result;
  CancelToken? _cancelToken;
  int _flowId = 0;

  @override
  void dispose() {
    _cancelToken?.cancel('Group OCR page disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));

    return Scaffold(
      key: const Key('group_ocr_page'),
      appBar: AppBar(title: const Text('Grup Fişi Tara')),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _GroupLoadError(
          message: groupUserMessage(
            error,
            fallbackMessage: 'Grup bilgileri yüklenemedi. Tekrar deneyin.',
          ),
          onRetry: () => ref.invalidate(groupDetailProvider(widget.groupId)),
        ),
        data: (group) => SafeArea(
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
                _ResultView(result: _result!, onShare: _shareWithGroup)
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
      ),
    );
  }

  Future<void> _runOcr(GroupReceiptLauncher launcher) async {
    if (_isLoading) return;
    final flowId = ++_flowId;
    setState(() {
      _isLoading = true;
      _message = null;
      _result = null;
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
      setState(() {
        _isLoading = false;
        _result = result;
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

  void _shareWithGroup() {
    Navigator.of(context).pop(_result);
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
  const _ResultView({required this.result, required this.onShare});

  final ReceiptParseResult result;
  final VoidCallback onShare;

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
          icon: const Icon(Icons.group_outlined),
          label: const Text('Grupla Paylaş'),
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

class _GroupLoadError extends StatelessWidget {
  const _GroupLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 12),
            Text(message, key: const Key('group_ocr_error_message')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('group_ocr_group_retry_button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
