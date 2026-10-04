import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/calendar.dart';
import '../widgets/primary_app_bar.dart';

// Calendar screen content shown below the primary app bar.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('calendar-app-bar'),
        destination: AppDestination.calendar,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.screenEdgePadding,
                vertical: AppSpacing.md,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.calendarBorder),
                ),
                child: CalendarWidget(),
              ),
            ),
          ),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: ValueKey('calendar-navigation'),
              selectedIndex: AppDestination.calendar.index,
            ),
          ),
        ],
      ),
    );
  }
}