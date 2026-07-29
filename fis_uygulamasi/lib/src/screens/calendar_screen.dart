import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/ui_models.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.eventsByDay = const {}});

  final Map<DateTime, List<CalendarEvent>> eventsByDay;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime focused = DateTime.now();
  DateTime? selected;
  List<CalendarEvent> events(DateTime d) =>
      widget.eventsByDay[DateTime(d.year, d.month, d.day)] ?? const [];

  List<MapEntry<DateTime, CalendarEvent>> get upcomingEvents {
    final entries =
        widget.eventsByDay.entries
            .expand(
              (entry) => entry.value.map((event) => MapEntry(entry.key, event)),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
    children: [
      AppCard(
        padding: const EdgeInsets.all(10),
        child: TableCalendar<CalendarEvent>(
          locale: 'tr_TR',
          firstDay: DateTime(2025),
          lastDay: DateTime(2028),
          focusedDay: focused,
          selectedDayPredicate: (d) => isSameDay(selected, d),
          eventLoader: events,
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
            markerDecoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .25),
              shape: BoxShape.circle,
            ),
          ),
          onDaySelected: (d, f) {
            setState(() {
              selected = d;
              focused = f;
            });
            _showDay(d, events(d));
          },
          onPageChanged: (d) => focused = d,
        ),
      ),
      const SizedBox(height: 24),
      Text('Yaklaşanlar', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (upcomingEvents.isEmpty)
        const AppCard(
          child: Center(
            child: Text('Yaklaşan bir finansal hareket bulunmuyor.'),
          ),
        ),
      ...upcomingEvents.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EventTile(
            date: entry.key,
            title: entry.value.title,
            amount: entry.value.amount,
          ),
        ),
      ),
    ],
  );
  void _showDay(DateTime day, List<CalendarEvent> items) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    MaterialLocalizations.of(context).formatMediumDate(day),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton.filled(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    tooltip: 'Etkinlik ekle',
                  ),
                ],
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Bugüne ait bir hareket bulunmuyor.'),
                ),
              ...items.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        (e.isIncome ? AppColors.income : AppColors.expense)
                            .withValues(alpha: .12),
                    child: Icon(
                      e.isIncome ? Icons.south_west : Icons.north_east,
                    ),
                  ),
                  title: Text(e.title),
                  trailing: Text(
                    e.amount,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: e.isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.date,
    required this.title,
    required this.amount,
  });

  final DateTime date;
  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                date.day.toString().padLeft(2, '0'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                DateFormat.MMM(
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(date).toUpperCase(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
