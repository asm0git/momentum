import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';

enum TaskAppearanceType { checkable, compact, completed }

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
      height: 1.15,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: task.isChecked,
            onChanged: (value) => onChecked?.call(value ?? false),
            activeColor: AppColors.primary,
            shape: const CircleBorder(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (categoryIconName != null) ...[
          const SizedBox(width: 12),
          Image.asset(
            'assets/img/categories/$categoryIconName.png',
            width: AppSpacing.navigationIconSize,
            height: AppSpacing.navigationIconSize,
            color: AppColors.primary,
            colorBlendMode: BlendMode.srcIn,
          ),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: titleStyle),
              const SizedBox(height: 2),
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
