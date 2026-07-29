import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import '../../features/transaction_draft/presentation/transaction_draft_page.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key, this.saveTransaction});

  final Future<void> Function(TransactionEntity transaction)? saveTransaction;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gelir Ekle')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Yeni Gelir', style: Theme.of(context).textTheme.headlineMedium),
        const Text(
          'Maaş, freelance veya diğer gelirlerini buradan ekleyebilirsin.',
        ),
        const SizedBox(height: 24),
        const AppCard(
          color: AppColors.mintLight,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.mint,
                child: Icon(Icons.south_west_rounded, color: AppColors.income),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Kaydettiğin gelir anında bakiyene ve hesap hareketlerine yansır.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('add_income_button'),
      onPressed: () => _openIncomeEntry(context),
      icon: const Icon(Icons.add),
      label: const Text('Yeni gelir'),
    ),
  );

  Future<void> _openIncomeEntry(BuildContext context) async {
    final draft = await Navigator.of(context).push<TransactionDraft>(
      MaterialPageRoute(
        builder: (_) =>
            const TransactionDraftPage(mode: TransactionDraftPageMode.income),
      ),
    );
    if (!context.mounted || draft == null || saveTransaction == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await saveTransaction!(
        draft.toTransactionEntity(
          source: TransactionSource.manual,
          transactionType: TransactionType.income,
        ),
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Gelir başarıyla kaydedildi.')),
        );
    } on Exception catch (error) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Gelir kaydedilemedi: $error')));
    }
  }
}
