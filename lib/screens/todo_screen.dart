import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../state/planner_state.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/collapsible_category.dart';
import '../widgets/primary_app_bar.dart';

// To-do screen containing the expandable task categories.
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key, this.initialCategoryId});

  final int? initialCategoryId;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _scrollController = ScrollController();
  final _categoryKeys = <int, GlobalKey>{};
  bool _scrollScheduled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scrollScheduled || widget.initialCategoryId == null) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _categoryKeys[widget.initialCategoryId]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.2,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final categories = planner.categories;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('todo-app-bar'),
        destination: AppDestination.todo,
      ),
      body: Stack(
        children: [
          ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: categories.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.xxs),
            itemBuilder: (context, index) {
              final category = categories[index];
              final categoryId = category.id;
              final items = categoryId == null
                  ? const <PlannerItem>[]
                  : planner.itemsForCategory(categoryId);
              final pendingCount = items
                  .where(
                    (item) =>
                        item is Event || (item is Task && !item.isChecked),
                  )
                  .length;
              return CollapsibleCategory(
                key: categoryId == null
                    ? ValueKey(category.title)
                    : _categoryKeys.putIfAbsent(categoryId, GlobalKey.new),
                title: category.title,
                pendingLabel: '$pendingCount pending',
                iconName: category.iconName,
                items: items,
                initiallyExpanded: categoryId == widget.initialCategoryId,
              );
            },
          ),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: const ValueKey('todo-navigation'),
              selectedIndex: AppDestination.todo.index,
            ),
          ),
        ],
      ),
    );
  }
}
