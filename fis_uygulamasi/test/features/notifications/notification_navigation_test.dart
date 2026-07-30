import 'package:app_main/features/notifications/daily_budget_reminder_service.dart';
import 'package:app_main/features/notifications/notification_navigation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fiş payloadı navigasyon hazır olduğunda gider rotasını açar', () {
    final visitedRoutes = <String>[];
    final controller = NotificationNavigationController();

    controller.attachNavigator(visitedRoutes.add);

    controller.setNavigationReady(true);

    controller.handlePayload(DailyBudgetReminderService.expenseReceiptPayload);

    expect(visitedRoutes, [
      NotificationNavigationController.expenseReceiptRoute,
    ]);
  });

  test('fiş payloadı navigasyon hazır olana kadar bekletilir', () {
    final visitedRoutes = <String>[];
    final controller = NotificationNavigationController();

    controller.attachNavigator(visitedRoutes.add);

    controller.handlePayload(DailyBudgetReminderService.expenseReceiptPayload);

    expect(visitedRoutes, isEmpty);

    controller.setNavigationReady(true);

    expect(visitedRoutes, [
      NotificationNavigationController.expenseReceiptRoute,
    ]);
  });

  test('bilinmeyen payload yönlendirme yapmaz', () {
    final visitedRoutes = <String>[];
    final controller = NotificationNavigationController();

    controller.attachNavigator(visitedRoutes.add);

    controller.setNavigationReady(true);
    controller.handlePayload('unknown');

    expect(visitedRoutes, isEmpty);
  });
}
