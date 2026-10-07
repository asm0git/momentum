import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';

class DayWidget extends StatelessWidget {
  const DayWidget({
    super.key,
    required this.date,
    required this.isWeekend,
    required this.isSelected,
    this.categories = const [],
    this.onSelected,
    this.compact = false,
  });

  final DateTime? date;
  final bool isWeekend;
  final bool isSelected;
  final List<TaskCategory> categories;
  final VoidCallback? onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final day = date;
    final textTheme = Theme.of(context).textTheme;
    final isToday = day != null && _sameDay(day, DateTime.now());
    final circleSize = compact || isToday
        ? AppSpacing.calendarTodayCircleSize
        : AppSpacing.selectedIconContainerSize;
    final circleColor = isToday
        ? AppColors.secondary
        : isSelected
        ? AppColors.primary
        : AppColors.transparent;
    final textColor = isToday || isSelected
        ? AppColors.onPrimary
        : isWeekend
        ? AppColors.disabled
        : AppColors.onSurface;

    return InkWell(
      onTap: onSelected,
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
            if (!compact) Expanded(child: _buildCategoryGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 2.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return _CategoryCountPill(category: categories[index]);
      },
    );
  }
}

class _CategoryCountPill extends StatelessWidget {
  const _CategoryCountPill({required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const ShapeDecoration(
        color: AppColors.surface,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (category.iconName.isNotEmpty) ...[
            Image.asset(
              'assets/img/categories/${category.iconName}.png',
              width: 10,
              height: 10,
              color: AppColors.primary,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            '${category.items.whereType<Task>().length}',
            style: textTheme.labelSmall?.copyWith(color: AppColors.onSurface),
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
