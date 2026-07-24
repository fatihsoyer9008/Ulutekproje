import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gelir Ekle')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Text('Düzenli Gelir', style: Theme.of(context).textTheme.headlineMedium),
      const Text('Her ay aldığın gelirleri buradan yönetebilirsin.'),
      const SizedBox(height: 24),
      const _IncomeTile(Icons.work_outline_rounded, 'Maaş', 'Her ayın 1. günü', '₺48.000'),
      const SizedBox(height: 12),
      const _IncomeTile(Icons.computer_rounded, 'Freelance', 'Değişken gelir', '₺4.750'),
    ]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Yeni gelir')),
  );
}
class _IncomeTile extends StatelessWidget {
  const _IncomeTile(this.icon, this.title, this.subtitle, this.amount);
  final IconData icon; final String title, subtitle, amount;
  @override
  Widget build(BuildContext context) => AppCard(child: Row(children: [
    CircleAvatar(backgroundColor: AppColors.mint, child: Icon(icon, color: AppColors.income)),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), Text(subtitle)])),
    Text(amount, style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w700)),
  ]));
}
