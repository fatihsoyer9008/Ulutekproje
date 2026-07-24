import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 120), children: [
    const TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Hareketlerde ara...')),
    const SizedBox(height: 20),
    Text('Bugün', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    const _Transaction('Kahve Dünyası', 'Yeme & İçme', '-₺185', Icons.local_cafe_outlined, false),
    const SizedBox(height: 10),
    const _Transaction('Freelance ödeme', 'Ek gelir', '+₺4.750', Icons.computer, true),
    const SizedBox(height: 20),
    Text('Dün', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    const _Transaction('Migros', 'Market', '-₺1.240', Icons.shopping_basket_outlined, false),
  ]);
}
class _Transaction extends StatelessWidget {
  const _Transaction(this.title, this.category, this.amount, this.icon, this.income);
  final String title, category, amount; final IconData icon; final bool income;
  @override
  Widget build(BuildContext context) => AppCard(padding: const EdgeInsets.all(16), child: Row(children: [
    CircleAvatar(backgroundColor: AppColors.mintLight, child: Icon(icon, color: AppColors.primary)),
    const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), Text(category)])),
    Text(amount, style: TextStyle(fontWeight: FontWeight.w700, color: income ? AppColors.income : AppColors.expense)),
  ]));
}
