import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
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
import '../widgets/selector.dart' as app_selector;

// Timer screen with horizontally scrolling presets and the clock.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _scrollController = ScrollController();
  bool _selectionClearQueued = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
    final focusTasks = planner.selectableFocusTasks;
    final selectedTask = focusTimer.selectedTask;
    final selectedIsAvailable =
        selectedTask != null && focusTasks.any((task) => task == selectedTask);
    if (!focusTimer.isRunning && selectedTask != null && !selectedIsAvailable) {
      _queueSelectionClear(focusTimer);
    }
    final selectorTasks = [
      ...focusTasks,
      if (focusTimer.isRunning &&
          selectedTask != null &&
          !focusTasks.any((task) => task == selectedTask))
        selectedTask,
    ];
    final displaySelection = selectedIsAvailable || focusTimer.isRunning
        ? selectedTask
        : null;

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
              controller: _scrollController,
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
                    SizedBox(
                      width: double.infinity,
                      child: Clock(
                        onToggleRunning: () =>
                            _handleClockTap(planner, focusTimer),
                      ),
                    ),
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
                            Container(
                              height: AppSpacing.popupFieldHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.popup,
                                ),
                              ),
                              child: app_selector.Selector(
                                key: const ValueKey(
                                  'timer-focus-task-selector',
                                ),
                                options: [
                                  for (final task in selectorTasks)
                                    app_selector.SelectorOption(
                                      value: _selectionValue(task),
                                      label:
                                          '${task.taskTitle} (${task.categoryTitle})',
                                      iconName: task.categoryIcon,
                                    ),
                                ],
                                selectedValue: displaySelection == null
                                    ? null
                                    : _selectionValue(displaySelection),
                                placeholder: 'Select a task',
                                onChanged: focusTimer.isRunning
                                    ? null
                                    : (value) {
                                        final selection = focusTasks
                                            .where(
                                              (task) =>
                                                  _selectionValue(task) ==
                                                  value,
                                            )
                                            .firstOrNull;
                                        focusTimer.selectTask(selection);
                                      },
                                isExpanded: true,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Select a task to track focus time by category. '
                              "Without one, it's recorded as Unassigned in Insights.",
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.disabled),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Today, $dateLabel',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
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

  void _queueSelectionClear(FocusTimerState timer) {
    if (_selectionClearQueued) return;
    _selectionClearQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionClearQueued = false;
      if (mounted && !timer.isRunning) timer.selectTask(null);
    });
  }

  void _handleClockTap(PlannerState planner, FocusTimerState timer) {
    if (!timer.isRunning) {
      final selection = timer.selectedTask;
      final isAvailable =
          selection != null &&
          planner.selectableFocusTasks.any((task) => task == selection);
      if (selection != null && !isAvailable) timer.selectTask(null);
    }
    timer.toggleRunning();
  }

  String _selectionValue(FocusTaskSelection selection) =>
      '${selection.taskId}:${selection.categoryId}:${selection.taskTitle}:${selection.categoryTitle}';

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
