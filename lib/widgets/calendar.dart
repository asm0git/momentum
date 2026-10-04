import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'week.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  late DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      final lastDay = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        0,
      ).day;
      if (_selectedDay != null) {
        _selectedDay = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          _selectedDay!.day.clamp(1, lastDay),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlankDays = firstDay.weekday % 7;
    final weekCount = ((leadingBlankDays + daysInMonth) / 7).ceil();
    final weeks = List.generate(
      weekCount,
      (weekIndex) => WeekWidget(
        days: List.generate(7, (dayIndex) {
          final dayNumber = weekIndex * 7 + dayIndex - leadingBlankDays + 1;
          if (dayNumber < 1 || dayNumber > daysInMonth) {
            return null;
          }
          return DateTime(
            _visibleMonth.year,
            _visibleMonth.month,
            dayNumber,
          );
        }),
        selectedDay: _selectedDay,
        onDaySelected: (day) {
          setState(() {
            _selectedDay = day;
          });
        },
      ),
    );

    return Column(
      children: [
        _CalendarHeader(
          monthName: _monthNames[_visibleMonth.month - 1],
          year: _visibleMonth.year,
          onPreviousMonth: () => _changeMonth(-1),
          onNextMonth: () => _changeMonth(1),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (var index = 0; index < _weekdayNames.length; index++)
              Expanded(
                child: Container(
                  height: AppSpacing.lg,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.calendarBorder),
                  ),
                  child: Text(
                    _weekdayNames[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: index == 0 || index == 6
                              ? AppColors.disabled
                              : AppColors.onSurface,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: Column(
            children: [
              for (final week in weeks)
                SizedBox(height: AppSpacing.calendarDayHeight, child: week),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.monthName,
    required this.year,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String monthName;
  final int year;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.calendarBorder),
      ),
      child: Row(
        children: [
          _CalendarControl(
            icon: Icons.chevron_left,
            tooltip: 'Previous month',
            onPressed: onPreviousMonth,
          ),
          Expanded(
            child: Container(
              height: AppSpacing.lg * 2,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: AppColors.calendarBorder),
                ),
              ),
              child: Text(
                '$monthName $year',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          _CalendarControl(
            icon: Icons.chevron_right,
            tooltip: 'Next month',
            onPressed: onNextMonth,
          ),
        ],
      ),
    );
  }
}

class _CalendarControl extends StatelessWidget {
  const _CalendarControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.lg * 2,
      height: AppSpacing.lg * 2,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
      ),
    );
  }
}
