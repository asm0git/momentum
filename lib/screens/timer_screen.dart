import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data/pomodoro_preset.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../state/focus_timer_state.dart';
import '../state/planner_state.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/clock.dart';
import '../widgets/estimated_duration_picker.dart';
import '../widgets/focus_preset.dart';
import '../widgets/item_actions.dart';
import '../widgets/primary_app_bar.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/task_list_container.dart';
import '../widgets/task_widget.dart';
import '../widgets/selector.dart' as app_selector;
import '../widgets/blurred_dialog.dart';

const _builtInPomodoroPresets = <PomodoroPreset>[
  PomodoroPreset(workMinutes: 30, breakMinutes: 5),
  PomodoroPreset(workMinutes: 25, breakMinutes: 2),
  PomodoroPreset(workMinutes: 45, breakMinutes: 10),
  PomodoroPreset(workMinutes: 60, breakMinutes: 15),
];

// Timer screen with horizontally scrolling presets and the clock.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _scrollController = ScrollController();
  bool _selectionClearQueued = false;
  bool _defaultSelectionQueued = false;

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
    final focusItems = planner.selectableFocusItems;
    final selectedTask = focusTimer.selectedTask;
    final selectedUnassigned = selectedTask == FocusTaskSelection.unassigned;
    final selectedIsAvailable =
        selectedUnassigned ||
        (selectedTask != null &&
            focusItems.any((item) => item == selectedTask));
    if (!focusTimer.isRunning && selectedTask != null && !selectedIsAvailable) {
      _queueSelectionClear(focusTimer);
    }
    final defaultSelection = planner.defaultFocusSelection;
    if (!focusTimer.isRunning &&
        selectedTask == null &&
        defaultSelection != null) {
      _queueDefaultSelection(focusTimer, defaultSelection);
    }
    final selectorItems = [
      FocusTaskSelection.unassigned,
      ...focusItems,
      if (focusTimer.isRunning &&
          selectedTask != null &&
          !selectedUnassigned &&
          !focusItems.any((item) => item == selectedTask))
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
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Presets',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  PillActionButton(
                                    key: const ValueKey('timer-add-preset'),
                                    label: 'Add preset',
                                    leadingIcon: Icons.add_circle_outline,
                                    backgroundColor: AppColors.surface,
                                    outlineColor: AppColors.surface,
                                    onPressed: () =>
                                        _showAddPresetDialog(focusTimer),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left:
                                      AppSpacing.screenEdgePadding +
                                      AppSpacing.xxs,
                                  right:
                                      AppSpacing.screenEdgePadding +
                                      AppSpacing.xxs,
                                ),
                                child: Row(
                                  children: [
                                    for (final preset
                                        in focusTimer.customPresets)
                                      _preset(
                                        focusTimer,
                                        preset.workMinutes,
                                        preset.breakMinutes,
                                      ),
                                    for (final preset
                                        in _builtInPomodoroPresets)
                                      _preset(
                                        focusTimer,
                                        preset.workMinutes,
                                        preset.breakMinutes,
                                      ),
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
                                  for (final item in selectorItems)
                                    app_selector.SelectorOption(
                                      value: _selectionValue(item),
                                      label:
                                          '${item.taskTitle} (${item.categoryTitle})${item.isEvent ? ' · Event' : ''}',
                                      iconName: item.categoryIcon,
                                    ),
                                ],
                                selectedValue: displaySelection == null
                                    ? null
                                    : _selectionValue(displaySelection),
                                placeholder: 'Select a task or event',
                                onChanged: focusTimer.isRunning
                                    ? null
                                    : (value) {
                                        final selection =
                                            value ==
                                                _selectionValue(
                                                  FocusTaskSelection.unassigned,
                                                )
                                            ? FocusTaskSelection.unassigned
                                            : focusItems
                                                  .where(
                                                    (item) =>
                                                        _selectionValue(item) ==
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
                              'Select a task or event to track focus time by '
                              'category. '
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

  Future<void> _showAddPresetDialog(FocusTimerState timer) async {
    var workDuration = const Duration(minutes: 25);
    var restDuration = const Duration(minutes: 5);

    final preset = await showBlurredDialog<PomodoroPreset>(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = (MediaQuery.sizeOf(dialogContext).width - 32)
            .clamp(280.0, 400.0)
            .toDouble();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSave =
                workDuration.inMinutes > 0 && restDuration.inMinutes > 0;
            final textStyle = Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal);

            return Dialog(
              insetPadding: const EdgeInsets.all(AppSpacing.md),
              backgroundColor: AppColors.background,
              surfaceTintColor: AppColors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.popup),
              ),
              child: SizedBox(
                width: dialogWidth,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add preset',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      EstimatedDurationPicker(
                        label: 'Work minutes',
                        value: workDuration,
                        onChanged: (value) =>
                            setDialogState(() => workDuration = value),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      EstimatedDurationPicker(
                        label: 'Rest minutes',
                        value: restDuration,
                        onChanged: (value) =>
                            setDialogState(() => restDuration = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                textStyle: textStyle,
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                textStyle: textStyle,
                              ),
                              onPressed: canSave
                                  ? () => Navigator.pop(
                                      context,
                                      PomodoroPreset(
                                        workMinutes: workDuration.inMinutes,
                                        breakMinutes: restDuration.inMinutes,
                                      ),
                                    )
                                  : null,
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || preset == null) return;

    if (_builtInPomodoroPresets.contains(preset)) {
      _showPresetMessage('That preset already exists.');
      return;
    }

    final result = await timer.addCustomPreset(preset);
    if (!mounted) return;
    switch (result) {
      case CustomPresetSaveResult.saved:
        break;
      case CustomPresetSaveResult.duplicate:
        _showPresetMessage('That preset already exists.');
      case CustomPresetSaveResult.invalid:
        _showPresetMessage('Work and rest times must be at least 5 minutes.');
      case CustomPresetSaveResult.notPersisted:
        _showPresetMessage(
          'Preset added for this session, but could not be saved.',
        );
    }
  }

  void _showPresetMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _queueSelectionClear(FocusTimerState timer) {
    if (_selectionClearQueued) return;
    _selectionClearQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionClearQueued = false;
      if (mounted && !timer.isRunning) timer.selectTask(null);
    });
  }

  void _queueDefaultSelection(
    FocusTimerState timer,
    FocusTaskSelection selection,
  ) {
    if (_defaultSelectionQueued) return;
    _defaultSelectionQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _defaultSelectionQueued = false;
      if (mounted && !timer.isRunning && timer.selectedTask == null) {
        timer.selectTask(selection);
      }
    });
  }

  void _handleClockTap(PlannerState planner, FocusTimerState timer) {
    if (!timer.isRunning) {
      final selection = timer.selectedTask;
      final isAvailable =
          selection == FocusTaskSelection.unassigned ||
          (selection != null &&
              planner.selectableFocusItems.any((item) => item == selection));
      if (selection != null && !isAvailable) timer.selectTask(null);
    }
    timer.toggleRunning();
  }

  String _selectionValue(FocusTaskSelection selection) =>
      '${selection.isEvent ? 'event' : 'task'}:${selection.taskId}:${selection.categoryId}:${selection.taskTitle}:${selection.categoryTitle}';

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
