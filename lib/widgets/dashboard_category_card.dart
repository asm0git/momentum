import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';
import 'category_icon_picker.dart';

// Compact category preview used in the dashboard's horizontal category strip.
class DashboardCategoryCard extends StatelessWidget {
  const DashboardCategoryCard({
    super.key,
    required this.category,
    required this.nextItem,
    required this.onTap,
    this.iconName,
    this.showPendingCount = true,
    this.pendingCount,
  });

  final TaskCategory category;
  final PlannerItem? nextItem;
  final VoidCallback onTap;
  final String? iconName;
  final bool showPendingCount;
  final int? pendingCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: AppSpacing.dashboardCategoryWidth,
      height: AppSpacing.dashboardCategoryHeight,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.popup),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: AppSpacing.dashboardCategoryHeaderHeight,
                  child: _buildHeading(context, textTheme),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildUpcomingPreview(context, textTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeading(BuildContext context, TextTheme textTheme) {
    return Row(
      children: [
        if ((iconName ?? category.iconName).trim().isNotEmpty)
          CategoryIcon(
            iconName: iconName ?? category.iconName,
            size: 20,
            fit: BoxFit.contain,
          )
        else
          const SizedBox.square(dimension: 20),
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
              if (showPendingCount)
                Text(
                  '${pendingCount ?? category.pendingCount} pending',
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

  Widget _buildUpcomingPreview(BuildContext context, TextTheme textTheme) {
    final item = nextItem;
    return SizedBox(
      height: AppSpacing.dashboardCategoryPreviewHeight,
      child: item == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No upcoming items',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    _formatPreviewDate(context, item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatPreviewDate(BuildContext context, PlannerItem item) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final scheduledDate = item.date;
    final weekday = weekdays[scheduledDate.weekday - 1];
    if (item is Event && item.allDay) return weekday;
    final time = item is Task ? item.time : (item as Event).start;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$weekday, $hour:$minute $period';
  }
}
