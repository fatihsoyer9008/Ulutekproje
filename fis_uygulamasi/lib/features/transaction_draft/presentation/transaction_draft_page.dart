import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

import '../model/turkish_money.dart';

enum TransactionDraftPageMode { manual, ocrReview, income }

class TransactionDraftPage extends StatefulWidget {
  const TransactionDraftPage({
    super.key,
    this.initialDraft = const TransactionDraft.empty(),
    this.normalizedOcrText,
    this.confidenceScore,
    this.isParseSuccessful = true,
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
  late List<ReceiptLineItemDraft> _lineItems;
  bool _showDateRequiredError = false;
  bool _isConfirming = false;

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

    _transactionDate = widget.initialDraft.transactionDate;
    _lineItems = [...widget.initialDraft.lineItems];
    _dateController = TextEditingController(
      text: _formatTransactionDate(_transactionDate),
    );
  }

  @override
  void dispose() {
    _institutionController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
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
        lineItems: List.unmodifiable(_lineItems),
      ),
    );
  }

  int? get _enteredAmountInMinor =>
      parseTurkishLiraToMinor(_amountController.text);

  int get _lineItemsTotalInMinor =>
      _lineItems.fold(0, (total, item) => total + item.totalAmountInMinor);

  bool get _hasTotalMismatch =>
      _lineItems.isNotEmpty &&
      _enteredAmountInMinor != null &&
      _lineItemsTotalInMinor != _enteredAmountInMinor;

  Future<void> _openLineItemEditor({int? index}) async {
    final current = index == null ? null : _lineItems[index];
    final result = await showDialog<ReceiptLineItemDraft>(
      context: context,
      builder: (_) => _LineItemEditorDialog(initialItem: current),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _lineItems.add(result);
      } else {
        _lineItems[index] = result;
      }
    });
  }

  void _deleteLineItem(int index) => setState(() => _lineItems.removeAt(index));

  @override
  Widget build(BuildContext context) => Scaffold(
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
              if (!widget.isParseSuccessful ||
                  widget.confidenceScore! <
                      ReceiptLowConfidenceWarning.defaultThreshold) ...[
                const SizedBox(height: 8),
                const Text(
                  'Fiş fotoğrafını tekrar çekebilir veya aşağıdaki bilgileri elle kontrol edebilirsiniz.',
                  key: Key('retake_receipt_suggestion'),
                ),
                const SizedBox(height: 16),
              ],
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
                    validator: (value) => value == null || value.trim().isEmpty
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
                    onChanged: (_) => setState(() {}),
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
                            'Ürün kalemleri',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('add_line_item_button'),
                          onPressed: _openLineItemEditor,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Ürün Ekle'),
                        ),
                      ],
                    ),
                    if (_lineItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Fişte ürün kalemi bulunamadı.'),
                      )
                    else
                      for (var index = 0; index < _lineItems.length; index++)
                        _LineItemTile(
                          key: Key('line_item_$index'),
                          item: _lineItems[index],
                          onEdit: () => _openLineItemEditor(index: index),
                          onDelete: () => _deleteLineItem(index),
                        ),
                    if (_hasTotalMismatch) ...[
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('line_items_total_mismatch_warning'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ürünlerin toplamı (${formatMinorAsTurkishLira(_lineItemsTotalInMinor)} TL) '
                                'ile fiş toplamı (${formatMinorAsTurkishLira(_enteredAmountInMinor!)} TL) eşleşmiyor.',
                                style: TextStyle(color: Colors.red.shade800),
                              ),
                            ),
                          ],
                        ),
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

class _LineItemEditorDialog extends StatefulWidget {
  const _LineItemEditorDialog({this.initialItem});

  final ReceiptLineItemDraft? initialItem;

  @override
  State<_LineItemEditorDialog> createState() => _LineItemEditorDialogState();
}

class _LineItemEditorDialogState extends State<_LineItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(
      text: _formatQuantity(item?.quantityInMillis ?? 1000),
    );
    _totalController = TextEditingController(
      text: item == null
          ? ''
          : formatMinorAsTurkishLira(item.totalAmountInMinor),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final initial = widget.initialItem;
    Navigator.pop(
      context,
      ReceiptLineItemDraft(
        name: _nameController.text.trim(),
        totalAmountInMinor: parseTurkishLiraToMinor(_totalController.text)!,
        quantityInMillis: _parseQuantityInMillis(_quantityController.text)!,
        unitPriceInMinor: initial?.unitPriceInMinor,
        taxRateInBasisPoints: initial?.taxRateInBasisPoints,
        category: initial?.category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('line_item_editor_dialog'),
    title: Text(widget.initialItem == null ? 'Ürün Ekle' : 'Ürünü Düzenle'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const Key('line_item_name_field'),
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Ürün adı'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Ürün adı zorunludur'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('line_item_quantity_field'),
            controller: _quantityController,
            decoration: const InputDecoration(labelText: 'Miktar'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) => _parseQuantityInMillis(value) == null
                ? 'Geçerli bir miktar giriniz'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('line_item_total_field'),
            controller: _totalController,
            decoration: const InputDecoration(
              labelText: 'Toplam fiyat',
              suffixText: 'TL',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final amount = parseTurkishLiraToMinor(value);
              return amount == null || amount < 0
                  ? 'Geçerli bir fiyat giriniz'
                  : null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        key: const Key('save_line_item_button'),
        onPressed: _save,
        child: const Text('Kaydet'),
      ),
    ],
  );
}

class _LineItemTile extends StatelessWidget {
  const _LineItemTile({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ReceiptLineItemDraft item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(item.name),
    subtitle: Text('${_formatQuantity(item.quantityInMillis)} adet'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${formatMinorAsTurkishLira(item.totalAmountInMinor)} TL'),
        IconButton(
          key: Key('edit_line_item_${item.name}'),
          tooltip: 'Ürünü düzenle',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: Key('delete_line_item_${item.name}'),
          tooltip: 'Ürünü sil',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
  );
}

String _formatQuantity(int quantityInMillis) {
  if (quantityInMillis % 1000 == 0) return '${quantityInMillis ~/ 1000}';
  return (quantityInMillis / 1000)
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '')
      .replaceAll('.', ',');
}

int? _parseQuantityInMillis(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  final parsed = double.tryParse(normalized ?? '');
  if (parsed == null || parsed <= 0) return null;
  return (parsed * 1000).round();
}

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
