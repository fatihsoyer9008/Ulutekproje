import 'package:app_main/features/savings/domain/savings_goal_insights.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 7);

  test('süresi geçmiş hedefi overdue olarak işaretler', () {
    expect(
      calculateSavingsGoalStatus(
        progress: .8,
        createdAt: DateTime(2026, 1, 1),
        targetDate: DateTime(2026, 8, 1),
        now: now,
      ),
      SavingsGoalStatus.overdue,
    );
  });

  test('gerçek ilerlemeyi zaman bazlı beklenen ilerlemeyle karşılaştırır', () {
    expect(
      calculateSavingsGoalStatus(
        progress: .70,
        createdAt: DateTime(2026, 1, 1),
        targetDate: DateTime(2027, 1, 1),
        now: DateTime(2026, 7, 2),
      ),
      SavingsGoalStatus.aheadOfPlan,
    );
    expect(
      calculateSavingsGoalStatus(
        progress: .40,
        createdAt: DateTime(2026, 1, 1),
        targetDate: DateTime(2027, 1, 1),
        now: DateTime(2026, 7, 2),
      ),
      SavingsGoalStatus.behindPlan,
    );
  });

  test('aylık gerekli katkıyı kuruş cinsinden yukarı yuvarlar', () {
    expect(
      requiredMonthlySavingsInMinor(
        remainingAmountInMinor: 10001,
        targetDate: now.add(const Duration(days: 90)),
        now: now,
      ),
      3334,
    );
  });
}
