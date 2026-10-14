import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/recurrence.dart';
import '../../data_models.dart';
import 'days.dart';
import 'week_layout.dart';

const _maxVisibleCalendarBars = 3;
const _calendarBarHeight = 16.0;
const _calendarBarGap = 2.0;
const _calendarBarExtent = _calendarBarHeight + _calendarBarGap;
const _calendarOverflowHeight = 16.0;
const _calendarHeaderHeight =
    AppSpacing.selectedIconContainerSize + AppSpacing.xxs;

/// Height needed for a date header, three item bars, and an overflow row.
const calendarItemsWeekHeight =
    _calendarHeaderHeight +
    _maxVisibleCalendarBars * _calendarBarExtent +
    _calendarOverflowHeight +
    AppSpacing.xxs;

/// Height of compact rows, sized to keep the six calendar views ordered.
const calendarDateOnlyWeekHeight = 64.0;

class WeekWidget extends StatelessWidget {
  const WeekWidget({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.items,
    required this.onDaySelected,
    this.minimumDate,
    this.compact = false,
    this.showTaskIndicators = true,
  });

  final List<DateTime?> days;
  final DateTime selectedDay;
  final List<PlannerItem> items;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? minimumDate;
  final bool compact;
  final bool showTaskIndicators;

  @override
  Widget build(BuildContext context) {
    final validDates = <(int, DateTime)>[
      for (var index = 0; index < days.length; index++)
        if (days[index] case final date?) (index, dateOnly(date)),
    ];
    final firstDate = validDates.isEmpty ? null : validDates.first.$2;
    final lastDate = validDates.isEmpty ? null : validDates.last.$2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = constraints.maxWidth / 7;
        final placements = compact || firstDate == null || lastDate == null
            ? const <CalendarWeekPlacement>[]
            : placeCalendarWeekItems(
                items: items,
                firstDate: firstDate,
                lastDate: lastDate,
                visibleDates: validDates,
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                for (var index = 0; index < 7; index++)
                  Expanded(child: _buildDay(index)),
              ],
            ),
            if (!compact)
              Positioned.fill(
                child: AnimatedOpacity(
                  key: const ValueKey('calendar-week-items-opacity'),
                  opacity: showTaskIndicators ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (final placement in placements)
                          if (placement.lane < _maxVisibleCalendarBars)
                            _buildBar(context, placement, dayWidth),
                        ..._buildOverflowLabels(context, placements, dayWidth),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDay(int index) {
    final date = days[index];
    return DayWidget(
      date: date,
      minimumDate: minimumDate,
      isSelected: date != null && DateUtils.isSameDay(date, selectedDay),
      compact: compact,
      onSelected: date == null || _isBeforeMinimum(date)
          ? null
          : () => onDaySelected(date),
    );
  }

  Widget _buildBar(
    BuildContext context,
    CalendarWeekPlacement placement,
    double dayWidth,
  ) {
    final span = placement.endColumn - placement.startColumn + 1;
    final title = placement.item.title;
    final top = _calendarHeaderHeight + placement.lane * _calendarBarExtent;
    final startsHere = !placement.continuesBefore;
    final endsHere = !placement.continuesAfter;
    return Positioned(
      left: placement.startColumn * dayWidth + 2,
      top: top,
      width: span * dayWidth - 4,
      height: _calendarBarHeight,
      child: Container(
        key: ValueKey(
          'calendar-bar-${placement.ordinal}-$title-'
          '${placement.item.date.toIso8601String()}',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(startsHere ? 5 : 1),
            right: Radius.circular(endsHere ? 5 : 1),
          ),
        ),
        child: Text(
          title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: placement.isCompleted
                ? AppColors.disabled
                : AppColors.onSurface,
            decoration: placement.isCompleted
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverflowLabels(
    BuildContext context,
    List<CalendarWeekPlacement> placements,
    double dayWidth,
  ) {
    if (placements.every(
      (placement) => placement.lane < _maxVisibleCalendarBars,
    )) {
      return const [];
    }

    final hiddenByColumn = <int, int>{};
    for (final placement in placements) {
      if (placement.lane < _maxVisibleCalendarBars) continue;
      for (
        var column = placement.startColumn;
        column <= placement.endColumn;
        column++
      ) {
        hiddenByColumn.update(column, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    const top =
        _calendarHeaderHeight + _maxVisibleCalendarBars * _calendarBarExtent;
    return [
      for (final entry in hiddenByColumn.entries)
        Positioned(
          left: entry.key * dayWidth + 2,
          top: top,
          width: dayWidth - 4,
          height: _calendarOverflowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: '${entry.value} more items',
              child: Text(
                '+${entry.value} more',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ),
    ];
  }

  bool _isBeforeMinimum(DateTime date) {
    final minimum = minimumDate;
    return minimum != null && dateOnly(date).isBefore(dateOnly(minimum));
  }
}
