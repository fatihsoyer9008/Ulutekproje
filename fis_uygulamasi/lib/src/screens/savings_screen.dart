import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../data/dummy_data.dart';
import '../models/ui_models.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  int page = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: .88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Hedeflerine küçük adımlarla yaklaş.'),
      ),
      Expanded(
        child: PageView.builder(
          controller: _pageController,
          itemCount: DummyData.goals.length,
          onPageChanged: (value) => setState(() => page = value),
          itemBuilder: (_, index) => _GoalCard(goal: DummyData.goals[index]),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          DummyData.goals.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: page == index ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: page == index ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      const SizedBox(height: 100),
    ],
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final SavingGoal goal;

  @override
  Widget build(BuildContext context) {
    final progress = goal.current / goal.target;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: AppCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 410;
            final illustrationSize = compact ? 104.0 : 144.0;
            final largeGap = compact ? 10.0 : 20.0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: illustrationSize,
                  height: illustrationSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: goal.color.withValues(alpha: .12),
                  ),
                  child: Icon(
                    goal.icon,
                    size: illustrationSize / 2,
                    color: goal.color,
                  ),
                ),
                SizedBox(height: largeGap),
                Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text('%${(progress * 100).round()} tamamlandı'),
                SizedBox(height: largeGap),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: compact ? 8 : 12,
                  borderRadius: BorderRadius.circular(10),
                  color: goal.color,
                  backgroundColor: goal.color.withValues(alpha: .14),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('₺${goal.current.toStringAsFixed(0)}'),
                    Text('Hedef ₺${goal.target.toStringAsFixed(0)}'),
                  ],
                ),
                SizedBox(height: compact ? 10 : 16),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Para Ekle'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
