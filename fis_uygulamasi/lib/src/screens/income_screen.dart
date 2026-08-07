import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import 'income_entry_page.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key, this.saveTransaction});

  final Future<void> Function(TransactionEntity transaction)? saveTransaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Gelir Ekle')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Yeni Gelir',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Maaş, freelance veya diğer gelirlerini buradan ekleyebilirsin.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh
                : AppColors.mintLight,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDark
                      ? theme.colorScheme.primaryContainer
                      : AppColors.mint,
                  child: Icon(
                    Icons.south_west_rounded,
                    color: isDark
                        ? theme.colorScheme.onPrimaryContainer
                        : AppColors.income,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Kaydettiğin gelir anında bakiyene ve hesap hareketlerine yansır.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
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
  }

  Future<void> _openIncomeEntry(BuildContext context) async {
    final draft = await Navigator.of(context).push<TransactionDraft>(
      MaterialPageRoute(builder: (_) => const IncomeEntryPage()),
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
