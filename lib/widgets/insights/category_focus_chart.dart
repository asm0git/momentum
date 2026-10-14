import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data_models.dart';
import '../category_icon_picker.dart';
import 'insights_formatters.dart';

class CategoryFocusChart extends StatelessWidget {
  const CategoryFocusChart({
    required this.totals,
    required this.iconNameFor,
    super.key,
  });

  final List<FocusCategoryTotal> totals;
  final String Function(int categoryId, String snapshotIcon) iconNameFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final legend = _CategoryLegend(
          totals: totals,
          iconNameFor: iconNameFor,
        );
        final ring = SizedBox(
          width: 184,
          height: 184,
          child: CustomPaint(
            key: const ValueKey('insights-category-ring'),
            painter: _CategoryRingPainter(values: totals),
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
    );
  }
}

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
                  formatFocusDuration(totals[index].totalSeconds),
                  style: style?.copyWith(color: AppColors.onSurface),
                ),
              ],
            ),
          ),
      ],
    );
  }
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
