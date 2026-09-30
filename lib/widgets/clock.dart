import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../app_theme.dart';

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
  bool _isPressed = false;

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

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 450,
        height: 450,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 500,
              height: 500,
              child: GestureDetector(
                onTap: _toggleTimer,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surface),
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: _previousProgress,
                      end: progress,
                    ),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, value, child) {
                      return CustomPaint(
                        painter: _ClockRingPainter(progress: value),
                      );
                    },
                  ),
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: _toggleTimer,
                onTapDown: (_) => setState(() => _isPressed = true),
                onTapUp: (_) => setState(() => _isPressed = false),
                onTapCancel: () => setState(() => _isPressed = false),
                child: AnimatedScale(
                  scale: _isPressed ? 0.96 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.surface),
                        ),
                        child: Text(
                          _isRunning ? 'Tap to pause' : 'Tap to start',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontSize: (textTheme.bodySmall?.fontSize ?? 12) * 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.surface),
                        ),
                        child: Text(
                          _formatTime(_remainingSeconds),
                          style: textTheme.headlineLarge?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: AppSpacing.lg * 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.surface),
                        ),
                        child: Text(
                          '1:24:25',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize:
                                (textTheme.bodyMedium?.fontSize ?? 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.surface),
                        ),
                        child: Text(
                          'Total focus time',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontSize: (textTheme.bodySmall?.fontSize ?? 12) * 2,
                          ),
                        ),
                      ),
                    ],
                  ),
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
    final strokeWidth = AppSpacing.lg;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = size.center(Offset.zero);
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final startAngle = -math.pi / 2;
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
