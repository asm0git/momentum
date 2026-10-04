import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';

enum TaskAppearanceType {
  checkable,
  withoutCategoryIcon,
  compact,
  calendarCellMini,
  completed,
}

// Individual task row with checkbox, category icon, and task metadata.
class TaskWidget extends StatelessWidget {
  const TaskWidget({
    super.key,
    required this.task,
    this.categoryIconName,
    this.appearanceType = TaskAppearanceType.checkable,
    this.onChecked,
  });

  final Task task;
  final String? categoryIconName;
  final TaskAppearanceType appearanceType;
  final ValueChanged<bool>? onChecked;

  @override
  Widget build(BuildContext context) {
    switch (appearanceType) {
      case TaskAppearanceType.checkable:
        return _buildCheckableTask(context, includeCategoryIcon: true);
      case TaskAppearanceType.withoutCategoryIcon:
        return _buildCheckableTask(context, includeCategoryIcon: false);
      case TaskAppearanceType.compact:
      case TaskAppearanceType.calendarCellMini:
        return _buildCalendarCellMini(context);
      case TaskAppearanceType.completed:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCalendarCellMini(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = task.isChecked ? AppColors.disabled : AppColors.onSurface;

    return Text(
      task.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textTheme.labelSmall?.copyWith(
        color: textColor,
        decoration: task.isChecked ? TextDecoration.lineThrough : null,
      ),
    );
  }

  Widget _buildCheckableTask(
    BuildContext context, {
    required bool includeCategoryIcon,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = task.isChecked ? AppColors.disabled : AppColors.onSurface;
    final titleStyle = textTheme.bodyMedium?.copyWith(
      color: textColor,
      decoration: task.isChecked ? TextDecoration.lineThrough : null,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: AppSpacing.navigationIconSize,
          child: Center(
            child: Checkbox(
              value: task.isChecked,
              onChanged: (value) => onChecked?.call(value ?? false),
              activeColor: AppColors.primary,
              shape: const CircleBorder(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
          ),
        ),
        if (includeCategoryIcon && categoryIconName != null) ...[
          const SizedBox(width: 8),
          Image.asset(
            'assets/img/categories/$categoryIconName.png',
            width: AppSpacing.navigationIconSize,
            height: AppSpacing.navigationIconSize,
            color: AppColors.primary,
            colorBlendMode: BlendMode.srcIn,
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: titleStyle),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _formatDateTime(task.date, task.time),
                    style: textTheme.bodySmall?.copyWith(color: textColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.check_circle,
                    size: AppSpacing.sm * 1.5,
                    color: textColor,
                  ),
                  const SizedBox(width: AppSpacing.xs / 4),
                  Text(
                    _formatDuration(task.estimatedDuration),
                    style: textTheme.bodySmall?.copyWith(color: textColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date, TimeOfDay time) {
    final weekday = _weekdays[date.weekday - 1];
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final formattedTime = '$hour:$minute $period';
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final daysFromToday = taskDate.difference(todayDate).inDays;

    if (daysFromToday == 0) {
      return 'Today, $formattedTime';
    }
    if (daysFromToday > 0 && daysFromToday <= 7) {
      return '$weekday, $formattedTime';
    }

    final month = _months[date.month - 1];
    return '$weekday, ${date.day} $month, $formattedTime';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0 && duration.inMinutes % 60 == 0) {
      return '~${duration.inHours} hours';
    }
    return '~${duration.inMinutes} minutes';
  }

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
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
}
