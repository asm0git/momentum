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
    final cancelStyle = FilledButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.primary,
      shape: const StadiumBorder(),
      minimumSize: const Size(0, 42),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: textStyle,
    );
    final actionStyle = FilledButton.styleFrom(
      backgroundColor: actionColor,
      foregroundColor: AppColors.onPrimary,
      shape: const StadiumBorder(),
      minimumSize: const Size(0, 42),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: textStyle,
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.disabled;
        return actionColor;
      }),
    );

    return Container(
      key: const ValueKey('dialog-action-buttons'),
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.background),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              style: cancelStyle,
              onPressed: onCancel,
              child: Text(cancelLabel),
            ),
          ),
          Expanded(
            child: FilledButton(
              style: actionStyle,
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
