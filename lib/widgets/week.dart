import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'days.dart';

class WeekWidget extends StatelessWidget {
  const WeekWidget({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final List<DateTime?> days;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.calendarBorder),
      ),
      child: Row(
        children: [
          for (var index = 0; index < 7; index++)
            Expanded(
              child: DayWidget(
                date: days[index],
                isWeekend: index == 0 || index == 6,
                isSelected: days[index] != null &&
                  selectedDay != null &&
                  _sameDay(days[index]!, selectedDay!),
                onSelected: days[index] == null
                    ? null
                    : () => onDaySelected(days[index]!),
              ),
            ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
