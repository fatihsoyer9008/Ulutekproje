enum SavingsGoalStatus {
  completed,
  overdue,
  aheadOfPlan,
  behindPlan,
  deadlineApproaching,
  progressingWell,
  gettingStarted,
}

SavingsGoalStatus calculateSavingsGoalStatus({
  required double progress,
  required DateTime createdAt,
  required DateTime? targetDate,
  required DateTime now,
}) {
  if (progress >= 1) return SavingsGoalStatus.completed;
  if (targetDate == null) {
    return progress >= .30
        ? SavingsGoalStatus.progressingWell
        : SavingsGoalStatus.gettingStarted;
  }

  final daysLeft = targetDate.difference(now).inDays;
  if (daysLeft < 0) return SavingsGoalStatus.overdue;

  final totalDays = targetDate.difference(createdAt).inDays;
  final elapsedDays = now.difference(createdAt).inDays;
  if (totalDays > 0) {
    final expectedProgress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    if (progress >= expectedProgress + .05) {
      return SavingsGoalStatus.aheadOfPlan;
    }
    if (progress <= expectedProgress - .05) {
      return SavingsGoalStatus.behindPlan;
    }
  }
  if (daysLeft <= 30) return SavingsGoalStatus.deadlineApproaching;
  return progress >= .30
      ? SavingsGoalStatus.progressingWell
      : SavingsGoalStatus.gettingStarted;
}

int? requiredMonthlySavingsInMinor({
  required int remainingAmountInMinor,
  required DateTime? targetDate,
  required DateTime now,
}) {
  if (remainingAmountInMinor <= 0 ||
      targetDate == null ||
      !targetDate.isAfter(now)) {
    return null;
  }
  final months = (targetDate.difference(now).inDays / 30).ceil().clamp(1, 360);
  return (remainingAmountInMinor / months).ceil();
}

const int savingsGoalLevelCount = 5;

class SavingsGoalLevelTransition {
  const SavingsGoalLevelTransition({
    required this.previousLevel,
    required this.currentLevel,
  });

  final int previousLevel;
  final int currentLevel;

  bool get didLevelUp => currentLevel > previousLevel;

  int get gainedLevelCount => currentLevel - previousLevel;
}

int calculateSavingsGoalLevel({
  required int amountInMinor,
  required int targetAmountInMinor,
}) {
  if (targetAmountInMinor <= 0) {
    throw ArgumentError.value(
      targetAmountInMinor,
      'targetAmountInMinor',
      'Hedef tutarı sıfırdan büyük olmalıdır.',
    );
  }

  final safeAmount = amountInMinor.clamp(0, targetAmountInMinor);
  final progress = safeAmount / targetAmountInMinor;

  return (progress * savingsGoalLevelCount).floor().clamp(
    0,
    savingsGoalLevelCount,
  );
}

SavingsGoalLevelTransition calculateSavingsGoalLevelTransition({
  required int previousAmountInMinor,
  required int currentAmountInMinor,
  required int targetAmountInMinor,
}) {
  return SavingsGoalLevelTransition(
    previousLevel: calculateSavingsGoalLevel(
      amountInMinor: previousAmountInMinor,
      targetAmountInMinor: targetAmountInMinor,
    ),
    currentLevel: calculateSavingsGoalLevel(
      amountInMinor: currentAmountInMinor,
      targetAmountInMinor: targetAmountInMinor,
    ),
  );
}
