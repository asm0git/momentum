import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// The clock face supports pointer selection and accessible label buttons.
class AppTimePickerDial extends StatelessWidget {
  const AppTimePickerDial({
    super.key,
    required this.time,
    required this.selectingHour,
    required this.use24Hours,
    required this.onChanged,
    required this.onHourSelected,
  });

  final TimeOfDay time;
  final bool selectingHour;
  final bool use24Hours;
  final ValueChanged<TimeOfDay> onChanged;
  final VoidCallback onHourSelected;

  void _select(int value, {bool commit = false}) {
    final selected = selectingHour
        ? time.replacing(
            hour: use24Hours
                ? value
                : value % 12 + (time.period == DayPeriod.pm ? 12 : 0),
          )
        : time.replacing(minute: value);
    onChanged(selected);
    if (selectingHour && commit) onHourSelected();
  }

  void _selectPosition(Offset position, Size size, {bool commit = false}) {
    final offset = position - size.center(Offset.zero);
    if (offset.distance < AppSpacing.xs) return;
    final angle =
        (math.atan2(offset.dy, offset.dx) + math.pi / 2) % (2 * math.pi);
    if (selectingHour) {
      var hour = (angle / (2 * math.pi) * 12).round() % 12;
      if (use24Hours) {
        final innerRing = offset.distance < size.shortestSide / 2 - 42;
        if (innerRing) {
          hour = hour == 0 ? 0 : hour + 12;
        } else {
          hour = hour == 0 ? 12 : hour;
        }
      }
      _select(hour, commit: commit);
    } else {
      _select((angle / (2 * math.pi) * 60).round() % 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pickerTheme = TimePickerTheme.of(context);
    final selectedValue = selectingHour
        ? (use24Hours
              ? time.hour
              : (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod))
        : time.minute;
    final values = selectingHour
        ? [
            12,
            ...List.generate(11, (i) => i + 1),
            if (use24Hours) ...[0, ...List.generate(11, (i) => i + 13)],
          ]
        : List.generate(12, (i) => i * 5);
    final handColor = pickerTheme.dialHandColor ?? AppColors.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size.square(constraints.biggest.shortestSide);
        final center = size.center(Offset.zero);
        final outerRadius = size.shortestSide / 2 - 28;
        final innerSelected =
            selectingHour &&
            use24Hours &&
            (selectedValue == 0 || selectedValue > 12);
        final fraction = selectingHour
            ? (selectedValue % 12) / 12
            : selectedValue / 60;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) =>
              _selectPosition(details.localPosition, size, commit: true),
          onPanStart: (details) => _selectPosition(details.localPosition, size),
          onPanUpdate: (details) =>
              _selectPosition(details.localPosition, size),
          onPanEnd: (_) {
            if (selectingHour) onHourSelected();
          },
          child: CustomPaint(
            painter: _DialHandPainter(
              fraction: fraction,
              radius: outerRadius - (innerSelected ? 28 : 0),
              backgroundColor:
                  pickerTheme.dialBackgroundColor ??
                  theme.colorScheme.surfaceContainerHighest,
              handColor: handColor,
            ),
            child: Stack(
              children: [
                for (var index = 0; index < values.length; index++)
                  _label(
                    context,
                    values[index],
                    index,
                    center,
                    outerRadius - (index >= 12 ? 28 : 0),
                    selectedValue == values[index],
                    pickerTheme,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(
    BuildContext context,
    int value,
    int index,
    Offset center,
    double radius,
    bool selected,
    TimePickerThemeData pickerTheme,
  ) {
    final angle = (index % 12) * math.pi / 6 - math.pi / 2;
    final position = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final states = selected ? {WidgetState.selected} : <WidgetState>{};
    final color = pickerTheme.dialTextColor;
    final textColor = color == null
        ? (selected ? AppColors.onPrimary : AppColors.onSurface)
        : WidgetStateProperty.resolveAs<Color>(color, states);
    final label = selectingHour
        ? value.toString()
        : value.toString().padLeft(2, '0');
    return Positioned(
      left: position.dx - 24,
      top: position.dy - 24,
      width: 48,
      height: 48,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${selectingHour ? 'Hour' : 'Minute'} $label',
        // Paint numeral feedback above the clock face, within a full circle.
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkResponse(
            key: ValueKey(
              'time-picker-dial-${selectingHour ? 'hour' : 'minute'}-$value',
            ),
            containedInkWell: true,
            customBorder: const CircleBorder(),
            highlightShape: BoxShape.circle,
            radius: 24,
            onTap: () => _select(value, commit: true),
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style:
                      (pickerTheme.dialTextStyle ??
                              Theme.of(context).textTheme.bodyLarge)
                          ?.copyWith(color: textColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialHandPainter extends CustomPainter {
  const _DialHandPainter({
    required this.fraction,
    required this.radius,
    required this.backgroundColor,
    required this.handColor,
  });

  final double fraction;
  final double radius;
  final Color backgroundColor;
  final Color handColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final angle = fraction * 2 * math.pi - math.pi / 2;
    final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(
      center,
      size.shortestSide / 2,
      Paint()..color = backgroundColor,
    );
    final paint = Paint()..color = handColor;
    canvas.drawLine(center, end, paint..strokeWidth = 2);
    canvas.drawCircle(end, 24, paint);
    canvas.drawCircle(center, 4, paint);
  }

  @override
  bool shouldRepaint(_DialHandPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      radius != oldDelegate.radius ||
      backgroundColor != oldDelegate.backgroundColor ||
      handColor != oldDelegate.handColor;
}
