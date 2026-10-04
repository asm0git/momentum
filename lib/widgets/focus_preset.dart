import 'package:flutter/material.dart';

import '../app_theme.dart';

// Compact timer preset card shown above the clock on the timer screen.
class FocusPreset extends StatelessWidget {
  const FocusPreset({
    super.key,
    this.workMinutes = 30,
    this.breakMinutes = 5,
  });

  final int workMinutes;
  final int breakMinutes;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.md,
    ),
      padding: const EdgeInsets.all(AppSpacing.md),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.focusPreset),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/img/unselected/Timer.png',
            width: AppSpacing.md,
            height: AppSpacing.md,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$workMinutes mins',
                style: textTheme.titleMedium?.copyWith(height: 0),
              ),
              Text(
                '$breakMinutes mins',
                style: textTheme.bodySmall?.copyWith(height: 0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
