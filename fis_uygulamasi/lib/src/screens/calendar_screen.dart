import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.transactions,
    this.initialFocusedDay,
    super.key,
  });

  final List<TransactionEntity> transactions;
  final DateTime? initialFocusedDay;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final initialDay = widget.initialFocusedDay ?? DateTime.now();
    _focusedDay = _dateOnly(initialDay);
    _selectedDay = _focusedDay;
  }

  List<TransactionEntity> get _focusedMonthTransactions => widget.transactions
      .where(
        (transaction) =>
            transaction.date.year == _focusedDay.year &&
            transaction.date.month == _focusedDay.month,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final transactionsByDay = _groupTransactionsByDay(widget.transactions);
    final monthTransactions = _focusedMonthTransactions;
    final selectedTransactions =
        transactionsByDay[_dateOnly(_selectedDay)] ?? const [];
    final incomeInMinor = _sumByType(monthTransactions, TransactionType.income);
    final expenseInMinor = _sumByType(
      monthTransactions,
      TransactionType.expense,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        _MonthlySummary(
          incomeInMinor: incomeInMinor,
          expenseInMinor: expenseInMinor,
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(10),
          child: TableCalendar<TransactionEntity>(
            locale: 'tr_TR',
            firstDay: DateTime(2000),
            lastDay: DateTime(DateTime.now().year + 5, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => transactionsByDay[_dateOnly(day)] ?? const [],
            availableCalendarFormats: const {CalendarFormat.month: 'Ay'},
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              markersMaxCount: 2,
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .25),
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders<TransactionEntity>(
              markerBuilder: (context, day, transactions) {
                if (transactions.isEmpty) return null;
                final hasIncome = transactions.any(
                  (item) => item.transactionType == TransactionType.income,
                );
                final hasExpense = transactions.any(
                  (item) => item.transactionType == TransactionType.expense,
                );
                return Positioned(
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasIncome)
                        const _TransactionMarker(color: AppColors.income),
                      if (hasIncome && hasExpense) const SizedBox(width: 3),
                      if (hasExpense)
                        const _TransactionMarker(color: AppColors.expense),
                    ],
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = _dateOnly(selectedDay);
                _focusedDay = _dateOnly(focusedDay);
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = _dateOnly(focusedDay);
                _selectedDay = _focusedDay;
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Seçili gün', style: Theme.of(context).textTheme.titleLarge),
            Text(
              DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDay),
              key: const Key('calendar_selected_date'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedTransactions.isEmpty)
          const AppCard(
            key: Key('calendar_empty_day'),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('Seçilen güne ait bir gelir veya gider yok.'),
              ),
            ),
          )
        else
          ...selectedTransactions.map(
            (transaction) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransactionTile(transaction: transaction),
            ),
          ),
      ],
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({
    required this.incomeInMinor,
    required this.expenseInMinor,
  });

  final int incomeInMinor;
  final int expenseInMinor;

  @override
  Widget build(BuildContext context) {
    final netInMinor = incomeInMinor - expenseInMinor;
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            key: const Key('calendar_monthly_income'),
            label: 'Gelir',
            amount: '+${_formatMoney(incomeInMinor)}',
            color: AppColors.income,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryItem(
            key: const Key('calendar_monthly_expense'),
            label: 'Gider',
            amount: '-${_formatMoney(expenseInMinor)}',
            color: AppColors.expense,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryItem(
            key: const Key('calendar_monthly_net'),
            label: 'Net',
            amount: _formatSignedMoney(netInMinor),
            color: netInMinor >= 0 ? AppColors.income : AppColors.expense,
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    super.key,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TransactionMarker extends StatelessWidget {
  const _TransactionMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.transactionType == TransactionType.income;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final categoryName = _transactionCategoryName(transaction);
    final title = transaction.merchantName?.trim().isNotEmpty == true
        ? transaction.merchantName!.trim()
        : isIncome
        ? 'Gelir'
        : categoryName;

    return AppCard(
      key: Key('calendar_transaction_${transaction.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(
              isIncome ? Icons.south_west : Icons.north_east,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${isIncome ? 'Gelir' : categoryName}'
                  ' • ${DateFormat('HH:mm', 'tr_TR').format(transaction.date)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${_formatMoney(transaction.amountInMinor)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

Map<DateTime, List<TransactionEntity>> _groupTransactionsByDay(
  List<TransactionEntity> transactions,
) {
  final result = <DateTime, List<TransactionEntity>>{};
  for (final transaction in transactions) {
    result.putIfAbsent(_dateOnly(transaction.date), () => []).add(transaction);
  }
  for (final dailyTransactions in result.values) {
    dailyTransactions.sort((a, b) => b.date.compareTo(a.date));
  }
  return result;
}

int _sumByType(List<TransactionEntity> transactions, TransactionType type) =>
    transactions
        .where((transaction) => transaction.transactionType == type)
        .fold(0, (total, transaction) => total + transaction.amountInMinor);

String _formatMoney(int amountInMinor) => NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
).format(amountInMinor / 100);

String _formatSignedMoney(int amountInMinor) {
  if (amountInMinor > 0) {
    return '+${_formatMoney(amountInMinor)}';
  } else if (amountInMinor < 0) {
    return '-${_formatMoney(amountInMinor.abs())}';
  } else {
    return _formatMoney(amountInMinor);
  }
}

String _categoryName(TransactionCategory category) => switch (category) {
  TransactionCategory.market => 'Market',
  TransactionCategory.ulasim => 'Ulaşım',
  TransactionCategory.fatura => 'Fatura',
  TransactionCategory.eglence => 'Eğlence',
  TransactionCategory.saglik => 'Sağlık',
  TransactionCategory.giyim => 'Giyim',
  TransactionCategory.diger => 'Diğer',
};

String _transactionCategoryName(TransactionEntity transaction) {
  final customName = transaction.categoryName?.trim();
  return customName?.isNotEmpty == true
      ? customName!
      : _categoryName(transaction.category);
}
