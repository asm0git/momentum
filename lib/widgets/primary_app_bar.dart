import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

import '../app_theme.dart';
import '../navigation_destinations.dart';

// Shared colored app bar shown at the top of every main screen.
class PrimaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrimaryAppBar({
    super.key,
    required this.destination,
    this.isBlurred = false,
    this.actions,
  });

  final AppDestination destination;
  final bool isBlurred;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final appBar = AppBar(
      centerTitle: true,
      toolbarHeight: AppSpacing.appBarHeight,
      title: Text(
        destination.title,
        style: theme.textTheme.headlineLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      ),
      actions: actions,
      backgroundColor: theme.colorScheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.appBarBottom),
        ),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );

    if (!isBlurred) return appBar;
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: appBar,
      ),
    );
  }
}
