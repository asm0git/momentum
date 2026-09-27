import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../navigation_destinations.dart';
import '../widgets/bottom_navigation_bar.dart';
import '../widgets/primary_app_bar.dart';

class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PrimaryAppBar(
        key: ValueKey('ai-app-bar'),
        destination: AppDestination.ai,
      ),
      body: Stack(
        children: [
          SizedBox.expand(),
          Positioned.fill(
            child: FloatingNavigationGroup(
              key: ValueKey('ai-navigation'),
              selectedIndex: AppDestination.ai.index,
            ),
          ),
        ],
      ),
    );
  }
}