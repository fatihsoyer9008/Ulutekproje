import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/database/database_providers.dart';
import 'features/auth/presentation/controllers/auth_session_controller.dart';
import 'features/notifications/notification_navigation_controller.dart';
import 'features/notifications/notification_providers.dart';
import 'features/notifications/daily_budget_reminder_service.dart';
import 'features/notifications/notification_preferences.dart';
import 'src/app/app_router.dart';
import 'src/app/finance_app.dart';
import 'src/screens/expense_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  final notificationNavigationController = NotificationNavigationController();

  final reminderService = DailyBudgetReminderService(
    onNotificationTap: notificationNavigationController.handlePayload,
  );

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await reminderService.initialize();

    final launchPayload = await reminderService.getLaunchPayload();

    notificationNavigationController.handlePayload(launchPayload);

    await _restoreDailyReminder(reminderService);
  }

  final isar = await IsarService.getInstance();



runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        dailyBudgetReminderServiceProvider.overrideWithValue(reminderService),
      ],
      child: _AppBootstrap(
        notificationNavigationController: notificationNavigationController,
      ),
    ),
  );
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

    return FinanceApp(
      enableAuth: true,
      notificationNavigationController: notificationNavigationController,
      transactionStream: transactionRepository.watchAllTransactions(),
      saveTransaction: transactionRepository.addTransaction,
    );
  }
}

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({
    super.key,
    this.enableAuth = false,
    this.notificationNavigationController,
    this.transactionStream = const Stream<List<TransactionEntity>>.empty(),
    this.saveTransaction,
    this.scanReceipt,
  });

  final bool enableAuth;
  final NotificationNavigationController? notificationNavigationController;
  final Stream<List<TransactionEntity>> transactionStream;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;

  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();

    if (widget.enableAuth) {
      _router = createAppRouter(
        ref: ref,
        transactionStream: widget.transactionStream,
        saveTransaction: widget.saveTransaction,
        scanReceipt: widget.scanReceipt,
      );

      final router = _router;

      if (router != null) {
        widget.notificationNavigationController?.attachNavigator(router.go);
      }
    }
  }

  @override
  void dispose() {
    widget.notificationNavigationController?.detachNavigator();

    _router?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enableAuth) {
      final authStatus = ref.watch(authSessionControllerProvider).status;

      final navigationReady =
          authStatus == AuthStatus.authenticated ||
          authStatus == AuthStatus.guest;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        widget.notificationNavigationController?.setNavigationReady(
          navigationReady,
        );
      });
    }
    final router = _router;
    if (widget.enableAuth && router != null) {
      return MaterialApp.router(
        title: 'Cüzdanım',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      );
    }

    // Eski widget/integration testlerinin ve bağımsız UI kullanımının
    // geriye dönük uyumluluğu korunur.
    return MaterialApp(
      title: 'Cüzdanım',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: StreamBuilder<List<TransactionEntity>>(
        stream: widget.transactionStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('İşlemler yüklenemedi.')),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return FinanceHome(
            transactions: snapshot.requireData,
            saveTransaction: widget.saveTransaction,
            scanReceipt: widget.scanReceipt,
          );
        },
      ),
    );
  }
}
