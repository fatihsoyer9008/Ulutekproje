import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_session_controller.dart';
import '../../features/notifications/notification_navigation_controller.dart';
import '../screens/expense_screen.dart';
import 'app_router.dart';
import 'finance_home.dart';

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
