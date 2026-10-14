import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/recurrence.dart';
import 'insights_formatters.dart';

class FocusHeatmap extends StatelessWidget {
  const FocusHeatmap({required this.totals, super.key});

  final Map<DateTime, int> totals;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final currentWeek = mondayOf(today);
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      key: const ValueKey('insights-heatmap-grid'),
      builder: (context, constraints) {
        const weekdayLabelWidth = 28.0;
        const cellStride = 15.0;
        final availableWeeks = constraints.maxWidth.isFinite
            ? ((constraints.maxWidth - weekdayLabelWidth) / cellStride).floor()
            : 52;
        final weekCount = availableWeeks.clamp(1, 52).toInt();
        final gridWidth = weekdayLabelWidth + weekCount * cellStride;
        final start = currentWeek.subtract(Duration(days: (weekCount - 1) * 7));
        final columns = List<DateTime>.generate(
          weekCount,
          (index) => start.add(Duration(days: index * 7)),
        );

        return SizedBox(
          width: gridWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: gridWidth,
                height: 16,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (var column = 0; column < columns.length; column++)
                      if (column == 0 ||
                          columns[column].month != columns[column - 1].month ||
                          columns[column].year != columns[column - 1].year)
                        Positioned(
                          left: math.min(
                            weekdayLabelWidth + column * cellStride,
                            gridWidth - 36,
                          ),
                          top: 0,
                          child: SizedBox(
                            width: 36,
                            child: Text(
                              monthShortLabel(columns[column].month),
                              key: ValueKey(
                                'insights-month-${columns[column].year}-${columns[column].month}',
                              ),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.disabled,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              for (var weekday = 0; weekday < 7; weekday++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: weekdayLabelWidth,
                        child: Text(
                          weekdayShortLabel(weekday + 1),
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.disabled,
                          ),
                        ),
                      ),
                      for (final week in columns)
                        if (week.add(Duration(days: weekday)).isAfter(today))
                          const SizedBox(width: cellStride, height: 12)
                        else
                          _HeatmapCell(
                            date: week.add(Duration(days: weekday)),
                            seconds:
                                totals[dateOnly(
                                  week.add(Duration(days: weekday)),
                                )] ??
                                0,
                          ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Less', style: textTheme.labelSmall),
                  const SizedBox(width: AppSpacing.xxs),
                  for (final color in AppColors.focusHeatmapLevels)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Text('More', style: textTheme.labelSmall),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({required this.date, required this.seconds});

  final DateTime date;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final dateLabel = MaterialLocalizations.of(context).formatFullDate(date);
    final description = '$dateLabel: ${formatFocusDuration(seconds)} focus';
    final level = focusHeatmapLevelForSeconds(seconds);
    return Semantics(
      label: description,
      child: Tooltip(
        message: description,
        child: Container(
          key: ValueKey(
            'insights-heatmap-cell-${date.toIso8601String().substring(0, 10)}',
          ),
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: AppColors.focusHeatmapLevels[level],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

int focusHeatmapLevelForSeconds(int seconds) => seconds <= 0
    ? 0
    : seconds < 30 * 60
    ? 1
    : seconds < 60 * 60
    ? 2
    : seconds <= 2 * 60 * 60
    ? 3
    : 4;
