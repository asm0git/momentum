import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../services/onboarding_preferences.dart';
import '../state/planner_state.dart';

class AddCalendarsScreen extends StatelessWidget {
  const AddCalendarsScreen({super.key, this.onboarding = false});

  final bool onboarding;

  Future<void> _continue(BuildContext context) async {
    if (onboarding) {
      await OnboardingPreferences.markComplete();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final query = Uri.base.queryParameters;
    final callbackProvider = CalendarProvider.values
        .where((provider) => provider.key == query['calendar_provider'])
        .firstOrNull;
    final callbackError = callbackProvider == null
        ? null
        : query['${callbackProvider.key}_error'];
    final callbackMessage = callbackProvider == null
        ? null
        : callbackError == null
        ? query['${callbackProvider.key}_connected'] == '1'
              ? '${callbackProvider.title} connected. Syncing your calendar…'
              : null
        : callbackError == 'authorization_cancelled'
        ? '${callbackProvider.title} authorization was canceled.'
        : callbackError == 'provider_not_configured'
        ? '${callbackProvider.title} is not configured yet.'
        : 'Could not connect ${callbackProvider.title}. Please try again.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenEdgePadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              Image.asset(
                'assets/img/logo/logo_purple.png',
                width: 164,
                fit: BoxFit.contain,
                semanticLabel: 'Momentum',
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.focusPreset),
                ),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < CalendarProvider.values.length;
                      index++
                    ) ...[
                      _CalendarRow(
                        provider: CalendarProvider.values[index],
                        connected:
                            planner
                                .statusForProvider(
                                  CalendarProvider.values[index],
                                )
                                ?.connected ==
                            true,
                        syncing: planner.isProviderSyncing(
                          CalendarProvider.values[index],
                        ),
                        hasError:
                            planner.errorForProvider(
                              CalendarProvider.values[index],
                            ) !=
                            null,
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(_routeFor(CalendarProvider.values[index])),
                      ),
                      if (index < CalendarProvider.values.length - 1)
                        const Divider(
                          height: 1,
                          indent: AppSpacing.md + 28 + AppSpacing.md,
                          endIndent: AppSpacing.md,
                          color: AppColors.background,
                        ),
                    ],
                  ],
                ),
              ),
              if (callbackMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    callbackMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: callbackError == null
                          ? AppColors.primary
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filled(
                  tooltip: onboarding
                      ? 'Skip calendar setup and continue'
                      : 'Return to Momentum',
                  onPressed: () => _continue(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.all(AppSpacing.md),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  static String _routeFor(CalendarProvider provider) => switch (provider) {
    CalendarProvider.canvas => '/canvas',
    CalendarProvider.googleCalendar => '/google',
    CalendarProvider.outlook => '/outlook',
  };
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({
    required this.provider,
    required this.connected,
    required this.syncing,
    required this.hasError,
    required this.onTap,
  });

  final CalendarProvider provider;
  final bool connected;
  final bool syncing;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(_iconFor(provider), color: AppColors.primary, size: 26),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  provider.title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
                ),
              ),
              if (syncing)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hasError)
                const Icon(Icons.error_outline, color: AppColors.error)
              else if (connected)
                const Icon(Icons.check_circle, color: AppColors.secondary)
              else
                const Icon(Icons.chevron_right, color: AppColors.onSurface),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(CalendarProvider provider) => switch (provider) {
    CalendarProvider.canvas => Icons.school_outlined,
    CalendarProvider.googleCalendar => Icons.calendar_month_outlined,
    CalendarProvider.outlook => Icons.event_note_outlined,
  };
}
