import 'package:flutter/material.dart';

import '../app_theme.dart';

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
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/img/unselected/Timer.png',
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$workMinutes mins',
                style: textTheme.titleMedium?.copyWith(height: 1),
              ),
              Text(
                '$breakMinutes mins',
                style: textTheme.bodySmall?.copyWith(height: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
