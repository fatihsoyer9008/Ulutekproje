import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/transaction_draft.dart';
import '../model/turkish_money.dart';

class TransactionDraftPage extends StatefulWidget {
  const TransactionDraftPage({
  super.key,
  this.initialDraft = const TransactionDraft.empty(),
});

  final TransactionDraft initialDraft;

  @override
  State<TransactionDraftPage> createState() =>
      _TransactionDraftPageState();
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final confirmedDraft = TransactionDraft(
      institutionName: _institutionController.text.trim(),
      category: _categoryController.text.trim(),
      amountInMinor: parseTurkishLiraToMinor(_amountController.text)!,
    );

    Navigator.of(context).pop(confirmedDraft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İşlemi Kontrol Et'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Fiş bilgilerini kontrol edin',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Yapay zekânın çıkardığı bilgileri kaydetmeden önce '
                'düzenleyebilirsiniz.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('institution_name_field'),
                controller: _institutionController,
                decoration: const InputDecoration(
                  labelText: 'Kurum Adı',
                  hintText: 'Örneğin: Migros',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kurum adı zorunludur';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('category_field'),
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  hintText: 'Örneğin: Market',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kategori zorunludur';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('amount_field'),
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Tutar',
                  hintText: '0,00',
                  suffixText: 'TL',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9,.\s]'),
                  ),
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
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('cancel_draft_button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('confirm_draft_button'),
                onPressed: _confirmDraft,
                child: const Text('Onayla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
