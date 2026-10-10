import 'package:flutter/material.dart';

import '../app_theme.dart';

class PillActionButton extends StatelessWidget {
  const PillActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.normal,
    );

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.surface),
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 20),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: labelStyle),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(trailingIcon, size: 20),
          ],
        ],
      ),
    );
  }
}
