import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/primary_app_bar.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('timer-app-bar'),
        destination: AppDestination.timer,
      ),
      body: Stack(
        children: [
          SizedBox.expand(),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: ValueKey('timer-navigation'),
              selectedIndex: AppDestination.timer.index,
            ),
          ),
        ],
      ),
    );
  }
}