import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';
import 'task_widget.dart';

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
  late List<PlannerItem> _items = List.of(widget.items);

  @override
  void didUpdateWidget(covariant CollapsibleCategory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _items = List.of(widget.items);
    }
  }

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
                const SizedBox(width: AppSpacing.xs),
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
                        '${_items.whereType<Task>().where((task) => !task.isChecked).length} pending',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
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
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _items.length - 1 ? 0 : 12,
                  ),
                  child: item is Task
                      ? TaskWidget(
                          task: item,
                          categoryIconName: widget.iconName,
                          onChecked: (isChecked) => _checkTask(item, isChecked),
                        )
                      : Text(item.title, style: textTheme.bodyMedium),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _checkTask(Task task, bool isChecked) {
    setState(() {
      task.isChecked = isChecked;
      if (isChecked) {
        _items
          ..remove(task)
          ..add(task);
      } else {
        _items
          ..remove(task)
          ..insert(0, task);
      }
    });
  }
}
