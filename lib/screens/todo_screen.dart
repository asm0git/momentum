import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../state/planner_state.dart';
import '../widgets/item_editor/add_item_popup.dart';
import '../widgets/navigation/bottom_navigation_bar.dart';
import '../widgets/planner/collapsible_category.dart';
import '../widgets/planner/item_actions.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/navigation/primary_app_bar.dart';

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
  Timer? _pastItemRefreshTimer;

  @override
  void initState() {
    super.initState();
    _pastItemRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pastItemRefreshTimer?.cancel();
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PillActionButton(
                    key: const ValueKey('todo-new-category'),
                    label: 'New category',
                    onPressed: _createCategory,
                    leadingIcon: Icons.add_circle_outline,
                    backgroundColor: AppColors.surface,
                    outlineColor: AppColors.surface,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.xxs),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final categoryId = category.id;
                    final importProvider = planner.calendarProviderForCategory(
                      category,
                    );
                    final items = categoryId == null
                        ? const <PlannerItem>[]
                        : planner.todoItemsForCategory(categoryId);
                    final pendingCount = items
                        .where(
                          (item) =>
                              item is Event ||
                              (item is Task && !item.isChecked),
                        )
                        .length;
                    return CollapsibleCategory(
                      key: categoryId == null
                          ? ValueKey(category.title)
                          : _categoryKeys.putIfAbsent(
                              categoryId,
                              GlobalKey.new,
                            ),
                      title: category.title,
                      pendingLabel: '$pendingCount pending',
                      iconName: planner.categoryDisplayIconName(category),
                      items: items,
                      showPendingCount: importProvider == null,
                      initiallyExpanded: categoryId == widget.initialCategoryId,
                      onDeleteCategory: categoryId == null
                          ? null
                          : () => confirmDeleteCategory(
                              context,
                              category,
                              categories,
                            ),
                    );
                  },
                ),
              ),
            ],
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

  Future<void> _createCategory() async {
    final category = await showNewCategoryDialog(context);
    if (category == null || !mounted) return;
    try {
      await context.read<PlannerState>().addCategory(category);
    } catch (error) {
      debugPrint('Could not create category: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create this category.')),
        );
      }
    }
  }
}
