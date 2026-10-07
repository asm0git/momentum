import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../state/planner_state.dart';
import 'item_actions.dart';
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
  });

  final String title;
  final String pendingLabel;
  final String iconName;
  final List<PlannerItem> items;

  @override
  State<CollapsibleCategory> createState() => _CollapsibleCategoryState();
}

class _CollapsibleCategoryState extends State<CollapsibleCategory> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
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
                // const SizedBox(width: AppSpacing.xs),
                if (widget.iconName.isNotEmpty)
                  Image.asset(
                    'assets/img/categories/${widget.iconName}.png',
                    width: AppSpacing.navigationIconSize,
                    height: AppSpacing.navigationIconSize,
                    color: AppColors.primary,
                    colorBlendMode: BlendMode.srcIn,
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
        ),
        if (_isExpanded) ...[
          TaskListContainer(
            items: widget.items,
            categoryIconName: widget.iconName,
            appearanceType: TaskAppearanceType.withoutCategoryIcon,
            onChecked: (task, value) =>
                context.read<PlannerState>().setTaskCompleted(task, value),
            onItemTap: (item) => showItemEditor(context, item),
            onDelete: (item) => confirmDeleteItem(context, item),
          ),
        ],
      ],
    );
  }
}
