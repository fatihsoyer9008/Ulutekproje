import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import '../models/ui_models.dart';

abstract final class DummyData {
  static const categories = [
    CategorySummary('Yeme & İçme', '₺4.850', .72, AppColors.warning, Icons.restaurant_rounded),
    CategorySummary('Abonelikler', '₺1.240', .46, AppColors.blue, Icons.subscriptions_rounded),
    CategorySummary('Diğer', '₺920', .28, AppColors.primary, Icons.grid_view_rounded),
  ];
  static const goals = [
    SavingGoal('Tatil Fonu', 18400, 30000, Icons.beach_access_rounded, AppColors.blue),
    SavingGoal('Yeni Bilgisayar', 27500, 45000, Icons.laptop_mac_rounded, AppColors.primary),
    SavingGoal('Acil Durum', 40000, 50000, Icons.health_and_safety_rounded, AppColors.warning),
  ];
  static final events = <DateTime, List<CalendarEvent>>{
    DateTime(2026, 7, 1): const [CalendarEvent('Maaş', '+₺48.000', true)],
    DateTime(2026, 7, 4): const [CalendarEvent('Kira', '-₺14.000', false)],
    DateTime(2026, 7, 12): const [CalendarEvent('Netflix', '-₺300', false)],
    DateTime(2026, 7, 18): const [CalendarEvent('Market', '-₺1.250', false)],
  };
}
