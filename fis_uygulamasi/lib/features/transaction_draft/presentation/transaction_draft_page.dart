import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

import '../model/receipt_total_validation.dart';
import '../model/turkish_money.dart';
import 'widgets/receipt_total_mismatch_warning.dart';

enum TransactionDraftPageMode { manual, ocrReview, income }

class TransactionDraftPage extends StatefulWidget {
  const TransactionDraftPage({
    super.key,
    this.initialDraft = const TransactionDraft.empty(),
    this.normalizedOcrText,
    this.confidenceScore,
    this.isParseSuccessful = true,
    this.onSecureAnalysisRequested,
    this.mode = TransactionDraftPageMode.ocrReview,
    this.categories,
  }) : assert(
         confidenceScore == null ||
             (confidenceScore >= 0 && confidenceScore <= 1),
       );

  final TransactionDraft initialDraft;
  final String? normalizedOcrText;
  final double? confidenceScore;
  final bool isParseSuccessful;
  final VoidCallback? onSecureAnalysisRequested;
  final TransactionDraftPageMode mode;
  final List<CategoryEntity>? categories;

  @override
  State<TransactionDraftPage> createState() => _TransactionDraftPageState();
}

class _TransactionDraftPageState extends State<TransactionDraftPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _institutionController;
  late final TextEditingController _amountController;
  late final List<CategoryEntity> _categories;
  String? _selectedCategory;
  late final TextEditingController _dateController;
  DateTime? _transactionDate;
  late List<ReceiptItem> _receiptItems;
  bool _showDateRequiredError = false;
  bool _isConfirming = false;

  bool get _shouldOfferSecureAnalysis =>
      widget.mode == TransactionDraftPageMode.ocrReview &&
      widget.confidenceScore != null &&
      (!widget.isParseSuccessful ||
          widget.confidenceScore! <
              ReceiptLowConfidenceWarning.defaultThreshold);

  @override
  void initState() {
    super.initState();
    _institutionController = TextEditingController(
      text: widget.initialDraft.institutionName,
    );
    _categories = _buildCategories(
      widget.categories ?? createDefaultCategoryEntities(),
      widget.initialDraft.category,
    );
    _selectedCategory = _matchingCategoryName(
      _categories,
      widget.initialDraft.category,
    );

    final initialAmount = widget.initialDraft.amountInMinor;
    _amountController = TextEditingController(
      text: initialAmount == null
          ? ''
          : formatMinorAsTurkishLira(initialAmount),
    );
    _amountController.addListener(_onAmountChanged);

    _transactionDate = widget.initialDraft.transactionDate;
    _receiptItems = [...widget.initialDraft.receiptItems];
    _dateController = TextEditingController(
      text: _formatTransactionDate(_transactionDate),
    );
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _institutionController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  String _formatTransactionDate(DateTime? date) {
    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  Future<void> _selectTransactionDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(2000);
    final lastDate = DateTime(now.year + 5);
    final currentDate = _transactionDate ?? now;

    final initialDate = currentDate.isBefore(firstDate)
        ? firstDate
        : currentDate.isAfter(lastDate)
        ? lastDate
        : currentDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Fiş tarihini seçin',
    );

    if (selectedDate == null) return;

    setState(() {
      _transactionDate = selectedDate;
      _dateController.text = _formatTransactionDate(selectedDate);
      _showDateRequiredError = false;
    });
  }

  void _confirmDraft() {
    if (_isConfirming) return;

    if (widget.mode == TransactionDraftPageMode.ocrReview &&
        _transactionDate == null) {
      setState(() => _showDateRequiredError = true);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isConfirming = true);

    Navigator.of(context).pop(
      TransactionDraft(
        institutionName: _institutionController.text.trim(),
        category: _selectedCategory!.trim(),
        amountInMinor: parseTurkishLiraToMinor(_amountController.text)!,
        transactionDate: _transactionDate,
        rawOcrText: widget.initialDraft.rawOcrText,
        receiptItems: List.unmodifiable(_receiptItems),
      ),
    );
  }

  Future<void> _addReceiptItem() async {
    final item = await _showReceiptItemDialog();
    if (item == null || !mounted) return;
    setState(() => _receiptItems.add(item));
  }

  Future<void> _editReceiptItem(int index) async {
    final item = await _showReceiptItemDialog(
      initialItem: _receiptItems[index],
    );
    if (item == null || !mounted) return;
    setState(() => _receiptItems[index] = item);
  }

  void _deleteReceiptItem(int index) {
    setState(() => _receiptItems.removeAt(index));
  }

  Future<ReceiptItem?> _showReceiptItemDialog({ReceiptItem? initialItem}) {
    return showDialog<ReceiptItem>(
      context: context,
      builder: (context) => _ReceiptItemDialog(initialItem: initialItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiptTotalValidation = ReceiptTotalValidation.evaluate(
      items: _receiptItems,
      mainReceiptTotalInMinor: parseTurkishLiraToMinor(_amountController.text),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == TransactionDraftPageMode.manual
              ? 'Manuel Gider Ekle'
              : widget.mode == TransactionDraftPageMode.income
              ? 'Gelir Ekle'
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
                if (_shouldOfferSecureAnalysis) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Fiş fotoğrafını tekrar çekebilir veya aşağıdaki bilgileri elle kontrol edebilirsiniz.',
                    key: Key('retake_receipt_suggestion'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      key: const Key('secure_analysis_button'),
                      onPressed: widget.onSecureAnalysisRequested,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Görseli güvenli analiz için gönder'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              if (widget.mode == TransactionDraftPageMode.ocrReview &&
                  receiptTotalValidation.hasMismatch) ...[
                const SizedBox(height: 16),
                ReceiptTotalMismatchWarning(
                  itemsTotalInMinor:
                      receiptTotalValidation.calculatedItemsTotalInMinor!,
                  receiptTotalInMinor:
                      receiptTotalValidation.mainReceiptTotalInMinor!,
                ),
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Kurum adı zorunludur'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const Key('category_field'),
                      initialValue: _selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        hintText: 'Kategori seçin',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final category in _categories)
                          DropdownMenuItem(
                            value: category.name,
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Kategori zorunludur'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('transaction_date_field'),
                      controller: _dateController,
                      readOnly: true,
                      onTap: _selectTransactionDate,
                      decoration: InputDecoration(
                        labelText: 'Fiş Tarihi',
                        hintText: 'Tarih bulunamadı - seçmek için dokunun',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        suffixIcon: IconButton(
                          tooltip: 'Tarih seç',
                          onPressed: _selectTransactionDate,
                          icon: const Icon(Icons.edit_calendar_outlined),
                        ),
                        errorText: _showDateRequiredError
                            ? 'Fiş tarihi zorunludur'
                            : null,
                        border: const OutlineInputBorder(),
                      ),
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
              if (widget.mode == TransactionDraftPageMode.ocrReview) ...[
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Fiş ürünleri',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            key: const Key('add_receipt_item_button'),
                            onPressed: _addReceiptItem,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Ürün ekle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _receiptItems.isEmpty
                            ? 'Fişte ürün bulunamadı. Ürünleri elle ekleyebilirsiniz.'
                            : 'Okunan ürünleri kaydetmeden önce kontrol edin.',
                        key: const Key('receipt_items_description'),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      if (_receiptItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (
                          var index = 0;
                          index < _receiptItems.length;
                          index++
                        )
                          _ReceiptItemTile(
                            key: ValueKey('receipt_item_$index'),
                            item: _receiptItems[index],
                            onEdit: () => _editReceiptItem(index),
                            onDelete: () => _deleteReceiptItem(index),
                            index: index,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
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
                onPressed: _isConfirming ? null : _confirmDraft,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.mode == TransactionDraftPageMode.manual
                      ? 'Gideri Kaydet'
                      : widget.mode == TransactionDraftPageMode.income
                      ? 'Geliri Kaydet'
                      : 'Onayla',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptItemTile extends StatelessWidget {
  const _ReceiptItemTile({
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ReceiptItem item;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final total = item.totalAmountInMinor ?? item.priceMinor;
    final quantity = item.quantity;
    final details = <String>[
      if (quantity != null) '${_formatQuantity(quantity)} adet',
      if (item.unitPriceInMinor != null)
        '${formatMinorAsTurkishLira(item.unitPriceInMinor!)} TL/birim',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  key: ValueKey('receipt_item_name_$index'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (details.isNotEmpty)
                  Text(
                    details.join(' • '),
                    style: const TextStyle(color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (total != null)
            Text(
              '${formatMinorAsTurkishLira(total)} TL',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          IconButton(
            key: ValueKey('edit_receipt_item_$index'),
            tooltip: 'Ürünü düzenle',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            key: ValueKey('delete_receipt_item_$index'),
            tooltip: 'Ürünü sil',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _ReceiptItemDialog extends StatefulWidget {
  const _ReceiptItemDialog({this.initialItem});

  final ReceiptItem? initialItem;

  @override
  State<_ReceiptItemDialog> createState() => _ReceiptItemDialogState();
}

class _ReceiptItemDialogState extends State<_ReceiptItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(
      text: _formatQuantity(item?.quantity ?? 1),
    );
    _unitPriceController = TextEditingController(
      text: item?.unitPriceInMinor == null
          ? ''
          : formatMinorAsTurkishLira(item!.unitPriceInMinor!),
    );
    final total = item?.totalAmountInMinor ?? item?.priceMinor;
    _totalController = TextEditingController(
      text: total == null ? '' : formatMinorAsTurkishLira(total),
    );
    _quantityController.addListener(_recalculateTotal);
    _unitPriceController.addListener(_recalculateTotal);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_recalculateTotal);
    _unitPriceController.removeListener(_recalculateTotal);
    _nameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _recalculateTotal() {
    final quantity = _parseQuantity(_quantityController.text);
    final unitPrice = parseTurkishLiraToMinor(_unitPriceController.text);
    if (quantity == null || quantity <= 0 || unitPrice == null) return;

    final total = ReceiptTotalValidation.calculateItemTotalInMinor(
      ReceiptItem(
        name: _nameController.text,
        quantity: quantity,
        unitPriceInMinor: unitPrice,
      ),
    );
    if (total != null) {
      _totalController.text = formatMinorAsTurkishLira(total);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final initial = widget.initialItem;
    final total = parseTurkishLiraToMinor(_totalController.text)!;
    Navigator.of(context).pop(
      ReceiptItem(
        name: _nameController.text.trim(),
        category: initial?.category,
        priceMinor: total,
        totalAmountInMinor: total,
        quantity: _parseQuantity(_quantityController.text),
        unitPriceInMinor: parseTurkishLiraToMinor(_unitPriceController.text),
        taxRate: initial?.taxRate,
        taxAmountInMinor: initial?.taxAmountInMinor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialItem == null ? 'Ürün ekle' : 'Ürünü düzenle'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('receipt_item_name_field'),
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Ürün adı',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ürün adı zorunludur'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('receipt_item_quantity_field'),
              controller: _quantityController,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Miktar',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final quantity = _parseQuantity(value);
                return quantity == null || quantity <= 0
                    ? 'Geçerli bir miktar giriniz'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('receipt_item_unit_price_field'),
              controller: _unitPriceController,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,. \s]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Birim fiyat (isteğe bağlı)',
                suffixText: 'TL',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? null
                  : parseTurkishLiraToMinor(value) == null
                  ? 'Geçerli bir fiyat giriniz'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('receipt_item_total_field'),
              controller: _totalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,. \s]')),
              ],
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Satır toplamı',
                suffixText: 'TL',
                border: OutlineInputBorder(),
              ),
              validator: (value) => parseTurkishLiraToMinor(value) == null
                  ? 'Geçerli bir toplam giriniz'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        key: const Key('save_receipt_item_button'),
        onPressed: _submit,
        child: const Text('Kaydet'),
      ),
    ],
  );
}

double? _parseQuantity(String? value) =>
    double.tryParse(value?.trim().replaceAll(',', '.') ?? '');

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString().replaceAll('.', ',');

List<CategoryEntity> _buildCategories(
  List<CategoryEntity> source,
  String initialCategory,
) {
  final categories = [...source];
  final trimmedInitial = initialCategory.trim();
  if (trimmedInitial.isNotEmpty &&
      _matchingCategoryName(categories, trimmedInitial) == null) {
    categories.add(
      CategoryEntity()
        ..name = trimmedInitial
        ..colorValue = 0xFF546E7A
        ..iconCodePoint = Icons.category_outlined.codePoint
        ..createdAt = DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
  return categories;
}

String? _matchingCategoryName(
  List<CategoryEntity> categories,
  String categoryName,
) {
  final normalised = _normaliseCategory(categoryName);
  if (normalised.isEmpty) return null;
  for (final category in categories) {
    if (_normaliseCategory(category.name) == normalised) return category.name;
  }
  return null;
}

String _normaliseCategory(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'\s+'), '');

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
              : mode == TransactionDraftPageMode.income
              ? Icons.south_west_rounded
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
                mode == TransactionDraftPageMode.manual
                    ? 'MANUEL'
                    : mode == TransactionDraftPageMode.income
                    ? 'GELİR'
                    : 'TASLAK',
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
                  : mode == TransactionDraftPageMode.income
                  ? 'Gelir bilgilerini girin'
                  : 'Fiş bilgilerini kontrol edin',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              mode == TransactionDraftPageMode.manual
                  ? 'Kurum, kategori ve tutar bilgilerini elle ekleyin.'
                  : mode == TransactionDraftPageMode.income
                  ? 'Gelir kaynağı, türü ve tutar bilgilerini ekleyin.'
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
