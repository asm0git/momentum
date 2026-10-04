import 'package:flutter/material.dart';

import '../app_theme.dart';

class DayWidget extends StatelessWidget {
  const DayWidget({
    super.key,
    required this.date,
    required this.isWeekend,
    required this.isSelected,
    this.onSelected,
  });

  final DateTime? date;
  final bool isWeekend;
  final bool isSelected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final isToday = date != null && _sameDay(date!, DateTime.now());
    final textColor = isSelected || isToday
      ? AppColors.onPrimary
      : isWeekend
        ? AppColors.disabled
        : AppColors.onSurface;
    final fillColor = isSelected
      ? AppColors.primary
      : isToday
        ? AppColors.secondary
        : AppColors.transparent;

    return InkWell(
      onTap: onSelected,
      child: Container(
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.calendarBorder),
          ),
        ),
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Column(
          children: [
            SizedBox(
              height: AppSpacing.selectedIconContainerSize,
              child: date == null
                  ? null
                  : Center(
                      child: Container(
                        width: AppSpacing.selectedIconContainerSize,
                        height: AppSpacing.selectedIconContainerSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: fillColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${date!.day}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ),
                    ),
            ),
            const Expanded(
              child: SizedBox(),
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
