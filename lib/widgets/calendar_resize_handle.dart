import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../calendar_view_mode.dart';

class CalendarResizeHandle extends StatefulWidget {
  const CalendarResizeHandle({
    super.key,
    required this.mode,
    required this.fullMonthWeekCount,
    required this.onModeChanged,
  });

  final CalendarViewMode mode;
  final int fullMonthWeekCount;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  State<CalendarResizeHandle> createState() => _CalendarResizeHandleState();
}

class _CalendarResizeHandleState extends State<CalendarResizeHandle> {
  double _dragDistance = 0;

  void _changeMode(CalendarViewMode? mode) {
    if (mode != null && mode != widget.mode) {
      widget.onModeChanged(mode);
    }
  }

  int _weekCountFor(CalendarViewMode mode) =>
      mode.visibleWeekCount ?? widget.fullMonthWeekCount;

  void _finishDrag() {
    final dragDistance = _dragDistance;
    _dragDistance = 0;
    if (dragDistance.abs() < kTouchSlop) return;

    final targetWeekCount =
        _weekCountFor(widget.mode) +
        dragDistance / AppSpacing.calendarDayHeight;
    var selectedMode = widget.mode;
    var closestDistance = double.infinity;

    for (final candidate in CalendarViewMode.values) {
      final distance = (_weekCountFor(candidate) - targetWeekCount).abs();
      final isCloser = distance < closestDistance - 0.0001;
      final isDirectionalTie =
          (distance - closestDistance).abs() <= 0.0001 &&
          ((dragDistance > 0 && candidate.index > selectedMode.index) ||
              (dragDistance < 0 && candidate.index < selectedMode.index));
      if (isCloser || isDirectionalTie) {
        selectedMode = candidate;
        closestDistance = distance;
      }
    }

    _changeMode(selectedMode);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('calendar-resize-handle-semantics'),
      container: true,
      label: 'Calendar height',
      value: widget.mode.label,
      hint: 'Swipe up to show fewer weeks or down to show more weeks.',
      increasedValue: widget.mode.largerMode?.label,
      decreasedValue: widget.mode.smallerMode?.label,
      onIncrease: widget.mode.largerMode == null
          ? null
          : () => _changeMode(widget.mode.largerMode),
      onDecrease: widget.mode.smallerMode == null
          ? null
          : () => _changeMode(widget.mode.smallerMode),
      child: GestureDetector(
        key: const ValueKey('calendar-resize-handle'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => _dragDistance = 0,
        onVerticalDragUpdate: (details) => _dragDistance += details.delta.dy,
        onVerticalDragEnd: (_) => _finishDrag(),
        child: const SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              width: 36,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
