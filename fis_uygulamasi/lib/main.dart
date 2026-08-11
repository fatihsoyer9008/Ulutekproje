import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_database/finance_database.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'application/service/isar_service.dart';
import 'core/database/database_providers.dart';
import 'features/auth/presentation/controllers/auth_session_controller.dart';
import 'features/backup/data/transaction_json_import_service.dart';
import 'features/notifications/daily_budget_reminder_service.dart';
import 'features/notifications/notification_navigation_controller.dart';
import 'features/notifications/notification_preferences.dart';
import 'features/notifications/notification_providers.dart';
import 'features/groups/data/fake_group_repository.dart';
import 'features/sync/application/offline_first_transaction_writer.dart';
import 'features/sync/application/sync_coordinator.dart';
import 'src/app/finance_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  final notificationNavigationController = NotificationNavigationController();

  final reminderService = DailyBudgetReminderService(
    onNotificationTap: notificationNavigationController.handlePayload,
  );

  final isar = await IsarService.getInstance();
  await CategoryRepository(isar).ensureDefaultCategories();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        dailyBudgetReminderServiceProvider.overrideWithValue(reminderService),
        groupRepositoryProvider.overrideWithValue(FakeGroupRepository.sample()),
      ],
      child: _AppBootstrap(
        notificationNavigationController: notificationNavigationController,
      ),
    ),
  );

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    unawaited(
      _initializeNotifications(
        reminderService,
        notificationNavigationController,
      ),
    );
  }
}

Future<void> _initializeNotifications(
  DailyBudgetReminderService reminderService,
  NotificationNavigationController navigationController,
) async {
  try {
    await reminderService.initialize();

    final launchPayload = await reminderService.getLaunchPayload();

    navigationController.handlePayload(launchPayload);

    await _restoreDailyReminder(reminderService);
  } catch (error, stackTrace) {
    debugPrint('Bildirim sistemi başlatılamadı: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _restoreDailyReminder(
  DailyBudgetReminderService reminderService,
) async {
  try {
    final preferences = NotificationPreferences();
    final enabled = await preferences.isEnabled();

    if (!enabled) {
      return;
    }

    final reminderTime = await preferences.getReminderTime();

    await reminderService.scheduleDailyReminder(reminderTime);
  } catch (error, stackTrace) {
    debugPrint('Günlük hatırlatıcı geri yüklenemedi: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class _AppBootstrap extends ConsumerWidget {
  const _AppBootstrap({required this.notificationNavigationController});

  final NotificationNavigationController notificationNavigationController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionRepository = ref.watch(transactionRepositoryProvider);
    final offlineFirstWriter = OfflineFirstTransactionWriter(
      saveTransaction: (transaction) async {
        await transactionRepository.addTransaction(transaction);
      },
      saveTransactionWithOfflineTask: (transaction, buildOfflineTask) async {
        await transactionRepository.addTransactionWithOfflineTask(
          transaction,
          buildOfflineTask: buildOfflineTask,
        );
      },
      triggerSynchronization: () {
        unawaited(ref.read(syncCoordinatorProvider.notifier).syncAfterSave());
      },
    );
    final transactionImportService = TransactionJsonImportService(
      importTransactions: transactionRepository.importTransactions,
    );

    return FinanceApp(
      enableAuth: true,
      enableStartupSync: true,
      enableDatabaseFeatures: true,
      notificationNavigationController: notificationNavigationController,
      transactionStreamFactory: transactionRepository.watchAllTransactions,
      saveTransaction: (transaction) async {
        final auth = ref.read(authSessionControllerProvider);
        await offlineFirstWriter.save(
          transaction,
          authenticatedUserId: auth.status == AuthStatus.authenticated
              ? auth.user?.id
              : null,
        );
      },
      transactionImportService: transactionImportService,
    );
  }
}
