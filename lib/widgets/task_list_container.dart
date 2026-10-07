import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';
import 'task_widget.dart';

// Surface container that renders a vertical list of task widgets.
class TaskListContainer extends StatelessWidget {
  static const _maxVisibleTasks = 4;

  const TaskListContainer({
    super.key,
    required this.items,
    this.categoryIconName,
    this.categoryIconForItem,
    this.maxVisibleItems = _maxVisibleTasks,
    this.appearanceType = TaskAppearanceType.withoutCategoryIcon,
    this.onChecked,
    this.onItemTap,
    this.onDelete,
  }) : assert(maxVisibleItems == null || maxVisibleItems >= 0);

  final List<PlannerItem> items;
  final String? categoryIconName;
  final String? Function(PlannerItem item)? categoryIconForItem;
  // Null displays the complete agenda; dashboard previews keep the default cap.
  final int? maxVisibleItems;
  final TaskAppearanceType appearanceType;
  final void Function(Task task, bool isChecked)? onChecked;
  final ValueChanged<PlannerItem>? onItemTap;
  final ValueChanged<PlannerItem>? onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visibleItems = [...items]..sort(_compareChronologically);
    final limitedItems = maxVisibleItems == null
        ? visibleItems
        : visibleItems.take(maxVisibleItems!).toList();
    final taskContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < limitedItems.length; index++)
          _buildTaskItem(context, index, textTheme, limitedItems),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: taskContent,
    );
  }

  int _compareChronologically(PlannerItem first, PlannerItem second) {
    final firstDateTime = _dateTimeFor(first);
    final secondDateTime = _dateTimeFor(second);
    return firstDateTime.compareTo(secondDateTime);
  }

  DateTime _dateTimeFor(PlannerItem item) {
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

  Widget _buildTaskItem(
    BuildContext context,
    int index,
    TextTheme textTheme,
    List<PlannerItem> visibleItems,
  ) {
    final item = visibleItems[index];
    final iconName = categoryIconForItem?.call(item) ?? categoryIconName;
    return Padding(
      padding: EdgeInsets.only(
        bottom: index == visibleItems.length - 1 ? 0 : AppSpacing.md,
      ),
      child: item is Task
          ? TaskWidget(
              task: item,
              categoryIconName: iconName,
              appearanceType: appearanceType,
              onChecked: onChecked == null
                  ? null
                  : (isChecked) => onChecked!(item, isChecked),
              onTap: onItemTap == null ? null : () => onItemTap!(item),
              onDelete: onDelete == null ? null : () => onDelete!(item),
            )
          : item is Event
          ? TaskWidget.event(
              event: item,
              categoryIconName:
                  appearanceType == TaskAppearanceType.withoutCategoryIcon
                  ? null
                  : iconName,
              onTap: onItemTap == null ? null : () => onItemTap!(item),
              onDelete: onDelete == null ? null : () => onDelete!(item),
            )
          : Text(item.title, style: textTheme.bodyMedium),
    );
  }
}
