import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import '../models/ui_models.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key, this.goals = const []});

  final List<SavingGoal> goals;

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.goals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: AppCard(
          child: Center(child: Text('Henüz birikim hedefi bulunmuyor.')),
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Hedeflerine küçük adımlarla yaklaş.'),
        ),
        Expanded(
          child: PageView.builder(
            controller: PageController(viewportFraction: .88),
            itemCount: widget.goals.length,
            onPageChanged: (v) => setState(() => page = v),
            itemBuilder: (_, i) => _GoalCard(goal: widget.goals[i]),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.goals.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: page == i ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: page == i ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final SavingGoal goal;
  @override
  Widget build(BuildContext context) {
    final progress = goal.current / goal.target;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 28),
      child: AppCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: goal.color.withValues(alpha: .12),
              ),
              child: Icon(goal.icon, size: 80, color: goal.color),
            ),
            const SizedBox(height: 24),
            Text(goal.title, style: Theme.of(context).textTheme.headlineMedium),
            Text('%${(progress * 100).round()} tamamlandı'),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(10),
              color: goal.color,
              backgroundColor: goal.color.withValues(alpha: .14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₺${goal.current.toStringAsFixed(0)}'),
                Text('Hedef ₺${goal.target.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Para Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
