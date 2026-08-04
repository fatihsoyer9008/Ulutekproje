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
    final entries = widget.eventsByDay.entries
        .expand(
          (entry) => entry.value.map((event) => MapEntry(entry.key, event)),
        )
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final isCurrentMonth =
        focused.year == now.year && focused.month == now.month;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // 1. TAKVİM KARTI
        AppCard(
          padding: const EdgeInsets.all(12),
          child: TableCalendar<CalendarEvent>(
            locale: 'tr_TR',
            firstDay: DateTime(2025),
            lastDay: DateTime(2028),
            focusedDay: focused,
            selectedDayPredicate: (d) => isSameDay(selected, d),
            eventLoader: events,
            availableCalendarFormats: const {CalendarFormat.month: 'Ay'},

            // Başlık Alanı
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isCurrentMonth
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.6),
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: scheme.onSurface,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface,
              ),
            ),

            // Hafta Günleri (Paz, Pzt...)
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isCurrentMonth
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              weekendStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isCurrentMonth
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),

            // Gün Sitilleri
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,

              defaultTextStyle: TextStyle(
                color: isCurrentMonth
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.45),
                fontWeight: isCurrentMonth ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
              weekendTextStyle: TextStyle(
                color: isCurrentMonth
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.45),
                fontWeight: isCurrentMonth ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),

              // BUGÜN STİLİ (Zarif Şeffaf Mint + Yeşil Halka Çerçeve)
              todayDecoration: BoxDecoration(
                color: AppColors.mint.withValues(alpha: 0.30),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.income,
                  width: 1.5,
                ),
              ),
              todayTextStyle: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),

              // SEÇİLİ GÜN STİLİ (İçi Dolu Dolgun Mint)
              selectedDecoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),

              // Etkinlik Noktaları
              markerDecoration: const BoxDecoration(
                color: AppColors.expense,
                shape: BoxShape.circle,
              ),
              markerSize: 5,
            ),

            onDaySelected: (d, f) {
              setState(() {
                selected = d;
                focused = f;
              });
              _showDay(d, events(d));
            },
            onPageChanged: (d) {
              setState(() {
                focused = d;
              });
            },
          ),
        ),
        const SizedBox(height: 24),

        // 2. YAKLAŞANLAR BAŞLIĞI
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            'Yaklaşanlar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
          ),
        ),

        // 3. BOŞ DURUM VEYA ETKİNLİK LİSTESİ
        if (upcomingEvents.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 42,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 12),
                Text(
                  'Yaklaşan bir finansal hareket bulunmuyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ...upcomingEvents.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EventTile(
                date: entry.key,
                title: entry.value.title,
                amount: entry.value.amount,
                isIncome: entry.value.isIncome,
              ),
            ),
          ),
      ],
    );
  }

  // TÜRKÇE TARİH DÜZELTMELİ BOTTOM SHEET
  void _showDay(DateTime day, List<CalendarEvent> items) =>
      showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          
          // "4 Ağustos 2026, Salı" Formatı
          final formattedDate =
              DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(day);

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                      ),
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mint,
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      tooltip: 'Etkinlik ekle',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Bugüne ait bir hareket bulunmuyor.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  ...items.map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: (e.isIncome
                                ? AppColors.income
                                : AppColors.expense)
                            .withValues(alpha: .20),
                        child: Icon(
                          e.isIncome
                              ? Icons.trending_up_rounded
                              : Icons.payments_outlined,
                          size: 20,
                          color: e.isIncome
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                      title: Text(
                        e.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        e.amount,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: e.isIncome
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.date,
    required this.title,
    required this.amount,
    this.isIncome = false,
  });

  final DateTime date;
  final String title;
  final String amount;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badgeBg = isIncome
        ? AppColors.mint.withValues(alpha: 0.35)
        : AppColors.lavender.withValues(alpha: 0.40);

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat.MMM('tr_TR').format(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}