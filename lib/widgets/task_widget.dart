import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';

enum TaskAppearanceType {
  checkable,
  withoutCategoryIcon,
  compact,
  calendarCellMini,
  completed,
  event,
}

// Shared task/event row with status icon, category icon, and scheduling details.
class TaskWidget extends StatelessWidget {
  const TaskWidget({
    super.key,
    required this.task,
    this.categoryIconName,
    this.appearanceType = TaskAppearanceType.checkable,
    this.onChecked,
    this.onTap,
  }) : assert(appearanceType != TaskAppearanceType.event),
       event = null;

  const TaskWidget.event({
    super.key,
    required this.event,
    this.categoryIconName,
    this.onTap,
  }) : task = null,
       appearanceType = TaskAppearanceType.event,
       onChecked = null;

  final Task? task;
  final Event? event;
  final String? categoryIconName;
  final TaskAppearanceType appearanceType;
  final ValueChanged<bool>? onChecked;
  final VoidCallback? onTap;

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
      case TaskAppearanceType.event:
        return _buildEvent(context, event!);
    }
  }

  Widget _buildCalendarCellMini(BuildContext context) {
    final task = this.task!;
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
    final task = this.task!;
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
        if (includeCategoryIcon && categoryIconName?.isNotEmpty == true) ...[
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
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _formatDateTime(task.date, task.time),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: textColor,
                        ),
                      ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(color: textColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvent(BuildContext context, Event event) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = event.allDay ? AppColors.secondary : AppColors.onSurface;
    final schedule = event.allDay
        ? '${_formatDate(event.date)}, All day'
        : '${_formatDate(event.date)}, ${_formatTime(event.start)} - '
              '${_formatTime(event.end)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: AppSpacing.navigationIconSize,
          child: Center(
            child: Image.asset(
              'assets/img/categories/all-day.png',
              width: 18,
              height: 18,
              fit: BoxFit.contain,
              color: textColor,
              colorBlendMode: BlendMode.srcIn,
              semanticLabel: event.allDay ? 'All-day event' : 'Event',
            ),
          ),
        ),
        if (categoryIconName?.isNotEmpty == true) ...[
          const SizedBox(width: AppSpacing.xs),
          Image.asset(
            'assets/img/categories/$categoryIconName.png',
            width: AppSpacing.navigationIconSize,
            height: AppSpacing.navigationIconSize,
            color: textColor,
            colorBlendMode: BlendMode.srcIn,
          ),
        ],
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: textTheme.bodyMedium?.copyWith(color: textColor),
                ),
                Text(
                  schedule,
                  style: textTheme.labelMedium?.copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date, TimeOfDay time) =>
      '${_formatDate(date)}, ${_formatTime(time)}';

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    final daysFromToday = taskDate.difference(todayDate).inDays;

    if (daysFromToday == 0) {
      return 'Today';
    }
    if (daysFromToday > 0 && daysFromToday <= 7) {
      return weekday;
    }

    final month = _months[date.month - 1];
    return '$weekday, ${date.day} $month';
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
