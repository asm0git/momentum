import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import '../state/focus_timer_state.dart';
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
    final focusTimer = context.watch<FocusTimerState>();
    final today = DateTime.now();
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(today);
    final agendaIcons = {
      for (final item in planner.itemsForDate(today))
        item: planner.categories
            .where((category) => category.id == item.categoryId)
            .firstOrNull
            ?.iconName,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PrimaryAppBar(
        key: const ValueKey('timer-app-bar'),
        destination: AppDestination.timer,
        isBlurred: focusTimer.isRunning,
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
                    _blurWhenRunning(
                      focusTimer.isRunning,
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
                                  left:
                                      AppSpacing.screenEdgePadding +
                                      AppSpacing.xxs,
                                ),
                                child: Row(
                                  children: [
                                    _preset(focusTimer, 30, 5),
                                    _preset(focusTimer, 25, 2),
                                    _preset(focusTimer, 45, 10),
                                    _preset(focusTimer, 50, 10),
                                    _preset(focusTimer, 60, 15),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const SizedBox(width: double.infinity, child: Clock()),
                    const SizedBox(height: AppSpacing.md),
                    _blurWhenRunning(
                      focusTimer.isRunning,
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
                                categoryIconForItem: (item) =>
                                    agendaIcons[item],
                                maxVisibleItems: null,
                                appearanceType: TaskAppearanceType.checkable,
                                onChecked: (task, value) =>
                                    planner.setTaskCompleted(task, value),
                                onItemTap: (item) => showItemEditor(
                                  context,
                                  planner.seriesFor(item),
                                ),
                                onDelete: (item) =>
                                    confirmDeleteItem(context, item),
                              ),
                          ],
                        ),
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

  Widget _preset(FocusTimerState timer, int workMinutes, int breakMinutes) =>
      FocusPreset(
        workMinutes: workMinutes,
        breakMinutes: breakMinutes,
        margin: const EdgeInsets.all(AppSpacing.xxs),
        onPressed: () => timer.selectPreset(
          workMinutes: workMinutes,
          breakMinutes: breakMinutes,
        ),
      );

  Widget _blurWhenRunning(bool isRunning, Widget child) => isRunning
      ? ClipRect(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: child,
          ),
        )
      : child;
}
