import 'package:flutter/material.dart';

import '../app_theme.dart';

class CircularIconButton extends StatelessWidget {
  const CircularIconButton({
    super.key,
    required this.backgroundColor,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.foregroundColor = AppColors.onPrimary,
    this.iconSize = AppSpacing.addIconSize,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.duration = Duration.zero,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: foregroundColor),
        iconSize: iconSize,
        padding: padding,
        tooltip: tooltip,
      ),
    );
  }
}
