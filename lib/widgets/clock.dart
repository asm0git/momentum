import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../state/focus_timer_state.dart';

/// The timer face remains sharp while the surrounding timer page is blurred.
class Clock extends StatelessWidget {
  const Clock({super.key});

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<FocusTimerState>();
    final textTheme = Theme.of(context).textTheme;
    final progress = timer.progress;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: timer.toggleRunning,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: progress, end: progress),
                  duration: const Duration(milliseconds: 450),
                  builder: (context, value, child) =>
                      CustomPaint(painter: _ClockRingPainter(progress: value)),
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: timer.toggleRunning,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: timer.isRunning ? 0.45 : 1,
                      duration: AppSpacing.fabAnimationDuration,
                      curve: Curves.easeInOutCubic,
                      child: Text(
                        timer.isRunning ? 'Tap to pause' : 'Tap to start',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatClock(timer.remainingSeconds),
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 0),
                    AnimatedOpacity(
                      opacity: timer.isRunning ? 0.45 : 1,
                      duration: AppSpacing.fabAnimationDuration,
                      curve: Curves.easeInOutCubic,
                      child: Text(
                        timer.phase == FocusPhase.work ? 'Focus' : 'Rest',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      _formatTotal(timer.totalFocusSecondsToday),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: timer.isRunning ? 0.45 : 1,
                      duration: AppSpacing.fabAnimationDuration,
                      curve: Curves.easeInOutCubic,
                      child: Text(
                        'Total focus time today',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatClock(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
  }

  static String _formatTotal(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _ClockRingPainter extends CustomPainter {
  const _ClockRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = AppSpacing.xs;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final bounds = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    final trackPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final shadowPaint = Paint()
      ..color = AppColors.secondary.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
    canvas.drawArc(bounds, startAngle, sweepAngle, false, shadowPaint);

    final progressPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(bounds, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(_ClockRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
