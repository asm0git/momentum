import 'package:flutter/material.dart';

import '../data_models.dart';
import 'days.dart';

class WeekWidget extends StatelessWidget {
  const WeekWidget({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.categories,
    required this.onDaySelected,
    this.compact = false,
  });

  final List<DateTime?> days;
  final DateTime selectedDay;
  final List<TaskCategory> categories;
  final ValueChanged<DateTime> onDaySelected;
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
              .map(
                (category) => TaskCategory(
                  title: category.title,
                  iconName: category.iconName,
                  items: category.items
                      .whereType<Task>()
                      .where((task) => _sameDay(task.date, date))
                      .toList(),
                ),
              )
              .where((category) => category.items.isNotEmpty)
              .toList();
    return DayWidget(
      date: date,
      categories: dayCategories,
      isWeekend: index == 0 || index == 6,
      isSelected: date != null && _sameDay(date, selectedDay),
      compact: compact,
      onSelected: date == null ? null : () => onDaySelected(date),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
