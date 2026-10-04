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
    this.appearanceType = TaskAppearanceType.withoutCategoryIcon,
    this.onChecked,
  });

  final List<PlannerItem> items;
  final String? categoryIconName;
  final TaskAppearanceType appearanceType;
  final void Function(Task task, bool isChecked)? onChecked;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isScrollable = items.length > 4;
    final bodyMediumSize = textTheme.bodyMedium?.fontSize ?? 16;
    final bodySmallSize = textTheme.bodySmall?.fontSize ?? 12;
    final estimatedTaskHeight =
        (bodyMediumSize * 1.15) + 2 + (bodySmallSize * 1.2);
    final maxTaskContentHeight = (estimatedTaskHeight * _maxVisibleTasks) +
        (AppSpacing.md * (_maxVisibleTasks - 1));
    final taskContent = isScrollable
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxTaskContentHeight,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _buildTaskItem(context, index, textTheme),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < items.length; index++)
                _buildTaskItem(context, index, textTheme),
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

  Widget _buildTaskItem(
    BuildContext context,
    int index,
    TextTheme textTheme,
  ) {
    final item = items[index];
    return Padding(
      padding: EdgeInsets.only(
        bottom: index == items.length - 1 ? 0 : AppSpacing.md,
      ),
      child: item is Task
          ? TaskWidget(
              task: item,
              categoryIconName: categoryIconName,
              appearanceType: appearanceType,
              onChecked: onChecked == null
                  ? null
                  : (isChecked) => onChecked!(item, isChecked),
            )
          : Text(item.title, style: textTheme.bodyMedium),
    );
  }
}
