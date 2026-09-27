import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';

enum TaskAppearanceType { checkable, compact, completed }

class TaskWidget extends StatelessWidget {
  const TaskWidget({
    super.key,
    required this.task,
    this.appearanceType = TaskAppearanceType.checkable,
    this.onChecked,
  });

  final Task task;
  final TaskAppearanceType appearanceType;
  final ValueChanged<bool>? onChecked;

  @override
  Widget build(BuildContext context) {
    switch (appearanceType) {
      case TaskAppearanceType.checkable:
        return _buildCheckableTask(context);
      case TaskAppearanceType.compact:
      case TaskAppearanceType.completed:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCheckableTask(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = task.isChecked ? AppColors.disabled : AppColors.onSurface;
    final titleStyle = textTheme.bodyMedium?.copyWith(
      color: textColor,
      decoration: task.isChecked ? TextDecoration.lineThrough : null,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: task.isChecked,
          onChanged: (value) => onChecked?.call(value ?? false),
          activeColor: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: titleStyle),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDateTime(task.date, task.time),
                      style: textTheme.bodySmall?.copyWith(color: textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.check_circle,
                    size: AppSpacing.sm,
                    color: textColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
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
    return '$weekday, $hour:$minute $period';
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
}