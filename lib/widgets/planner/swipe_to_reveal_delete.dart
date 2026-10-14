import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// Reveals the app's circular delete action after a left swipe.
class SwipeToRevealDelete extends StatefulWidget {
  const SwipeToRevealDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.deleteLabel = 'Delete item',
    this.backgroundColor = AppColors.surface,
    this.deleteCircleScale = 1,
    this.deleteRightInset,
  });

  static const actionWidth = 72.0;

  final Widget child;
  final VoidCallback onDelete;
  final String deleteLabel;
  final Color backgroundColor;
  final double deleteCircleScale;
  final double? deleteRightInset;

  @override
  State<SwipeToRevealDelete> createState() => _SwipeToRevealDeleteState();
}

class _SwipeToRevealDeleteState extends State<SwipeToRevealDelete>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _controller.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _controller.value =
        (_controller.value - details.delta.dx / SwipeToRevealDelete.actionWidth)
            .clamp(0.0, 1.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity < -300 ||
        (velocity.abs() <= 300 && _controller.value >= 0.35)) {
      _controller.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      _controller.animateBack(0, curve: Curves.easeInCubic);
    }
  }

  void _onHorizontalDragCancel() {
    _controller.animateBack(0, curve: Curves.easeInCubic);
  }

  void _delete() {
    _controller.animateBack(0, curve: Curves.easeInCubic);
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        final row = SizedBox(
          width: rowWidth,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(child: ColoredBox(color: widget.backgroundColor)),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: SwipeToRevealDelete.actionWidth,
                      child: Semantics(
                        button: true,
                        label: widget.deleteLabel,
                        onTap: _delete,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _delete,
                          child: Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final scaledDiameter =
                                    constraints.maxHeight *
                                    widget.deleteCircleScale;
                                final diameter =
                                    scaledDiameter <
                                        SwipeToRevealDelete.actionWidth
                                    ? scaledDiameter
                                    : SwipeToRevealDelete.actionWidth;
                                final iconSize = diameter * 0.5 < 24
                                    ? diameter * 0.5
                                    : 24.0;
                                final rightInset = widget.deleteRightInset;
                                final horizontalOffset = rightInset == null
                                    ? 0.0
                                    : (SwipeToRevealDelete.actionWidth -
                                                  diameter) /
                                              2 -
                                          rightInset;
                                return Transform.translate(
                                  offset: Offset(horizontalOffset, 0),
                                  child: SizedBox.square(
                                    dimension: diameter,
                                    child: DecoratedBox(
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Tooltip(
                                          message: widget.deleteLabel,
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppColors.onPrimary,
                                            size: iconSize,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                child: SizedBox(
                  width: rowWidth,
                  child: RepaintBoundary(
                    child: ColoredBox(
                      color: widget.backgroundColor,
                      child: widget.child,
                    ),
                  ),
                ),
                builder: (context, child) {
                  // Keep the moving surface edge on physical pixels to avoid
                  // fractional rasterization leaving a thin red fringe from
                  // the delete action underneath.
                  final rawOffset =
                      -SwipeToRevealDelete.actionWidth * _controller.value;
                  final alignedOffset =
                      (rawOffset * devicePixelRatio).round() / devicePixelRatio;
                  return Transform.translate(
                    offset: Offset(alignedOffset, 0),
                    child: IgnorePointer(
                      ignoring: _controller.value > 0.02,
                      child: child,
                    ),
                  );
                },
              ),
            ],
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onHorizontalDragCancel: _onHorizontalDragCancel,
          child: ClipRect(clipBehavior: Clip.hardEdge, child: row),
        );
      },
    );
  }
}
