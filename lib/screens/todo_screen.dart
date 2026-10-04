import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
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
  late final List<TaskCategory> _categories = createMockCategories();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('todo-app-bar'),
        destination: AppDestination.todo,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final category in _categories)
                CollapsibleCategory(
                  key: ValueKey(category.title),
                  title: category.title,
                  pendingLabel: '${category.pendingCount} pending',
                  iconName: category.iconName,
                  items: category.items,
                ),
            ],
          ),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: ValueKey('todo-navigation'),
              selectedIndex: AppDestination.todo.index,
            ),
          ),
        ],
      ),
    );
  }
}
