import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import '../state/planner_state.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/calendar.dart';
import '../widgets/item_actions.dart';
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
  DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final categories = planner.categories;
    final agendaIcons = {
      for (final item in planner.itemsForDate(_selectedDate))
        item: categories
            .where((category) => category.id == item.categoryId)
            .firstOrNull
            ?.iconName,
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
                    child: TextButton.icon(
                      key: const ValueKey('calendar-add-calendars'),
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/calendars'),
                      icon: const Icon(Icons.add_link),
                      label: Text(
                        'Add calendars',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ),
                  CalendarWidget(
                    categories: categories,
                    onDateSelected: (date) {
                      setState(() {
                        _selectedDate = _dateOnly(date);
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
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
