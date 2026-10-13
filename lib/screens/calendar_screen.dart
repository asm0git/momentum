import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../calendar_view_mode.dart';
import '../navigation_destinations.dart';
import '../services/calendar_view_preferences.dart';
import '../state/planner_state.dart';
import '../widgets/navigation/bottom_navigation_bar.dart';
import '../widgets/calendar/calendar.dart';
import '../widgets/calendar/calendar_resize_handle.dart';
import '../widgets/planner/item_actions.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/navigation/primary_app_bar.dart';
import '../widgets/planner/task_list_container.dart';
import '../widgets/planner/task_widget.dart';

// Calendar screen content shown below the primary app bar.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = _dateOnly(DateTime.now());
  CalendarViewMode _calendarViewMode = CalendarViewMode.fullMonth;
  bool _calendarViewModeChanged = false;

  @override
  void initState() {
    super.initState();
    _restoreCalendarViewMode();
  }

  Future<void> _restoreCalendarViewMode() async {
    try {
      final savedMode = await CalendarViewPreferences.load();
      if (!mounted || _calendarViewModeChanged) return;
      setState(() => _calendarViewMode = savedMode);
    } catch (error) {
      // Keep the full-month view if the saved preference cannot be read.
      debugPrint('Could not restore the saved calendar view: $error');
    }
  }

  void _setCalendarViewMode(CalendarViewMode mode) {
    if (_calendarViewMode == mode) return;
    _calendarViewModeChanged = true;
    setState(() => _calendarViewMode = mode);
    unawaited(_saveCalendarViewMode(mode));
  }

  Future<void> _saveCalendarViewMode(CalendarViewMode mode) async {
    try {
      await CalendarViewPreferences.save(mode);
    } catch (error) {
      // Keep the changed view for this visit if storage is unavailable.
      debugPrint('Could not save the calendar view preference: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final categories = planner.categories;
    final categoryIconsById = <int, String>{
      for (final category in categories)
        if (category.id != null) category.id!: category.iconName,
    };
    final agendaIcons = {
      for (final item in planner.itemsForDate(_selectedDate))
        item: categoryIconsById[item.categoryId],
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('calendar-app-bar'),
        destination: AppDestination.calendar,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenEdgePadding,
                AppSpacing.md,
                AppSpacing.screenEdgePadding,
                AppSpacing.navigationDockHeight + AppSpacing.sectionGap,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: PillActionButton(
                      key: const ValueKey('calendar-add-calendars'),
                      label: 'Add calendars',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/calendars'),
                      leadingIcon: Icons.add_link,
                    ),
                  ),
                  AnimatedSize(
                    key: const ValueKey('calendar-animated-size'),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.hardEdge,
                    child: CalendarWidget(
                      items: planner.items,
                      viewMode: _calendarViewMode,
                      onDateSelected: (date) {
                        setState(() {
                          _selectedDate = _dateOnly(date);
                        });
                      },
                    ),
                  ),
                  CalendarResizeHandle(
                    mode: _calendarViewMode,
                    onModeChanged: _setCalendarViewMode,
                  ),
                  Text(
                    _sectionTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
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
                          showItemEditor(context, planner.seriesFor(item)),
                      onDelete: (item) => confirmDeleteItem(context, item),
                    ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: const ValueKey('calendar-navigation'),
              selectedIndex: AppDestination.calendar.index,
            ),
          ),
        ],
      ),
    );
  }

  String get _sectionTitle {
    final today = _dateOnly(DateTime.now());
    if (_sameDay(_selectedDate, today)) {
      return 'Today';
    }

    final monthName = const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][_selectedDate.month - 1];
    return '$monthName ${_selectedDate.day}';
  }
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
