import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data_models.dart';
import '../../services/calendar_backend_client.dart';
import '../pill_action_button.dart';

class CalendarProviderPanel extends StatelessWidget {
  const CalendarProviderPanel({
    super.key,
    required this.provider,
    required this.status,
    required this.loading,
    required this.syncing,
    required this.isLast,
    required this.message,
    required this.error,
    required this.feedEditor,
    required this.onRetry,
    required this.onSync,
    required this.onDisconnect,
  });

  final CalendarProvider provider;
  final CalendarConnectionStatus? status;
  final bool loading;
  final bool syncing;
  final bool isLast;
  final String? message;
  final String? error;
  final Widget feedEditor;
  final VoidCallback onRetry;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentStatus = status;
    final connected = currentStatus?.connected == true;
    final isPublishedIcsFeed =
        currentStatus?.providerUrl?.endsWith('-published-ics') ?? false;
    final showAccountIdentity =
        !isPublishedIcsFeed &&
        (currentStatus?.accountName != null ||
            currentStatus?.accountEmail != null);
    final feedbackText = error ?? message;

    return Padding(
      key: ValueKey('calendar-provider-panel-${provider.key}'),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: isLast ? AppSpacing.md : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading && currentStatus == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (currentStatus == null)
            SizedBox(
              width: double.infinity,
              child: PillActionButton(
                label: 'Try again',
                leadingIcon: Icons.refresh,
                foregroundColor: AppColors.error,
                outlineColor: AppColors.error,
                onPressed: onRetry,
              ),
            )
          else if (connected) ...[
            if (showAccountIdentity)
              Text(
                '${currentStatus.accountName ?? 'Connected'}${currentStatus.accountEmail == null ? '' : '\n${currentStatus.accountEmail}'}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            if (showAccountIdentity) const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (currentStatus.lastSyncTime != null) ...[
                  Container(
                    key: ValueKey('calendar-sync-success-${provider.key}'),
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Expanded(
                  child: Text(
                    currentStatus.lastSyncTime == null
                        ? 'Not synced yet'
                        : 'Last synced ${MaterialLocalizations.of(context).formatMediumDate(currentStatus.lastSyncTime!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(currentStatus.lastSyncTime!.toLocal()))}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Refreshes when Momentum opens and every 5 minutes while it is open.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            feedEditor,
            if (syncing) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
              Text('Syncing…', style: textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: AppSpacing.popupFieldHeight,
              child: FilledButton.icon(
                onPressed: syncing ? null : onSync,
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                  textStyle: _actionTextStyle(context, AppColors.onPrimary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.popupFieldHeight,
              child: OutlinedButton(
                onPressed: onDisconnect,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  textStyle: _actionTextStyle(context, AppColors.error),
                ),
                child: const Text('Disconnect'),
              ),
            ),
          ] else ...[
            feedEditor,
          ],
          if (feedbackText != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              feedbackText,
              style: textTheme.bodySmall?.copyWith(
                color: error == null ? AppColors.primary : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _actionTextStyle(BuildContext context, Color color) => Theme.of(
    context,
  ).textTheme.bodyMedium!.copyWith(color: color, fontWeight: FontWeight.normal);
}
