import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/dashboard_category_card.dart';
import '../widgets/focus_preset.dart';
import '../widgets/primary_app_bar.dart';
import '../widgets/task_list_container.dart';
import '../widgets/task_widget.dart';

// Dashboard screen scaffold and its primary content area.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('dashboard-app-bar'),
        destination: AppDestination.dashboard,
      ),
      body: _ScreenBody(),
    );
  }
}

// Dashboard body behind the floating navigation group.
class _ScreenBody extends StatelessWidget {
  const _ScreenBody();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenEdgePadding,
            AppSpacing.md,
            AppSpacing.screenEdgePadding,
            AppSpacing.navigationDockHeight + AppSpacing.sectionGap,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateTimeSection(context),
              const SizedBox(height: AppSpacing.md),
              _buildCategoriesSection(context),
              const SizedBox(height: AppSpacing.md),
              _buildTodoSection(context),
              const SizedBox(height: AppSpacing.md),
              _buildFocusSection(context),
            ],
          ),
        ),
        Positioned.fill(
          child: FloatingNavigationGroup(
            key: ValueKey('dashboard-navigation'),
            selectedIndex: AppDestination.dashboard.index,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection(BuildContext context) {
    final now = DateTime.now();
    final nextItem = _findNextItem(createMockCategories(), now);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildDashboardComponent(
                _buildCurrentDateTime(context, now),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildDashboardComponent(
                _buildUpNext(context, nextItem),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDateTime(BuildContext context, DateTime now) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final time = _formatClock(TimeOfDay.fromDateTime(now));
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              weekdays[now.weekday - 1],
              style: textTheme.bodyMedium?.copyWith(color: AppColors.primary),
            ),
            Text(
              '${now.day} ${months[now.month - 1]}',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            alignment: Alignment.center,
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              maxLines: 1,
              softWrap: false,
              style: textTheme.displayLarge?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpNext(BuildContext context, _DashboardItem? nextItem) {
    final textTheme = Theme.of(context).textTheme;
    final textStyle = textTheme.bodyMedium?.copyWith(color: AppColors.primary);

    if (nextItem == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Up next:', style: textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              )),
          Text('No upcoming items', style: textStyle),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Up next:',
              style: textTheme.bodySmall?.copyWith(color: AppColors.primary),
            ),
            Text(
              '${_formatTime(nextItem.startTime)} - '
              '${_formatTime(nextItem.endTime)}',
              style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
            ),
            Row(
              children: [
                Image.asset(
                  'assets/img/categories/${nextItem.category.iconName}.png',
                  width: AppSpacing.navigationIconSize,
                  height: AppSpacing.navigationIconSize,
                  color: AppColors.primary,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    nextItem.item.title,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _DashboardItem? _findNextItem(List<TaskCategory> categories, DateTime now) {
    final items = [
      for (final category in categories)
        for (final item in category.items)
          _DashboardItem(
            item: item,
            category: category,
            startTime: _dateTimeFor(item),
            endTime: _endDateTimeFor(item),
          ),
    ]..sort((first, second) => first.startTime.compareTo(second.startTime));

    return items.where((item) => item.startTime.isAfter(now)).firstOrNull ??
        (items.isEmpty ? null : items.first);
  }

  DateTime _dateTimeFor(PlannerItem item) {
    final time = item is Task ? item.time : (item as Event).start;
    return DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      time.hour,
      time.minute,
    );
  }

  DateTime _endDateTimeFor(PlannerItem item) {
    if (item is Task) {
      return _dateTimeFor(item).add(item.estimatedDuration);
    }

    final event = item as Event;
    return DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      event.end.hour,
      event.end.minute,
    );
  }

  String _formatTime(DateTime time) {
    return _formatTimeOfDay(TimeOfDay.fromDateTime(time));
  }

  String _formatClock(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildSection(BuildContext context, [String? title]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Text(
            title,
            textAlign: TextAlign.left,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        Container(
          constraints: const BoxConstraints(minHeight: 120),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(BuildContext context) {
    final categories = createMockCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Categories',
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IntrinsicHeight(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < categories.length; index++) ...[
                  DashboardCategoryCard(
                    key: ValueKey('dashboard-category-${categories[index].title}'),
                    category: categories[index],
                  ),
                  if (index < categories.length - 1)
                    const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodoSection(BuildContext context) {
    final today = DateTime.now();
    final tasks = [
      for (final category in createMockCategories())
        ...category.items.whereType<Task>().where(
              (task) => _sameDay(task.date, today),
            ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'To-Do',
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        TaskListContainer(
          items: tasks,
          appearanceType: TaskAppearanceType.withoutCategoryIcon,
        ),
      ],
    );
  }

  Widget _buildFocusSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Focus',
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IntrinsicHeight(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FocusPreset(
                  workMinutes: 30,
                  breakMinutes: 5,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(width: AppSpacing.xs),
                FocusPreset(
                  workMinutes: 25,
                  breakMinutes: 2,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(width: AppSpacing.xs),
                FocusPreset(
                  workMinutes: 45,
                  breakMinutes: 10,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(width: AppSpacing.xs),
                FocusPreset(
                  workMinutes: 50,
                  breakMinutes: 10,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(width: AppSpacing.xs),
                FocusPreset(
                  workMinutes: 60,
                  breakMinutes: 15,
                  margin: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardComponent(Widget child) {
    return child;
  }
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _DashboardItem {
  const _DashboardItem({
    required this.item,
    required this.category,
    required this.startTime,
    required this.endTime,
  });

  final PlannerItem item;
  final TaskCategory category;
  final DateTime startTime;
  final DateTime endTime;
}
