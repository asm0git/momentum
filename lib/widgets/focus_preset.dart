import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Compact card that displays a work period and its matching break.
class FocusPreset extends StatelessWidget {
  const FocusPreset({
    super.key,
    this.workMinutes = 30,
    this.breakMinutes = 5,
    this.margin,
    this.onPressed,
  });

  final int workMinutes;
  final int breakMinutes;
  final EdgeInsets? margin;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin:
          margin ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.md,
          ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.focusPreset),
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.focusPreset),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.focusPreset),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                    Text('$workMinutes minutes', style: textTheme.titleMedium),
                    Text(
                      '$breakMinutes minutes rest',
                      style: textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.onSurface,
                  size: AppSpacing.navigationIconSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
