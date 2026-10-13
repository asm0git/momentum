import 'package:flutter/material.dart';

import '../../app_theme.dart';

class DayWidget extends StatelessWidget {
  const DayWidget({
    super.key,
    required this.date,
    required this.isSelected,
    this.minimumDate,
    this.onSelected,
    this.compact = false,
  });

  final DateTime? date;
  final bool isSelected;
  final DateTime? minimumDate;
  final VoidCallback? onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final day = date;
    final textTheme = Theme.of(context).textTheme;
    final isToday = day != null && _sameDay(day, DateTime.now());
    final isBeforeMinimumDate =
        day != null &&
        minimumDate != null &&
        DateUtils.dateOnly(day).isBefore(DateUtils.dateOnly(minimumDate!));
    final circleSize = AppSpacing.calendarTodayCircleSize;
    final circleColor = isBeforeMinimumDate
        ? AppColors.transparent
        : isToday
        ? AppColors.secondary
        : isSelected
        ? AppColors.primary
        : AppColors.transparent;
    final textColor = isBeforeMinimumDate
        ? AppColors.disabled
        : isToday || isSelected
        ? AppColors.onPrimary
        : AppColors.onSurface;

    return InkWell(
      onTap: isBeforeMinimumDate ? null : onSelected,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.calendarBorder)),
        ),
        padding: EdgeInsets.only(top: compact ? 0 : AppSpacing.xxs),
        child: Column(
          children: [
            SizedBox(
              height: compact
                  ? AppSpacing.selectedIconContainerSize - AppSpacing.xs - 1
                  : AppSpacing.selectedIconContainerSize,
              child: day == null
                  ? null
                  : Center(
                      child: Container(
                        width: circleSize,
                        height: circleSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: circleColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${day.day}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
