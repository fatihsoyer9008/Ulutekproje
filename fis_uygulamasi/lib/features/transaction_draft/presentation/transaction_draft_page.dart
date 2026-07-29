import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

import '../model/transaction_draft.dart';
import '../model/turkish_money.dart';

enum TransactionDraftPageMode { manual, ocrReview }

class TransactionDraftPage extends StatefulWidget {
  const TransactionDraftPage({
    super.key,
    this.initialDraft = const TransactionDraft.empty(),
    this.normalizedOcrText,
    this.confidenceScore,
    this.isParseSuccessful = true,
    this.mode = TransactionDraftPageMode.ocrReview,
  }) : assert(
         confidenceScore == null ||
             (confidenceScore >= 0 && confidenceScore <= 1),
       );

  final TransactionDraft initialDraft;
  final String? normalizedOcrText;
  final double? confidenceScore;
  final bool isParseSuccessful;
  final TransactionDraftPageMode mode;

  @override
  State<TransactionDraftPage> createState() => _TransactionDraftPageState();
}

class _TransactionDraftPageState extends State<TransactionDraftPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _institutionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _institutionController = TextEditingController(
      text: widget.initialDraft.institutionName,
    );
    _categoryController = TextEditingController(
      text: widget.initialDraft.category,
    );
    final initialAmount = widget.initialDraft.amountInMinor;
    _amountController = TextEditingController(
      text: initialAmount == null
          ? ''
          : formatMinorAsTurkishLira(initialAmount),
    );
  }

  @override
  void dispose() {
    _institutionController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _confirmDraft() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      TransactionDraft(
        institutionName: _institutionController.text.trim(),
        category: _categoryController.text.trim(),
        amountInMinor: parseTurkishLiraToMinor(_amountController.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.mode == TransactionDraftPageMode.manual
            ? 'Manuel Gider Ekle'
            : 'İşlemi Kontrol Et',
      ),
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DraftHeader(mode: widget.mode),
            const SizedBox(height: 20),
            if (widget.mode == TransactionDraftPageMode.ocrReview &&
                widget.confidenceScore != null) ...[
              ReceiptLowConfidenceWarning(
                confidenceScore: widget.confidenceScore!,
                isParseSuccessful: widget.isParseSuccessful,
              ),
              if (!widget.isParseSuccessful ||
                  widget.confidenceScore! <
                      ReceiptLowConfidenceWarning.defaultThreshold)
                const SizedBox(height: 16),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İşlem bilgileri',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Alanları kontrol edin, gerekirse düzenleyin.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('institution_name_field'),
                    controller: _institutionController,
                    decoration: const InputDecoration(
                      labelText: 'Kurum Adı',
                      hintText: 'Örneğin: Migros',
                      prefixIcon: Icon(Icons.storefront_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Kurum adı zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('category_field'),
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      hintText: 'Örneğin: Market',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Kategori zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('amount_field'),
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Tutar',
                      hintText: '0,00',
                      prefixIcon: Icon(Icons.payments_outlined),
                      suffixText: 'TL',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                    ],
                    validator: (value) {
                      final amountInMinor = parseTurkishLiraToMinor(value);
                      if (amountInMinor == null) {
                        return 'Geçerli bir tutar giriniz';
                      }
                      if (amountInMinor <= 0) {
                        return 'Tutar sıfırdan büyük olmalıdır';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            if (widget.mode == TransactionDraftPageMode.ocrReview &&
                widget.normalizedOcrText?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 16),
              AppCard(
                child: ExpansionTile(
                  key: const Key('normalized_ocr_text_tile'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('Düzeltilmiş OCR metni'),
                  subtitle: const Text(
                    'Yapay zekânın düzenlediği fiş metnini görüntüleyin.',
                  ),
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SelectableText(widget.normalizedOcrText!),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('cancel_draft_button'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Vazgeç'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              key: const Key('confirm_draft_button'),
              onPressed: _confirmDraft,
              icon: const Icon(Icons.check_rounded),
              label: Text(
                widget.mode == TransactionDraftPageMode.manual
                    ? 'Gideri Kaydet'
                    : 'Onayla',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DraftHeader extends StatelessWidget {
  const _DraftHeader({required this.mode});

  final TransactionDraftPageMode mode;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.mint,
        child: Icon(
          mode == TransactionDraftPageMode.manual
              ? Icons.edit_note_rounded
              : Icons.receipt_long_outlined,
          color: AppColors.primary,
          size: 28,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                mode == TransactionDraftPageMode.manual ? 'MANUEL' : 'TASLAK',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mode == TransactionDraftPageMode.manual
                  ? 'Gider bilgilerini girin'
                  : 'Fiş bilgilerini kontrol edin',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              mode == TransactionDraftPageMode.manual
                  ? 'Kurum, kategori ve tutar bilgilerini elle ekleyin.'
                  : 'Kaydetmeden önce yapay zekânın çıkardığı bilgileri '
                        'düzenleyebilirsiniz.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}
