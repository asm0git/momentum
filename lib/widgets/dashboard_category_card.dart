import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';

// Compact category preview used in the dashboard's horizontal category strip.
class DashboardCategoryCard extends StatelessWidget {
  const DashboardCategoryCard({super.key, required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final upcomingItem = _findUpcomingItem(DateTime.now());

    return SizedBox(
      width: AppSpacing.dashboardCategoryWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.popup),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeading(context, textTheme),
              const SizedBox(height: AppSpacing.xs),
              _buildUpcomingPreview(textTheme, upcomingItem),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeading(BuildContext context, TextTheme textTheme) {
    return Row(
      children: [
        Image.asset(
          'assets/img/categories/${category.iconName}.png',
          width: 20,
          height: 20,
          fit: BoxFit.contain,
          color: AppColors.primary,
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${category.pendingCount} pending',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        const Icon(Icons.chevron_right, color: AppColors.onSurface, size: 20),
      ],
    );
  }

  Widget _buildUpcomingPreview(TextTheme textTheme, _UpcomingItem? item) {
    if (item == null) {
      return Text(
        'No upcoming tasks',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelMedium?.copyWith(color: AppColors.onSurface),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(color: AppColors.onSurface),
        ),
        Text(
          _formatPreviewDate(item),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelMedium?.copyWith(color: AppColors.onSurface),
        ),
      ],
    );
  }

  _UpcomingItem? _findUpcomingItem(DateTime now) {
    final items =
        [
          for (final item in category.items)
            _UpcomingItem(item: item, scheduledDate: _scheduledDate(item)),
        ]..sort(
          (first, second) =>
              first.scheduledDate.compareTo(second.scheduledDate),
        );

    return items.where((item) => item.scheduledDate.isAfter(now)).firstOrNull ??
        (items.isEmpty ? null : items.first);
  }

  DateTime _scheduledDate(PlannerItem item) {
    final time = switch (item) {
      Task task => task.time,
      Event event => event.start,
      _ => const TimeOfDay(hour: 0, minute: 0),
    };

    return DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      time.hour,
      time.minute,
    );
  }

  String _formatPreviewDate(_UpcomingItem item) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final date = item.scheduledDate;
    final weekday = weekdays[date.weekday - 1];

    if (item.item is Event && (item.item as Event).allDay) {
      return weekday;
    }

    final time = TimeOfDay.fromDateTime(date);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$weekday, $hour:$minute $period';
  }
}

class _UpcomingItem {
  const _UpcomingItem({required this.item, required this.scheduledDate});

  final PlannerItem item;
  final DateTime scheduledDate;
}
