import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.primary,
        systemNavigationBarColor: AppColors.primary,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Image.asset(
                  'assets/img/logo/logo_white.png',
                  width: 224,
                  fit: BoxFit.contain,
                  semanticLabel: 'Momentum',
                ),
              ),
              Positioned(
                left: AppSpacing.screenEdgePadding,
                right: AppSpacing.screenEdgePadding,
                bottom: AppSpacing.md,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.onPrimary,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.focusPreset),
                    ),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushReplacementNamed('/calendars', arguments: true),
                  child: Text(
                    'Get started',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
