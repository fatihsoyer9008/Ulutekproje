import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';

import '../screens/calendar_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/expense_screen.dart';
import '../screens/savings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/transactions_screen.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({
    required this.transactionStream,
    this.saveTransaction,
    this.scanReceipt,
    super.key,
  });

  final Stream<List<TransactionEntity>> transactionStream;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _index = 0;

  late Stream<List<TransactionEntity>> _transactionStream;
  StreamController<List<TransactionEntity>>? _transactionController;
  StreamSubscription<List<TransactionEntity>>? _transactionSubscription;
  List<TransactionEntity>? _latestTransactions;

  static const _titles = [
    'Günaydın, Deniz',
    'İstatistikler',
    'Kumbaralarım',
    'Finans Takvimi',
    'Hesap Hareketleri',
  ];

  @override
  void initState() {
    super.initState();
    _connectTransactionStream(widget.transactionStream);
  }

  @override
  void didUpdateWidget(covariant FinanceHome oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactionStream != widget.transactionStream) {
      _connectTransactionStream(widget.transactionStream);
    }
  }

  void _connectTransactionStream(
    Stream<List<TransactionEntity>> source,
  ) {
    _transactionSubscription?.cancel();
    _transactionController?.close();

    _latestTransactions = null;

    late StreamController<List<TransactionEntity>> controller;

    controller = StreamController<List<TransactionEntity>>.broadcast(
      sync: true,
      onListen: () {
        final latest = _latestTransactions;

        if (latest != null && !controller.isClosed) {
          controller.add(latest);
        }
      },
    );

    _transactionController = controller;
    _transactionStream = controller.stream;

    _transactionSubscription = source.listen(
      (transactions) {
        _latestTransactions = transactions;

        if (!controller.isClosed) {
          controller.add(transactions);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _transactionController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        transactionStream: _transactionStream,
        saveTransaction: widget.saveTransaction,
        scanReceipt: widget.scanReceipt,
      ),
      StatisticsScreen(transactionStream: _transactionStream),
      const SavingsScreen(),
      const CalendarScreen(),
      TransactionsScreen(transactionStream: _transactionStream),
    ];

    return AppShell(
      title: _titles[_index],
      currentIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      body: IndexedStack(index: _index, children: screens),
    );
  }
}