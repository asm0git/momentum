import 'package:flutter/material.dart';

import '../app_theme.dart';

class DialogActionButtons extends StatelessWidget {
  const DialogActionButtons({
    super.key,
    required this.cancelLabel,
    required this.actionLabel,
    required this.onCancel,
    required this.onAction,
    required this.actionColor,
  });

  final String cancelLabel;
  final String actionLabel;
  final VoidCallback onCancel;
  final VoidCallback? onAction;
  final Color actionColor;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.normal);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.onSurface,
            minimumSize: const Size(0, 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: textStyle,
          ),
          onPressed: onCancel,
          child: Text(cancelLabel),
        ),
        const SizedBox(height: AppSpacing.xxs),
        FilledButton(
          style:
              FilledButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(0, 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: textStyle,
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                  states,
                ) {
                  if (states.contains(WidgetState.disabled)) {
                    return AppColors.disabled;
                  }
                  return actionColor;
                }),
              ),
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}
