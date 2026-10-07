import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../app_theme.dart';

// Interactive countdown clock displayed on the timer screen.
class Clock extends StatefulWidget {
  const Clock({super.key});

  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  static const int _totalSeconds = 25 * 60;
  int _remainingSeconds = _totalSeconds;
  bool _isRunning = false;
  Timer? _timer;
  double _previousProgress = 1;

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
    } else {
      if (_remainingSeconds <= 0) {
        _previousProgress = 0;
        _remainingSeconds = _totalSeconds;
      }
      setState(() {
        _isRunning = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() {
            _previousProgress = _remainingSeconds / _totalSeconds;
            _remainingSeconds--;
          });
        } else {
          timer.cancel();
          setState(() {
            _isRunning = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSecs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = _remainingSeconds / _totalSeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleTimer,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: _previousProgress, end: progress),
                  duration: const Duration(milliseconds: 900),
                  builder: (context, value, child) {
                    return CustomPaint(
                      painter: _ClockRingPainter(progress: value),
                    );
                  },
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: _toggleTimer,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: _isRunning ? 0.45 : 1,
                      duration: AppSpacing.fabAnimationDuration,
                      child: Text(
                        _isRunning ? 'Tap to pause' : 'Tap to start',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 0),
                    AnimatedOpacity(
                      opacity: _isRunning ? 0.45 : 1,
                      duration: AppSpacing.fabAnimationDuration,
                      child: Text(
                        '1:24:25',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 0),
                    AnimatedOpacity(
                      opacity: _isRunning ? 0.45 : 1,
                      duration: AppSpacing.fabAnimationDuration,
                      child: Text(
                        'Total focus time',
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
