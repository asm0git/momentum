import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../calendar_view_mode.dart';

class CalendarResizeHandle extends StatefulWidget {
  const CalendarResizeHandle({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  State<CalendarResizeHandle> createState() => _CalendarResizeHandleState();
}

class _CalendarResizeHandleState extends State<CalendarResizeHandle> {
  int? _activePointer;
  double? _pointerStartY;

  void _changeMode(CalendarViewMode? mode) {
    if (mode != null && mode != widget.mode) {
      widget.onModeChanged(mode);
    }
  }

  void _finishPointer(int pointer, double currentY) {
    if (_activePointer != pointer) return;
    final startY = _pointerStartY;
    _activePointer = null;
    _pointerStartY = null;
    if (startY == null || currentY == startY) return;

    _changeMode(
      currentY < startY ? widget.mode.smallerMode : widget.mode.largerMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('calendar-resize-handle-semantics'),
      container: true,
      label: 'Calendar height',
      value: widget.mode.label,
      hint:
          'Drag up to reduce the calendar or hide event bars. Drag down to show more weeks or event bars.',
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
        // Keep this recognizer in the gesture arena so a resize drag does not
        // scroll the page. The Listener handles movement below Flutter's drag
        // touch slop as well.
        onVerticalDragStart: (_) {},
        onVerticalDragUpdate: (_) {},
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_activePointer != null) return;
            _activePointer = event.pointer;
            _pointerStartY = event.position.dy;
          },
          onPointerUp: (event) =>
              _finishPointer(event.pointer, event.position.dy),
          onPointerCancel: (event) {
            if (_activePointer != event.pointer) return;
            _activePointer = null;
            _pointerStartY = null;
          },
          child: const SizedBox(
            height: 54,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: AppColors.calendarBorder),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 36,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
