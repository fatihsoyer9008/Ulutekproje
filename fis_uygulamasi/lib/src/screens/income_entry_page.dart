import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/transaction_draft/model/turkish_money.dart';

class IncomeEntryPage extends StatefulWidget {
  const IncomeEntryPage({super.key});

  @override
  State<IncomeEntryPage> createState() => _IncomeEntryPageState();
}

class _IncomeEntryPageState extends State<IncomeEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _sourceController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Diğer Gelir';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _sourceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni Gelir Ekle')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.south_west_rounded, color: Colors.white),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gelirini kaydet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Kaynağı yaz, kategoriyi senin için belirleyelim.',
                          style: TextStyle(color: Colors.white70, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gelir bilgileri',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const Key('income_source_field'),
                    controller: _sourceController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Para Kaynağı',
                      hintText: 'Örn: Maaş veya freelance proje',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    onChanged: (value) =>
                        setState(() => _category = inferIncomeCategory(value)),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Para kaynağını yazmalısınız'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('income_amount_field'),
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Tutar',
                      hintText: 'Örn: 25.000,00',
                      prefixIcon: Icon(Icons.currency_lira_rounded),
                      suffixText: 'TL',
                    ),
                    validator: (value) {
                      final amount = parseTurkishLiraToMinor(value ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Geçerli bir tutar giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AnimatedContainer(
                    key: const Key('income_category_preview'),
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Gelir kategorisi: $_category',
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const Key('save_income_button'),
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSubmitting ? 'Kaydediliyor...' : 'Geliri Kaydet'),
            ),
          ],
        ),
      ),
    ),
  );

  void _submit() {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    Navigator.of(context).pop(
      TransactionDraft(
        institutionName: _sourceController.text.trim(),
        category: _category,
        amountInMinor: parseTurkishLiraToMinor(_amountController.text)!,
        transactionDate: now,
      ),
    );
  }
}

String inferIncomeCategory(String source) {
  final normalized = source.trim().toLowerCase();
  if (normalized.contains('maaş') ||
      normalized.contains('maas') ||
      normalized.contains('ücret') ||
      normalized.contains('bordro')) {
    return 'Maaş';
  }
  if (normalized.contains('freelance') ||
      normalized.contains('proje') ||
      normalized.contains('danışman') ||
      normalized.contains('serbest')) {
    return 'Freelance';
  }
  if (normalized.contains('prim') || normalized.contains('bonus')) {
    return 'Prim';
  }
  if (normalized.contains('yatırım') ||
      normalized.contains('temettü') ||
      normalized.contains('faiz')) {
    return 'Yatırım Geliri';
  }
  if (normalized.contains('satış') || normalized.contains('satis')) {
    return 'Satış Geliri';
  }
  return 'Diğer Gelir';
}
