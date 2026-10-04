import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/primary_app_bar.dart';

// Dashboard screen scaffold and its primary content area.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('dashboard-app-bar'),
        destination: AppDestination.dashboard,
      ),
      body: _ScreenBody(),
    );
  }
}

// Dashboard body behind the floating navigation group.
class _ScreenBody extends StatelessWidget {
  const _ScreenBody();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const SizedBox.expand(),
        Positioned.fill(
          child: FloatingNavigationGroup(
            key: ValueKey('dashboard-navigation'),
            selectedIndex: AppDestination.dashboard.index,
          ),
        ),
      ],
    );
  }
}