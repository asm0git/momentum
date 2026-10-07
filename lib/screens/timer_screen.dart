import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../state/planner_state.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/clock.dart';
import '../widgets/focus_preset.dart';
import '../widgets/item_actions.dart';
import '../widgets/primary_app_bar.dart';
import '../widgets/task_list_container.dart';
import '../widgets/task_widget.dart';

// Timer screen with horizontally scrolling presets and the clock.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final today = DateTime.now();
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(today);
    final agendaIcons = {
      for (final item in planner.items.whereType<Task>().where(
        (task) => _isSameDay(task.date, today),
      ))
        item: planner.categories
            .where((category) => category.id == item.categoryId)
            .firstOrNull
            ?.iconName,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('timer-app-bar'),
        destination: AppDestination.timer,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenEdgePadding,
                            ),
                            child: Text(
                              'Presets',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: EdgeInsets.only(
                                left:
                                    AppSpacing.screenEdgePadding +
                                    AppSpacing.xxs,
                              ),
                              child: Row(
                                children: [
                                  FocusPreset(
                                    workMinutes: 30,
                                    breakMinutes: 5,
                                    margin: EdgeInsets.all(AppSpacing.xxs),
                                  ),
                                  FocusPreset(
                                    workMinutes: 25,
                                    breakMinutes: 2,
                                    margin: EdgeInsets.all(AppSpacing.xxs),
                                  ),
                                  FocusPreset(
                                    workMinutes: 45,
                                    breakMinutes: 10,
                                    margin: EdgeInsets.all(AppSpacing.xxs),
                                  ),
                                  FocusPreset(
                                    workMinutes: 50,
                                    breakMinutes: 10,
                                    margin: EdgeInsets.all(AppSpacing.xxs),
                                  ),
                                  FocusPreset(
                                    workMinutes: 60,
                                    breakMinutes: 15,
                                    margin: EdgeInsets.all(AppSpacing.xxs),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const SizedBox(width: double.infinity, child: Clock()),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenEdgePadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Today, $dateLabel',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (agendaIcons.isNotEmpty)
                            TaskListContainer(
                              items: agendaIcons.keys.toList(),
                              categoryIconForItem: (item) => agendaIcons[item],
                              maxVisibleItems: null,
                              appearanceType: TaskAppearanceType.checkable,
                              onChecked: (task, value) =>
                                  planner.setTaskCompleted(task, value),
                              onItemTap: (item) =>
                                  showItemEditor(context, item),
                              onDelete: (item) =>
                                  confirmDeleteItem(context, item),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: const ValueKey('timer-navigation'),
              selectedIndex: AppDestination.timer.index,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xs,
            child: Center(
              child: Container(
                width: 135,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.onSurface,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
