import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'circular_icon_button.dart';

/// Add button displayed beside the bottom navigation bar.
class AddTaskButton extends StatelessWidget {
  const AddTaskButton({
    super.key,
    required this.primary,
    required this.controller,
    required this.isOpen,
    required this.onPressed,
  });

  final Color primary;
  final AnimationController controller;
  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Rotate the plus icon once when the add menu opens or closes.
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) =>
          Transform.rotate(angle: controller.value * 3.14159 * 2, child: child),
      child: CircularIconButton(
        backgroundColor: isOpen ? AppColors.secondary : primary,
        icon: Icons.add,
        onPressed: onPressed,
        tooltip: 'Add',
        duration: AppSpacing.fabAnimationDuration,
      ),
    );
  }
}
