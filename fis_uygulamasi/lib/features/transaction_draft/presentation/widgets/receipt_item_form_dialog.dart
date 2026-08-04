import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/receipt_total_validation.dart';
import '../../model/turkish_money.dart';

class ReceiptItemFormDialog extends StatefulWidget {
  const ReceiptItemFormDialog({this.initialItem, super.key});

  final ReceiptItem? initialItem;

  @override
  State<ReceiptItemFormDialog> createState() =>
      _ReceiptItemFormDialogState();
}

class _ReceiptItemFormDialogState extends State<ReceiptItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    final quantity = item?.quantity ?? 1;
    final unitPrice = item?.unitPriceInMinor ?? item?.priceMinor;
    _nameController = TextEditingController(text: item?.name ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _quantityController = TextEditingController(text: _formatQuantity(quantity));
    _unitPriceController = TextEditingController(
      text: unitPrice == null ? '' : formatMinorAsTurkishLira(unitPrice),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  String _formatQuantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString().replaceAll('.', ',');

  double? _parseQuantity(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final quantity = _parseQuantity(_quantityController.text)!;
    final unitPrice = parseTurkishLiraToMinor(_unitPriceController.text)!;
    final provisional = ReceiptItem(
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      quantity: quantity,
      unitPriceInMinor: unitPrice,
      priceMinor: unitPrice,
      taxRate: widget.initialItem?.taxRate,
      taxAmountInMinor: widget.initialItem?.taxAmountInMinor,
    );
    Navigator.of(context).pop(
      ReceiptItem(
        name: provisional.name,
        category: provisional.category,
        quantity: quantity,
        unitPriceInMinor: unitPrice,
        priceMinor: unitPrice,
        totalAmountInMinor:
            ReceiptTotalValidation.calculateItemTotalInMinor(provisional),
        taxRate: provisional.taxRate,
        taxAmountInMinor: provisional.taxAmountInMinor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialItem == null ? 'Ürün ekle' : 'Ürünü düzenle'),
    content: SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Ürün adı',
              textField: true,
              child: TextFormField(
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('receipt_item_category_field'),
              controller: _categoryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Kategori (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Ürün miktarı',
              textField: true,
              child: TextFormField(
                key: const Key('receipt_item_quantity_field'),
                controller: _quantityController,
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
                  final quantity = _parseQuantity(value ?? '');
                  return quantity == null || quantity <= 0
                      ? 'Miktar sıfırdan büyük olmalıdır'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Ürün birim fiyatı Türk lirası',
              textField: true,
              child: TextFormField(
                key: const Key('receipt_item_unit_price_field'),
                controller: _unitPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Birim fiyat',
                  suffixText: 'TL',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = parseTurkishLiraToMinor(value);
                  return amount == null || amount < 0
                      ? 'Geçerli bir tutar giriniz'
                      : null;
                },
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('cancel_receipt_item_form_button'),
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
