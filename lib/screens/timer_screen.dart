import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/clock.dart';
import '../widgets/focus_preset.dart';
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
          const Center(
            child: const Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.md,
                left: AppSpacing.screenEdgePadding,
                right: AppSpacing.screenEdgePadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: const Row(
                        children: [FocusPreset()],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SizedBox(
                    width: double.infinity,
                    child: Clock(),
                  ),
                ],
              ),
            ),
          ),
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
