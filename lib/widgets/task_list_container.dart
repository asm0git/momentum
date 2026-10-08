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
        if (items.isEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'No tasks.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
            ),
          ),
        ],
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
    final Widget itemWidget;
    if (item is Task) {
      itemWidget = TaskWidget(
        task: item,
        categoryIconName: iconName,
        appearanceType: appearanceType,
        onChecked: onChecked == null
            ? null
            : (isChecked) => onChecked!(item, isChecked),
        onTap: onItemTap == null ? null : () => onItemTap!(item),
      );
    } else if (item is Event) {
      itemWidget = TaskWidget.event(
        event: item,
        categoryIconName:
            appearanceType == TaskAppearanceType.withoutCategoryIcon
            ? null
            : iconName,
        onTap: onItemTap == null ? null : () => onItemTap!(item),
      );
    } else {
      itemWidget = Text(item.title, style: textTheme.bodyMedium);
    }

    final supportsSwipeDelete = item is Task || item is Event;
    final row = onDelete != null && supportsSwipeDelete
        ? _SwipeToRevealDelete(
            onDelete: () => onDelete!(item),
            child: itemWidget,
          )
        : itemWidget;

    return Padding(
      padding: EdgeInsets.only(
        bottom: index == visibleItems.length - 1 ? 0 : AppSpacing.md,
      ),
      child: row,
    );
  }
}

class _SwipeToRevealDelete extends StatefulWidget {
  const _SwipeToRevealDelete({required this.child, required this.onDelete});

  static const actionWidth = 72.0;

  final Widget child;
  final VoidCallback onDelete;

  @override
  State<_SwipeToRevealDelete> createState() => _SwipeToRevealDeleteState();
}

class _SwipeToRevealDeleteState extends State<_SwipeToRevealDelete>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _controller.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _controller.value =
        (_controller.value -
                details.delta.dx / _SwipeToRevealDelete.actionWidth)
            .clamp(0.0, 1.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity < -300 ||
        (velocity.abs() <= 300 && _controller.value >= 0.35)) {
      _controller.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      _controller.animateBack(0, curve: Curves.easeInCubic);
    }
  }

  void _onHorizontalDragCancel() {
    _controller.animateBack(0, curve: Curves.easeInCubic);
  }

  void _delete() {
    _controller.animateBack(0, curve: Curves.easeInCubic);
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;
        final row = SizedBox(
          width: rowWidth,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: AppColors.surface),
              ),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: _SwipeToRevealDelete.actionWidth,
                      child: Semantics(
                        button: true,
                        label: 'Delete item',
                        onTap: _delete,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _delete,
                          child: Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final diameter =
                                    constraints.maxHeight <
                                        _SwipeToRevealDelete.actionWidth
                                    ? constraints.maxHeight
                                    : _SwipeToRevealDelete.actionWidth;
                                return SizedBox.square(
                                  dimension: diameter,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Tooltip(
                                        message: 'Delete item',
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                child: SizedBox(
                  width: rowWidth,
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: widget.child,
                  ),
                ),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      -_SwipeToRevealDelete.actionWidth * _controller.value,
                      0,
                    ),
                    child: IgnorePointer(
                      ignoring: _controller.value > 0.02,
                      child: child,
                    ),
                  );
                },
              ),
            ],
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onHorizontalDragCancel: _onHorizontalDragCancel,
          child: ClipRect(child: row),
        );
      },
    );
  }
}
