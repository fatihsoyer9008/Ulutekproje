import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_budget_reminder_service.dart';

final dailyBudgetReminderServiceProvider = Provider<DailyBudgetReminderService>(
  (ref) => DailyBudgetReminderService(),
);
