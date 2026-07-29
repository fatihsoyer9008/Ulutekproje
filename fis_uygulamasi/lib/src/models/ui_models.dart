import 'package:flutter/material.dart';

class CategorySummary {
  const CategorySummary(
    this.name,
    this.amount,
    this.progress,
    this.color,
    this.icon,
  );
  final String name;
  final String amount;
  final double progress;
  final Color color;
  final IconData icon;
}

class MonthlySpending {
  const MonthlySpending(this.label, this.amount);

  final String label;
  final double amount;
}

class SavingGoal {
  const SavingGoal(
    this.title,
    this.current,
    this.target,
    this.icon,
    this.color,
  );
  final String title;
  final double current;
  final double target;
  final IconData icon;
  final Color color;
}

class CalendarEvent {
  const CalendarEvent(this.title, this.amount, this.isIncome);
  final String title;
  final String amount;
  final bool isIncome;
}
