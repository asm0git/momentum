import 'package:flutter/material.dart';

import '../app_theme.dart';

// Floating action button used to add a task from the bottom navigation area.
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) =>
          Transform.rotate(angle: controller.value * 3.14159 * 2, child: child),
      child: AnimatedContainer(
        duration: AppSpacing.fabAnimationDuration,
        decoration: BoxDecoration(
          color: isOpen ? AppColors.secondary : primary,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.add, color: AppColors.onPrimary),
          iconSize: AppSpacing.addIconSize,
          padding: const EdgeInsets.all(AppSpacing.md),
          tooltip: 'Add',
        ),
      ),
    );
  }
}
