import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/recurrence.dart';
import '../data_models.dart';
import 'days.dart';

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
            ? const <_PlacedCalendarItem>[]
            : _placeItems(firstDate, lastDate, validDates);

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
      isSelected: date != null && _sameDay(date, selectedDay),
      compact: compact,
      onSelected: date == null || _isBeforeMinimum(date)
          ? null
          : () => onDaySelected(date),
    );
  }

  List<_PlacedCalendarItem> _placeItems(
    DateTime firstDate,
    DateTime lastDate,
    List<(int, DateTime)> validDates,
  ) {
    final occurrences = <_CalendarOccurrence>[];
    var ordinal = 0;
    for (final item in items) {
      if (item is Event) {
        final durationDays = dateOnly(
          item.endDate,
        ).difference(dateOnly(item.date)).inDays.clamp(0, 3650).toInt();
        final searchStart = firstDate.subtract(Duration(days: durationDays));
        for (final occurrenceDate in recurrenceDatesInRange(
          item,
          from: searchStart,
          through: lastDate,
        )) {
          final occurrence = occurrenceForDate(item, occurrenceDate) as Event;
          final startsOn = dateOnly(occurrence.date);
          final endsOn = dateOnly(occurrence.endDate);
          if (endsOn.isBefore(firstDate) || startsOn.isAfter(lastDate)) {
            continue;
          }
          occurrences.add(
            _CalendarOccurrence(
              item: occurrence,
              startsOn: startsOn,
              endsOn: endsOn.isBefore(startsOn) ? startsOn : endsOn,
              ordinal: ordinal++,
            ),
          );
        }
      } else if (item is Task) {
        for (final occurrenceDate in recurrenceDatesInRange(
          item,
          from: firstDate,
          through: lastDate,
        )) {
          final occurrence = occurrenceForDate(item, occurrenceDate);
          occurrences.add(
            _CalendarOccurrence(
              item: occurrence,
              startsOn: dateOnly(occurrenceDate),
              endsOn: dateOnly(occurrenceDate),
              ordinal: ordinal++,
            ),
          );
        }
      }
    }
    occurrences.sort(_compareCalendarOccurrences);

    final firstColumn = validDates.first.$1;
    final lastColumn = validDates.last.$1;
    final placements = <_PlacedCalendarItem>[];
    for (final occurrence in occurrences) {
      final startColumn = _columnForDate(
        validDates,
        occurrence.startsOn,
        beforeColumn: firstColumn,
        afterColumn: lastColumn,
      );
      final endColumn = _columnForDate(
        validDates,
        occurrence.endsOn,
        beforeColumn: firstColumn,
        afterColumn: lastColumn,
      );
      if (endColumn < startColumn) continue;

      var lane = 0;
      while (placements.any(
        (placed) =>
            placed.lane == lane &&
            startColumn <= placed.endColumn &&
            endColumn >= placed.startColumn,
      )) {
        lane++;
      }
      placements.add(
        _PlacedCalendarItem(
          occurrence: occurrence,
          startColumn: startColumn,
          endColumn: endColumn,
          lane: lane,
          continuesBefore: occurrence.startsOn.isBefore(firstDate),
          continuesAfter: occurrence.endsOn.isAfter(lastDate),
        ),
      );
    }
    return placements;
  }

  Widget _buildBar(
    BuildContext context,
    _PlacedCalendarItem placement,
    double dayWidth,
  ) {
    final span = placement.endColumn - placement.startColumn + 1;
    final title = placement.occurrence.item.title;
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
          'calendar-bar-${placement.occurrence.ordinal}-$title-'
          '${placement.occurrence.startsOn.toIso8601String()}',
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
            color: placement.occurrence.isCompleted
                ? AppColors.disabled
                : AppColors.onSurface,
            decoration: placement.occurrence.isCompleted
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverflowLabels(
    BuildContext context,
    List<_PlacedCalendarItem> placements,
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

class _CalendarOccurrence {
  const _CalendarOccurrence({
    required this.item,
    required this.startsOn,
    required this.endsOn,
    required this.ordinal,
  });

  final PlannerItem item;
  final DateTime startsOn;
  final DateTime endsOn;
  final int ordinal;

  DateTime get scheduledAt {
    if (item is Task) {
      final task = item as Task;
      return DateTime(
        startsOn.year,
        startsOn.month,
        startsOn.day,
        task.time.hour,
        task.time.minute,
      );
    }
    final event = item as Event;
    return DateTime(
      startsOn.year,
      startsOn.month,
      startsOn.day,
      event.allDay ? 0 : event.start.hour,
      event.allDay ? 0 : event.start.minute,
    );
  }

  bool get isCompleted => item is Task && (item as Task).isChecked;
}

class _PlacedCalendarItem {
  const _PlacedCalendarItem({
    required this.occurrence,
    required this.startColumn,
    required this.endColumn,
    required this.lane,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final _CalendarOccurrence occurrence;
  final int startColumn;
  final int endColumn;
  final int lane;
  final bool continuesBefore;
  final bool continuesAfter;
}

int _compareCalendarOccurrences(
  _CalendarOccurrence first,
  _CalendarOccurrence second,
) {
  final firstDay = dateOnly(first.startsOn);
  final secondDay = dateOnly(second.startsOn);
  final dayComparison = firstDay.compareTo(secondDay);
  if (dayComparison != 0) return dayComparison;

  final firstAllDay = first.item is Event && (first.item as Event).allDay;
  final secondAllDay = second.item is Event && (second.item as Event).allDay;
  if (firstAllDay != secondAllDay) return firstAllDay ? -1 : 1;

  final scheduleComparison = first.scheduledAt.compareTo(second.scheduledAt);
  if (scheduleComparison != 0) return scheduleComparison;

  final titleComparison = first.item.title.toLowerCase().compareTo(
    second.item.title.toLowerCase(),
  );
  if (titleComparison != 0) return titleComparison;
  return first.ordinal.compareTo(second.ordinal);
}

int _columnForDate(
  List<(int, DateTime)> dates,
  DateTime date, {
  required int beforeColumn,
  required int afterColumn,
}) {
  for (final (column, visibleDate) in dates) {
    if (_sameDay(date, visibleDate)) return column;
  }
  if (date.isBefore(dates.first.$2)) return beforeColumn;
  return afterColumn;
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
