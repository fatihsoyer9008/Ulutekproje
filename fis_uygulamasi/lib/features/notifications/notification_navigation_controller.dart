import 'package:flutter/foundation.dart';

import 'daily_budget_reminder_service.dart';

typedef NotificationRouteNavigator = void Function(String location);

class NotificationNavigationController {
  static const expenseReceiptRoute = '/expense/receipt';

  NotificationRouteNavigator? _navigate;
  String? _pendingRoute;
  bool _navigationReady = false;

  @visibleForTesting
  static String? routeForPayload(String? payload) {
    if (payload == DailyBudgetReminderService.expenseReceiptPayload) {
      return expenseReceiptRoute;
    }

    return null;
  }

  void handlePayload(String? payload) {
    final route = routeForPayload(payload);

    if (route == null) {
      return;
    }

    _pendingRoute = route;
    _flush();
  }

  void attachNavigator(NotificationRouteNavigator navigate) {
    _navigate = navigate;
    _flush();
  }

  void detachNavigator() {
    _navigate = null;
    _navigationReady = false;
  }

  void setNavigationReady(bool ready) {
    _navigationReady = ready;
    _flush();
  }

  void _flush() {
    final navigate = _navigate;
    final route = _pendingRoute;

    if (!_navigationReady || navigate == null || route == null) {
      return;
    }

    _pendingRoute = null;
    navigate(route);
  }
}
