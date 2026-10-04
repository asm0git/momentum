import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/clock.dart';
import '../widgets/focus_preset.dart';
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
  late final List<TaskCategory> _categories = createMockCategories();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(today);

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
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.screenEdgePadding +
                                      AppSpacing.xxs,
                                ),
                                child: const Row(
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
                      const SizedBox(
                        width: double.infinity,
                        child: Clock(),
                      ),
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
                            for (final category in _categories)
                              if (_todayTasks(category, today).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: TaskListContainer(
                                    items: _todayTasks(category, today),
                                    categoryIconName: category.iconName,
                                    appearanceType:
                                        TaskAppearanceType.checkable,
                                    onChecked: _checkTask,
                                  ),
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
              key: ValueKey('timer-navigation'),
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

  List<PlannerItem> _todayTasks(TaskCategory category, DateTime today) {
    return category.items
        .where(
          (item) => item is Task && _isSameDay(item.date, today),
        )
        .toList();
  }

  void _checkTask(Task task, bool isChecked) {
    setState(() {
      task.isChecked = isChecked;
    });
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
