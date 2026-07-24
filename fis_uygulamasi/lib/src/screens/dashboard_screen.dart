import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'expense_screen.dart';
import 'income_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
    children: [
      const Text('Finansal durumun'),
      Text('Kontrol sende.', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary]),
          boxShadow: const [BoxShadow(color: Color(0x40276B5A), blurRadius: 28, offset: Offset(0, 14))],
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('TOPLAM BAKİYE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1)),
            Icon(Icons.visibility_outlined, color: Colors.white70),
          ]),
          SizedBox(height: 12),
          Text('₺32.760,00', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
          SizedBox(height: 25),
          Row(children: [
            Expanded(child: _BalanceStat('Maaş', '₺28.000')),
            SizedBox(width: 14),
            Expanded(child: _BalanceStat('Ekstra', '₺4.760')),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: PrimaryActionButton(label: 'Gelir Gir', icon: Icons.south_west_rounded, onPressed: () => _open(context, const IncomeScreen()))),
        const SizedBox(width: 12),
        Expanded(child: PrimaryActionButton(label: 'Gider Gir', icon: Icons.north_east_rounded, isPrimary: false, onPressed: () => _open(context, const ExpenseScreen()))),
      ]),
      const SizedBox(height: 28),
      Text('Hatırlatıcı', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      AppCard(
        color: AppColors.mintLight,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CircleAvatar(backgroundColor: AppColors.mint, child: Icon(Icons.notifications_active_outlined, color: AppColors.primary)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bu hafta 2 ödeme var', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            const Text('Netflix yarın, internet faturası ise 3 gün sonra ödenecek.'),
          ])),
        ]),
      ),
    ],
  );
  static void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
    ]),
  );
}
