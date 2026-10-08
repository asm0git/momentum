import 'package:flutter/material.dart';

import '../data_models.dart';
import '../data/recurrence.dart';
import 'days.dart';

class WeekWidget extends StatelessWidget {
  const WeekWidget({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.categories,
    required this.onDaySelected,
    this.minimumDate,
    this.compact = false,
  });

  final List<DateTime?> days;
  final DateTime selectedDay;
  final List<TaskCategory> categories;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? minimumDate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(child: _buildDay(index)),
      ],
    );
  }

  Widget _buildDay(int index) {
    final date = days[index];
    final dayCategories = date == null
        ? const <TaskCategory>[]
        : categories
              .map((category) {
                final items = <PlannerItem>[];
                for (final item in category.items) {
                  for (final occurrenceDate in recurrenceDatesInRange(
                    item,
                    from: date,
                    through: date,
                  )) {
                    items.add(occurrenceForDate(item, occurrenceDate));
                  }
                }
                return TaskCategory(
                  title: category.title,
                  iconName: category.iconName,
                  items: items,
                );
              })
              .where((category) => category.items.isNotEmpty)
              .toList();
    return DayWidget(
      date: date,
      categories: dayCategories,
      minimumDate: minimumDate,
      isSelected: date != null && _sameDay(date, selectedDay),
      compact: compact,
      onSelected: date == null || _isBeforeMinimum(date)
          ? null
          : () => onDaySelected(date),
    );
  }

  bool _isBeforeMinimum(DateTime date) {
    final minimum = minimumDate;
    return minimum != null &&
        DateUtils.dateOnly(date).isBefore(DateUtils.dateOnly(minimum));
  }
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
