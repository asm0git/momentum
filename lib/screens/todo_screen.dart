import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import '../state/planner_state.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/collapsible_category.dart';
import '../widgets/primary_app_bar.dart';

// To-do screen containing the expandable task categories.
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final categories = planner.categoriesWithUnassignedItems;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('todo-app-bar'),
        destination: AppDestination.todo,
      ),
      body: Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: categories.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.xxs),
            itemBuilder: (context, index) {
              final category = categories[index];
              final items = planner.items
                  .where((item) => item.categoryId == category.id)
                  .toList();
              return CollapsibleCategory(
                key: ValueKey(category.title),
                title: category.title,
                pendingLabel: '${category.pendingCount} pending',
                iconName: category.iconName,
                items: items,
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
