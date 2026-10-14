import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import 'insights_formatters.dart';

class WeeklyFocusChart extends StatefulWidget {
  const WeeklyFocusChart({
    required this.values,
    required this.days,
    required this.textTheme,
    super.key,
  });

  final List<int> values;
  final List<DateTime> days;
  final TextTheme textTheme;

  @override
  State<WeeklyFocusChart> createState() => _WeeklyFocusChartState();
}

class _WeeklyFocusChartState extends State<WeeklyFocusChart> {
  static const _axisWidth = 32.0;
  static const _chartHeight = 150.0;
  static const _tooltipHeight = 24.0;
  int? _selectedIndex;
  bool _selectionPinned = false;

  @override
  void didUpdateWidget(covariant WeeklyFocusChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values) ||
        !listEquals(oldWidget.days, widget.days)) {
      _selectedIndex = null;
      _selectionPinned = false;
    }
  }

  void _selectAt(double dx, double width, {required bool pinned}) {
    if (width <= 0 || widget.days.isEmpty) return;
    final index = (dx / width * widget.days.length)
        .floor()
        .clamp(0, widget.days.length - 1)
        .toInt();
    if (_selectedIndex == index && _selectionPinned == pinned) return;
    setState(() {
      _selectedIndex = index;
      _selectionPinned = pinned;
    });
  }

  void _clearHoverSelection() {
    if (_selectionPinned || _selectedIndex == null) return;
    setState(() => _selectedIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _FocusAxisScale.forValues(widget.values);
    final selectedIndex = _selectedIndex;
    final tooltip = selectedIndex == null
        ? null
        : '${weekdayShortLabel(widget.days[selectedIndex].weekday)}, '
              '${monthShortLabel(widget.days[selectedIndex].month)} '
              '${widget.days[selectedIndex].day} · '
              '${formatFocusDuration(widget.values[selectedIndex])}';

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _axisWidth,
              height: _tooltipHeight + _chartHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < 4; index++)
                    Positioned(
                      left: 0,
                      right: 4,
                      top:
                          _tooltipHeight +
                          _WeeklyBarsPainter.gridTop +
                          _WeeklyBarsPainter.gridHeight * index / 3 -
                          8,
                      child: SizedBox(
                        height: 16,
                        child: FittedBox(
                          alignment: Alignment.centerRight,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            scale.labelAt(index),
                            key: ValueKey('insights-y-axis-label-$index'),
                            maxLines: 1,
                            style: widget.textTheme.labelSmall?.copyWith(
                              color: AppColors.disabled,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: _tooltipHeight,
                    child: tooltip == null
                        ? const SizedBox.expand()
                        : Transform.translate(
                            offset: const Offset(-_axisWidth / 2, 0),
                            child: Center(
                              child: Container(
                                key: const ValueKey(
                                  'insights-bar-value-tooltip',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.navigationItem,
                                  ),
                                ),
                                child: Text(
                                  tooltip,
                                  style: widget.textTheme.labelSmall?.copyWith(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) => MouseRegion(
                      onHover: (event) => _selectAt(
                        event.localPosition.dx,
                        constraints.maxWidth,
                        pinned: false,
                      ),
                      onExit: (_) => _clearHoverSelection(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _selectAt(
                          details.localPosition.dx,
                          constraints.maxWidth,
                          pinned: details.kind != PointerDeviceKind.mouse,
                        ),
                        child: SizedBox(
                          height: _chartHeight,
                          width: double.infinity,
                          child: CustomPaint(
                            key: const ValueKey('insights-weekly-bar-chart'),
                            painter: _WeeklyBarsPainter(
                              values: widget.values,
                              maximum: scale.maximumSeconds,
                              selectedIndex: selectedIndex,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const SizedBox(width: _axisWidth),
            for (var index = 0; index < widget.days.length; index++)
              Expanded(
                child: Semantics(
                  label:
                      '${weekdayNameLabel(widget.days[index].weekday)}, '
                      '${formatFocusDuration(widget.values[index])}',
                  child: Text(
                    weekdayShortLabel(widget.days[index].weekday),
                    textAlign: TextAlign.center,
                    style: widget.textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FocusAxisScale {
  const _FocusAxisScale({
    required this.inHours,
    required this.interval,
    required this.maximumSeconds,
  });

  final bool inHours;
  final double interval;
  final double maximumSeconds;

  factory _FocusAxisScale.forValues(List<int> values) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final averageSeconds = values.isEmpty ? 0.0 : total / 7;
    final inHours = averageSeconds >= 60 * 60;
    final unitSeconds = inHours ? 60 * 60.0 : 60.0;
    final maximumSeconds = values.fold<int>(
      0,
      (maximum, value) => math.max(maximum, value),
    );
    if (maximumSeconds == 0) {
      // A zero-to-one-hour scale keeps an empty chart readable while retaining
      // an explicit zero baseline.
      return const _FocusAxisScale(
        inHours: false,
        interval: 20,
        maximumSeconds: 60 * 60,
      );
    }
    final maximumUnits = maximumSeconds / unitSeconds;
    final interval = _niceInterval(maximumUnits / 3);
    return _FocusAxisScale(
      inHours: inHours,
      interval: interval,
      maximumSeconds: interval * 3 * unitSeconds,
    );
  }

  String labelAt(int topToBottomIndex) {
    final units = interval * (3 - topToBottomIndex);
    final unitSeconds = inHours ? 60 * 60.0 : 60.0;
    return formatFocusDuration((units * unitSeconds).round());
  }
}

double _niceInterval(double roughInterval) {
  if (roughInterval <= 0 || !roughInterval.isFinite) return 1;
  final power = math
      .pow(10, (math.log(roughInterval) / math.ln10).floor())
      .toDouble();
  final fraction = roughInterval / power;
  final niceFraction = fraction <= 1
      ? 1
      : fraction <= 2
      ? 2
      : fraction <= 2.5
      ? 2.5
      : fraction <= 5
      ? 5
      : 10;
  return niceFraction * power;
}

class _WeeklyBarsPainter extends CustomPainter {
  const _WeeklyBarsPainter({
    required this.values,
    required this.maximum,
    required this.selectedIndex,
  });

  static const gridTop = 12.0;
  static const gridBottom = 8.0;
  static const gridHeight = 150.0 - gridTop - gridBottom;

  final List<int> values;
  final double maximum;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 0.0;
    const right = 0.0;
    final chart = Rect.fromLTRB(
      left,
      gridTop,
      size.width - right,
      size.height - gridBottom,
    );
    final linePaint = Paint()
      ..color = AppColors.disabled.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = chart.top + chart.height * index / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), linePaint);
    }
    final slot = chart.width / values.length;
    final barWidth = math.min(24.0, slot * 0.55);
    for (var index = 0; index < values.length; index++) {
      final normalized = maximum <= 0 ? 0.0 : values[index] / maximum;
      final barHeight = normalized * (chart.height - 4);
      final rect = Rect.fromLTWH(
        chart.left + slot * index + (slot - barWidth) / 2,
        chart.bottom - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = selectedIndex == index
              ? AppColors.secondary
              : AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(_WeeklyBarsPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.maximum != maximum ||
      oldDelegate.selectedIndex != selectedIndex;
}
