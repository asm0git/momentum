import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data/recurrence.dart';
import '../data_models.dart';
import '../navigation_destinations.dart';
import '../state/planner_state.dart';
import '../widgets/navigation/bottom_navigation_bar.dart';
import '../widgets/navigation/primary_app_bar.dart';
import '../widgets/insights/category_focus_chart.dart';
import '../widgets/insights/focus_heatmap.dart';
import '../widgets/insights/insights_formatters.dart';
import '../widgets/insights/weekly_focus_chart.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late DateTime _weekStart = mondayOf(DateTime.now());
  Timer? _dateRolloverTimer;
  PlannerState? _planner;
  int _lastFocusRevision = -1;
  int _loadGeneration = 0;
  int _heatmapLoadGeneration = 0;
  bool _isLoading = true;
  bool _isHeatmapInitiallyLoading = true;
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
      unawaited(_reloadHeatmapTotals());
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
    final generation = ++_heatmapLoadGeneration;
    final today = dateOnly(DateTime.now());
    final heatStart = mondayOf(today).subtract(const Duration(days: 51 * 7));
    try {
      final totals = await planner.getFocusTotalsForRange(heatStart, today);
      if (!mounted ||
          generation != _heatmapLoadGeneration ||
          !identical(planner, _planner)) {
        return;
      }
      setState(() {
        _heatmapTotals = totals;
        _heatmapError = false;
        _isHeatmapInitiallyLoading = false;
      });
    } catch (error) {
      // Keep showing the last loaded heatmap if storage cannot be read.
      debugPrint('Could not refresh the focus heatmap: $error');
      if (mounted &&
          generation == _heatmapLoadGeneration &&
          identical(planner, _planner)) {
        setState(() {
          _heatmapError = true;
          _isHeatmapInitiallyLoading = false;
        });
      }
    }
  }

  void _onPlannerChanged() {
    final revision = _planner?.focusHistoryRevision;
    if (revision == null || revision == _lastFocusRevision) return;
    _lastFocusRevision = revision;
    _reload();
    unawaited(_reloadHeatmapTotals());
  }

  Future<void> _reload() async {
    final planner = _planner;
    if (planner == null) return;
    final generation = ++_loadGeneration;
    if (mounted) setState(() => _isLoading = true);
    final start = _weekStart;
    final end = start.add(const Duration(days: 6));
    try {
      final weekTotals = await planner.getFocusTotalsForRange(start, end);
      final categoryTotals = await planner.getFocusCategoryTotalsForRange(
        start,
        end,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _weekTotals = weekTotals;
        _categoryTotals = categoryTotals;
        _hasLoadedData = true;
        _loadError = false;
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
                      leading: const Icon(
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
                          WeeklyFocusChart(
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
                          CategoryFocusChart(
                            totals: _categoryTotals,
                            iconNameFor: _categoryIconNameFor,
                          ),
                      ],
                    ),
                  ),
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
                        if (_isHeatmapInitiallyLoading)
                          const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          FocusHeatmap(totals: _heatmapTotals),
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

String _formatWeekRange(DateTime start, DateTime end) {
  final startMonth = monthNameLabel(start.month);
  final endMonth = monthNameLabel(end.month);
  if (start.year == end.year && start.month == end.month) {
    return '$startMonth ${start.day}–${end.day}, ${end.year}';
  }
  if (start.year == end.year) {
    return '$startMonth ${start.day}–$endMonth ${end.day}, ${end.year}';
  }
  return '$startMonth ${start.day}, ${start.year}–$endMonth ${end.day}, ${end.year}';
}
