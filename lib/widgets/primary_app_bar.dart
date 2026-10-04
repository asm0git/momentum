import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';

// Shared colored app bar shown at the top of every main screen.
class PrimaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrimaryAppBar({super.key, required this.destination});

  final AppDestination destination;

  @override
  Size get preferredSize => const Size.fromHeight(AppSpacing.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      centerTitle: true,
      toolbarHeight: AppSpacing.appBarHeight,
      title: Text(
        destination.title,
        style: theme.textTheme.headlineLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      ),
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
  }
}