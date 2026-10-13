import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data/recurrence.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../state/planner_state.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/category_icon_picker.dart';
import '../widgets/primary_app_bar.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late DateTime _weekStart = _mondayOf(DateTime.now());
  Timer? _dateRolloverTimer;
  PlannerState? _planner;
  int _lastFocusRevision = -1;
  int _loadGeneration = 0;
  bool _isLoading = true;
  bool _hasLoadedData = false;
  bool _loadError = false;
  bool _heatmapError = false;
  Map<DateTime, int> _weekTotals = {};
  Map<DateTime, int> _heatmapTotals = {};
  List<FocusCategoryTotal> _categoryTotals = [];

  @override
  void initState() {
    super.initState();
    _scheduleDateRollover();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final planner = context.read<PlannerState>();
    if (!identical(planner, _planner)) {
      _planner?.removeListener(_onPlannerChanged);
      _planner = planner;
      _lastFocusRevision = planner.focusHistoryRevision;
      planner.addListener(_onPlannerChanged);
      _reload();
    }
  }

  @override
  void dispose() {
    _dateRolloverTimer?.cancel();
    _planner?.removeListener(_onPlannerChanged);
    super.dispose();
  }

  void _scheduleDateRollover() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _dateRolloverTimer = Timer(nextMidnight.difference(now), () {
      if (!mounted) return;
      _scheduleDateRollover();
      setState(() {});
      unawaited(_reloadHeatmapTotals());
    });
  }

  Future<void> _reloadHeatmapTotals() async {
    final planner = _planner;
    if (planner == null) return;
    final today = dateOnly(DateTime.now());
    final heatStart = _mondayOf(today).subtract(const Duration(days: 51 * 7));
    try {
      final totals = await planner.getFocusTotalsForRange(heatStart, today);
      if (!mounted) return;
      setState(() {
        _heatmapTotals = totals;
        _heatmapError = false;
      });
    } catch (error) {
      // Keep showing the last loaded heatmap if storage cannot be read.
      debugPrint('Could not refresh the focus heatmap: $error');
      if (mounted) setState(() => _heatmapError = true);
    }
  }

  void _onPlannerChanged() {
    final revision = _planner?.focusHistoryRevision;
    if (revision == null || revision == _lastFocusRevision) return;
    _lastFocusRevision = revision;
    _reload();
  }

  Future<void> _reload() async {
    final planner = _planner;
    if (planner == null) return;
    final generation = ++_loadGeneration;
    if (mounted) setState(() => _isLoading = true);
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    final today = dateOnly(DateTime.now());
    final currentWeek = _mondayOf(today);
    final heatStart = currentWeek.subtract(const Duration(days: 51 * 7));
    try {
      final weekTotals = await planner.getFocusTotalsForRange(start, end);
      final categoryTotals = await planner.getFocusCategoryTotalsForRange(
        start,
        end,
      );
      final heatmapTotals = await planner.getFocusTotalsForRange(
        heatStart,
        today,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _weekTotals = weekTotals;
        _categoryTotals = categoryTotals;
        _heatmapTotals = heatmapTotals;
        _hasLoadedData = true;
        _loadError = false;
        _heatmapError = false;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      debugPrint('Could not load insights data: $error');
      setState(() {
        _loadError = true;
        _isLoading = false;
      });
    }
  }

  void _changeWeek(int amount) {
    setState(() => _weekStart = _weekStart.add(Duration(days: amount * 7)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final weekDays = List<DateTime>.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final dailyValues = [
      for (final day in weekDays) _weekTotals[dateOnly(day)] ?? 0,
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(destination: AppDestination.insights),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenEdgePadding,
                AppSpacing.md,
                AppSpacing.screenEdgePadding,
                120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loadError) ...[
                    MaterialBanner(
                      key: const ValueKey('insights-load-error'),
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                      ),
                      content: Text(
                        _hasLoadedData
                            ? 'Could not refresh insights. Showing the last loaded totals.'
                            : 'Could not load insights. Try again to reload your totals.',
                      ),
                      backgroundColor: AppColors.surface,
                      actions: [
                        TextButton(
                          key: const ValueKey('insights-retry'),
                          onPressed: _reload,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _insightsSection(
                    title: 'Focus time per week',
                    textTheme: textTheme,
                    cardKey: const ValueKey('insights-weekly-card'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _InsightsWeekControl(
                              controlKey: const ValueKey(
                                'insights-previous-week',
                              ),
                              icon: Icons.chevron_left,
                              tooltip: 'Previous week',
                              onPressed: () => _changeWeek(-1),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  _formatWeekRange(_weekStart, weekEnd),
                                  key: const ValueKey('insights-week-range'),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            _InsightsWeekControl(
                              controlKey: const ValueKey('insights-next-week'),
                              icon: Icons.chevron_right,
                              tooltip: 'Next week',
                              onPressed: () => _changeWeek(1),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        if (_isLoading)
                          const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          _WeeklyBarChart(
                            values: dailyValues,
                            days: weekDays,
                            textTheme: textTheme,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Daily focus time',
                            textAlign: TextAlign.center,
                            style: textTheme.labelMedium?.copyWith(
                              color: AppColors.disabled,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _insightsSection(
                    title: 'Focus by category',
                    textTheme: textTheme,
                    cardKey: const ValueKey('insights-category-card'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLoading)
                          const SizedBox(
                            height: 180,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_categoryTotals.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                            child: Text(
                              'No categorized focus time this week.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.disabled,
                              ),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final legend = _CategoryLegend(
                                totals: _categoryTotals,
                                iconNameFor: _categoryIconNameFor,
                              );
                              final ring = SizedBox(
                                width: 184,
                                height: 184,
                                child: CustomPaint(
                                  key: const ValueKey('insights-category-ring'),
                                  painter: _CategoryRingPainter(
                                    values: _categoryTotals,
                                  ),
                                ),
                              );
                              if (constraints.maxWidth < 460) {
                                return Column(
                                  children: [
                                    ring,
                                    const SizedBox(height: AppSpacing.md),
                                    legend,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  ring,
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: legend),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _insightsSection(
                    title: 'Focus heatmap',
                    textTheme: textTheme,
                    cardKey: const ValueKey('insights-heatmap-card'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Daily focus time over recent weeks',
                          style: textTheme.labelMedium?.copyWith(
                            color: AppColors.disabled,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_heatmapError)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'The heatmap may be out of date.',
                                  ),
                                ),
                                TextButton(
                                  key: const ValueKey('insights-heatmap-retry'),
                                  onPressed: () =>
                                      unawaited(_reloadHeatmapTotals()),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        if (_isLoading)
                          const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          _FocusHeatmap(totals: _heatmapTotals),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: const ValueKey('insights-navigation'),
              selectedIndex: AppDestination.insights.index,
            ),
          ),
        ],
      ),
    );
  }

  String _categoryIconNameFor(int categoryId, String snapshotIcon) {
    final planner = _planner;
    if (planner == null) return snapshotIcon;
    final category = planner.categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    return category == null
        ? snapshotIcon
        : planner.categoryDisplayIconName(category);
  }
}

class _InsightsWeekControl extends StatelessWidget {
  const _InsightsWeekControl({
    required this.controlKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Key controlKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpacing.calendarMonthControlSize,
      child: IconButton(
        key: controlKey,
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: AppSpacing.calendarMonthChevronSize,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          backgroundColor: AppColors.onPrimary,
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

Widget _insightsSection({
  required String title,
  required TextTheme textTheme,
  required Widget child,
  required Key cardKey,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Text(title, style: textTheme.titleMedium),
    const SizedBox(height: AppSpacing.xxs),
    Container(
      key: cardKey,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: child,
    ),
  ],
);

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({required this.totals, required this.iconNameFor});

  final List<FocusCategoryTotal> totals;
  final String Function(int categoryId, String snapshotIcon) iconNameFor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < totals.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                CategoryIcon(
                  iconName: iconNameFor(
                    totals[index].categoryId,
                    totals[index].categoryIcon,
                  ),
                  size: 20,
                  color:
                      AppColors.focusChartColors[index %
                          AppColors.focusChartColors.length],
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    totals[index].categoryTitle,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _durationLabel(totals[index].totalSeconds),
                  style: style?.copyWith(color: AppColors.onSurface),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FocusHeatmap extends StatelessWidget {
  const _FocusHeatmap({required this.totals});

  final Map<DateTime, int> totals;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final currentWeek = _mondayOf(today);
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
                              _monthShort(columns[column].month),
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
                          _weekdayShort(weekday + 1),
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
    final description = '$dateLabel: ${_durationLabel(seconds)} focus';
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

class _WeeklyBarChart extends StatefulWidget {
  const _WeeklyBarChart({
    required this.values,
    required this.days,
    required this.textTheme,
  });

  final List<int> values;
  final List<DateTime> days;
  final TextTheme textTheme;

  @override
  State<_WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<_WeeklyBarChart> {
  static const _axisWidth = 32.0;
  static const _chartHeight = 150.0;
  static const _tooltipHeight = 24.0;
  int? _selectedIndex;
  bool _selectionPinned = false;

  @override
  void didUpdateWidget(covariant _WeeklyBarChart oldWidget) {
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
        : '${_weekdayShort(widget.days[selectedIndex].weekday)}, '
              '${_monthShort(widget.days[selectedIndex].month)} '
              '${widget.days[selectedIndex].day} · '
              '${_durationLabel(widget.values[selectedIndex])}';

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
                      '${_weekdayName(widget.days[index].weekday)}, '
                      '${_durationLabel(widget.values[index])}',
                  child: Text(
                    _weekdayShort(widget.days[index].weekday),
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
    return _durationLabel((units * unitSeconds).round());
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

class _CategoryRingPainter extends CustomPainter {
  const _CategoryRingPainter({required this.values});

  final List<FocusCategoryTotal> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, item) => sum + item.totalSeconds);
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.36;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index].totalSeconds / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = AppColors
              .focusChartColors[index % AppColors.focusChartColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_CategoryRingPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values);
}

DateTime _mondayOf(DateTime date) {
  final day = dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _formatWeekRange(DateTime start, DateTime end) {
  final startMonth = _monthName(start.month);
  final endMonth = _monthName(end.month);
  if (start.year == end.year && start.month == end.month) {
    return '$startMonth ${start.day}–${end.day}, ${end.year}';
  }
  if (start.year == end.year) {
    return '$startMonth ${start.day}–$endMonth ${end.day}, ${end.year}';
  }
  return '$startMonth ${start.day}, ${start.year}–$endMonth ${end.day}, ${end.year}';
}

String _durationLabel(int seconds) {
  if (seconds <= 0) return '0 mins';
  if (seconds < 60) return '${seconds}s';

  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final remainingMinutes = totalMinutes % 60;
  if (hours == 0) {
    return '$totalMinutes ${totalMinutes == 1 ? 'min' : 'mins'}';
  }
  final hourLabel = '$hours ${hours == 1 ? 'hr' : 'hrs'}';
  if (remainingMinutes == 0) return hourLabel;
  final minuteLabel =
      '$remainingMinutes ${remainingMinutes == 1 ? 'min' : 'mins'}';
  return '$hourLabel $minuteLabel';
}

String _weekdayShort(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

String _weekdayName(int weekday) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][weekday - 1];

String _monthName(int month) => const [
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
][month - 1];

String _monthShort(int month) => const [
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
][month - 1];
