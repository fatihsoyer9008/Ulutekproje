import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_session_controller.dart';
import '../../features/backup/data/transaction_json_import_service.dart';
import '../../features/notifications/notification_navigation_controller.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../screens/expense_screen.dart';
import 'app_router.dart';
import 'finance_home.dart';

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({
    super.key,
    this.enableAuth = false,
    this.notificationNavigationController,
    this.transactionStream = const Stream<List<TransactionEntity>>.empty(),
    this.transactionStreamFactory,
    this.saveTransaction,
    this.scanReceipt,
    this.parseReceipt,
    this.transactionImportService,
  });

  final bool enableAuth;
  final NotificationNavigationController? notificationNavigationController;
  final Stream<List<TransactionEntity>> transactionStream;
  final Stream<List<TransactionEntity>> Function()? transactionStreamFactory;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler? parseReceipt;
  final TransactionJsonImportService? transactionImportService;

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
        transactionStreamFactory:
            widget.transactionStreamFactory ?? () => widget.transactionStream,
        saveTransaction: widget.saveTransaction,
        scanReceipt: widget.scanReceipt,
        transactionImportService: widget.transactionImportService,
      );

      final router = _router;

      if (router != null) {
        widget.notificationNavigationController?.attachNavigator((location) {
          unawaited(router.push<void>(location));
        });
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
    final themeMode = widget.enableAuth
        ? ref.watch(appThemeModeProvider)
        : ThemeMode.light;
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
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
      );
    }

    return MaterialApp(
      title: 'Cüzdanım',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
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
            parseReceipt: widget.parseReceipt,
          );
        },
      ),
    );
  }
}
