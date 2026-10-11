import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../calendar_view_mode.dart';
import '../data_models.dart';
import 'week.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({
    super.key,
    this.categories = const [],
    this.onDateSelected,
    this.initialDate,
    this.minimumDate,
    this.compact = false,
    this.viewMode = CalendarViewMode.fullMonth,
  });

  final List<TaskCategory> categories;
  final ValueChanged<DateTime>? onDateSelected;
  final DateTime? initialDate;
  final DateTime? minimumDate;
  final bool compact;
  final CalendarViewMode viewMode;

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  static const _monthNames = [
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
  ];
  static const _weekdayNames = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  late DateTime _selectedDay = _initialSelection();
  late DateTime _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month);
  double _horizontalSwipeDistance = 0;
  double _verticalSwipeDistance = 0;

  DateTime _initialSelection() {
    final selected = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    final minimum = widget.minimumDate == null
        ? null
        : DateUtils.dateOnly(widget.minimumDate!);
    return minimum != null && selected.isBefore(minimum) ? minimum : selected;
  }

  void _changeMonth(int offset) {
    final nextMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + offset,
    );
    final minimum = widget.minimumDate == null
        ? null
        : DateUtils.dateOnly(widget.minimumDate!);
    if (minimum != null &&
        nextMonth.isBefore(DateTime(minimum.year, minimum.month))) {
      return;
    }

    late DateTime selectedDate;
    setState(() {
      _visibleMonth = nextMonth;
      final lastDay = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        0,
      ).day;
      selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        _selectedDay.day.clamp(1, lastDay),
      );
      if (minimum != null && selectedDate.isBefore(minimum)) {
        selectedDate = minimum;
      }
      _selectedDay = selectedDate;
    });
    widget.onDateSelected?.call(selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.compact ? CalendarViewMode.fullMonth : widget.viewMode;
    final visibleWeeks = _visibleWeeks(mode);
    final weeks = [
      for (final days in visibleWeeks)
        WeekWidget(
          days: days,
          selectedDay: _selectedDay,
          categories: widget.compact ? const [] : widget.categories,
          minimumDate: widget.minimumDate,
          compact: widget.compact,
          showTaskIndicators: !widget.compact && mode.showTaskIndicators,
          onDaySelected: _selectDay,
        ),
    ];
    final minimum = widget.minimumDate == null
        ? null
        : DateUtils.dateOnly(widget.minimumDate!);
    final previousMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    final canGoToPreviousMonth =
        minimum == null ||
        !previousMonth.isBefore(DateTime(minimum.year, minimum.month));

    Widget weekGrid = Column(
      children: [
        for (final week in weeks)
          SizedBox(
            height: widget.compact
                ? AppSpacing.selectedIconContainerSize - AppSpacing.xs
                : AppSpacing.calendarDayHeight,
            child: week,
          ),
      ],
    );
    if (!widget.compact && mode != CalendarViewMode.fullMonth) {
      weekGrid = GestureDetector(
        key: const ValueKey('calendar-week-swipe-navigation'),
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _horizontalSwipeDistance = 0,
        onHorizontalDragUpdate: (details) =>
            _horizontalSwipeDistance += details.delta.dx,
        onHorizontalDragEnd: (_) {
          _finishWeekSwipe(_horizontalSwipeDistance);
          _horizontalSwipeDistance = 0;
        },
        onHorizontalDragCancel: () => _horizontalSwipeDistance = 0,
        onVerticalDragStart: (_) => _verticalSwipeDistance = 0,
        onVerticalDragUpdate: (details) =>
            _verticalSwipeDistance += details.delta.dy,
        onVerticalDragEnd: (_) {
          _finishWeekSwipe(_verticalSwipeDistance);
          _verticalSwipeDistance = 0;
        },
        onVerticalDragCancel: () => _verticalSwipeDistance = 0,
        child: weekGrid,
      );
    }

    return Column(
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _CalendarHeader(
          monthName: _monthNames[_visibleMonth.month - 1],
          year: _visibleMonth.year,
          onPreviousMonth: canGoToPreviousMonth ? () => _changeMonth(-1) : null,
          onNextMonth: () => _changeMonth(1),
        ),
        SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.md),
        Row(
          children: [
            for (var index = 0; index < _weekdayNames.length; index++)
              Expanded(
                child: Container(
                  height: AppSpacing.lg,
                  alignment: Alignment.center,
                  child: Text(
                    _weekdayNames[index],
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        weekGrid,
      ],
    );
  }

  List<List<DateTime?>> _visibleWeeks(CalendarViewMode mode) {
    final visibleWeekCount = mode.visibleWeekCount;
    if (visibleWeekCount != null) {
      final firstWeekDay = _startOfWeek(_selectedDay);
      return List.generate(
        visibleWeekCount,
        (weekIndex) => List.generate(
          7,
          (dayIndex) =>
              firstWeekDay.add(Duration(days: weekIndex * 7 + dayIndex)),
        ),
      );
    }

    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlankDays = firstDay.weekday % 7;
    final weekCount = calendarMonthWeekCount(_visibleMonth);
    return List.generate(
      weekCount,
      (weekIndex) => List.generate(7, (dayIndex) {
        final dayNumber = weekIndex * 7 + dayIndex - leadingBlankDays + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) return null;
        return DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
      }),
    );
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      if (!widget.compact &&
          widget.viewMode != CalendarViewMode.fullMonth &&
          (day.year != _visibleMonth.year ||
              day.month != _visibleMonth.month)) {
        _visibleMonth = DateTime(day.year, day.month);
      }
    });
    widget.onDateSelected?.call(day);
  }

  void _shiftWeek(int direction) {
    final nextSelectedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day + direction * 7,
    );
    final minimum = widget.minimumDate == null
        ? null
        : DateUtils.dateOnly(widget.minimumDate!);
    if (minimum != null && nextSelectedDay.isBefore(minimum)) return;

    setState(() {
      _selectedDay = nextSelectedDay;
      _visibleMonth = DateTime(nextSelectedDay.year, nextSelectedDay.month);
    });
    widget.onDateSelected?.call(nextSelectedDay);
  }

  void _finishWeekSwipe(double distance) {
    if (distance.abs() < kTouchSlop) return;
    // Left/up moves forward through the weeks; right/down moves backward.
    _shiftWeek(distance < 0 ? 1 : -1);
  }

  static DateTime _startOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday % 7));
  }
}

int calendarMonthWeekCount(DateTime date) {
  final firstDay = DateTime(date.year, date.month);
  final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
  final leadingBlankDays = firstDay.weekday % 7;
  return ((leadingBlankDays + daysInMonth) / 7).ceil();
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.monthName,
    required this.year,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final String monthName;
  final int year;
  final VoidCallback? onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        _CalendarControl(
          icon: Icons.chevron_left,
          tooltip: 'Previous month',
          onPressed: onPreviousMonth,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                monthName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.primary),
              ),
              Text(
                '$year',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        _CalendarControl(
          icon: Icons.chevron_right,
          tooltip: 'Next month',
          onPressed: onNextMonth,
        ),
      ],
    );
  }
}

class _CalendarControl extends StatelessWidget {
  const _CalendarControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.calendarMonthControlSize,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: AppSpacing.calendarMonthChevronSize,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          backgroundColor: AppColors.background,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.calendarBorder),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
