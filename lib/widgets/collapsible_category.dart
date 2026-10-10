import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../state/planner_state.dart';
import 'category_icon_picker.dart';
import 'item_actions.dart';
import 'swipe_to_reveal_delete.dart';
import 'task_list_container.dart';
import 'task_widget.dart';

// Expandable to-do category header and its reusable task list.
class CollapsibleCategory extends StatefulWidget {
  const CollapsibleCategory({
    super.key,
    required this.title,
    required this.pendingLabel,
    required this.iconName,
    required this.items,
    this.initiallyExpanded = false,
    this.onDeleteCategory,
  });

  final String title;
  final String pendingLabel;
  final String iconName;
  final List<PlannerItem> items;
  final bool initiallyExpanded;
  final VoidCallback? onDeleteCategory;

  @override
  State<CollapsibleCategory> createState() => _CollapsibleCategoryState();
}

class _CollapsibleCategoryState extends State<CollapsibleCategory> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded || _containsEvent(widget.items);
  }

  @override
  void didUpdateWidget(covariant CollapsibleCategory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_containsEvent(oldWidget.items) && _containsEvent(widget.items)) {
      _isExpanded = true;
    }
    if (!oldWidget.initiallyExpanded && widget.initiallyExpanded) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final header = InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      borderRadius: BorderRadius.circular(AppRadii.navigationItem),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              _isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
              color: AppColors.primary,
              size: AppSpacing.navigationIconSize,
            ),
            if (widget.iconName.isNotEmpty)
              CategoryIcon(
                iconName: widget.iconName,
                size: AppSpacing.navigationIconSize,
              ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  Text(
                    widget.pendingLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onDeleteCategory != null)
          SwipeToRevealDelete(
            key: ValueKey('category-swipe-${widget.title}'),
            deleteLabel: 'Delete category',
            backgroundColor: AppColors.background,
            deleteCircleScale: 0.72,
            onDelete: widget.onDeleteCategory!,
            child: header,
          )
        else
          header,
        if (_isExpanded) ...[
          TaskListContainer(
            items: widget.items,
            // Category lists must show and scroll through every item. The
            // four-item limit is only for compact dashboard previews.
            maxVisibleItems: null,
            categoryIconName: widget.iconName,
            appearanceType: TaskAppearanceType.withoutCategoryIcon,
            onChecked: (task, value) =>
                context.read<PlannerState>().setTaskCompleted(task, value),
            onItemTap: (item) => showItemEditor(
              context,
              context.read<PlannerState>().seriesFor(item),
            ),
            onDelete: (item) => confirmDeleteItem(context, item),
          ),
        ],
      ],
    );
  }

  bool _containsEvent(List<PlannerItem> items) =>
      items.any((item) => item is Event);
}
