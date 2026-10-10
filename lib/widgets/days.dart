import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';
import 'category_icon_picker.dart';

class DayWidget extends StatelessWidget {
  const DayWidget({
    super.key,
    required this.date,
    required this.isSelected,
    this.minimumDate,
    this.categories = const [],
    this.onSelected,
    this.compact = false,
    this.showTaskIndicators = true,
  });

  final DateTime? date;
  final bool isSelected;
  final DateTime? minimumDate;
  final List<TaskCategory> categories;
  final VoidCallback? onSelected;
  final bool compact;
  final bool showTaskIndicators;

  @override
  Widget build(BuildContext context) {
    final day = date;
    final textTheme = Theme.of(context).textTheme;
    final isToday = day != null && _sameDay(day, DateTime.now());
    final isBeforeMinimumDate =
        day != null &&
        minimumDate != null &&
        DateUtils.dateOnly(day).isBefore(DateUtils.dateOnly(minimumDate!));
    final circleSize = compact || isToday
        ? AppSpacing.calendarTodayCircleSize
        : AppSpacing.selectedIconContainerSize;
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
            if (!compact)
              Expanded(
                child: AnimatedOpacity(
                  opacity: showTaskIndicators ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: !showTaskIndicators,
                    child: _buildCategoryGrid(),
                  ),
                ),
              ),
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
            CategoryIcon(iconName: category.iconName, size: 10),
            const SizedBox(width: 2),
          ],
          Text(
            '${category.items.length}',
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
