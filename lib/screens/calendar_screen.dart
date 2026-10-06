import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/calendar.dart';
import '../widgets/primary_app_bar.dart';
import '../widgets/task_list_container.dart';
import '../widgets/task_widget.dart';

// Calendar screen content shown below the primary app bar.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final List<TaskCategory> _categories = createMockCategories();
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final agendaIcons = {
      for (final category in _categories)
        for (final item in _tasksForDate(category)) item: category.iconName,
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
                  CalendarWidget(
                    categories: _categories,
                    onDateSelected: (date) {
                      setState(() {
                        _selectedDate = _dateOnly(date);
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _sectionTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (agendaIcons.isNotEmpty)
                    TaskListContainer(
                      items: agendaIcons.keys.toList(),
                      categoryIconForItem: (item) => agendaIcons[item],
                      maxVisibleItems: null,
                      appearanceType: TaskAppearanceType.checkable,
                      onChecked: _checkTask,
                    ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: ValueKey('calendar-navigation'),
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

  List<PlannerItem> _tasksForDate(TaskCategory category) {
    return category.items
        .where((item) => _sameDay(item.date, _selectedDate))
        .toList();
  }

  void _checkTask(Task task, bool isChecked) {
    setState(() {
      task.isChecked = isChecked;
    });
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
