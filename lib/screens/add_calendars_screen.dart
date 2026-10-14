import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../services/onboarding_preferences.dart';
import '../state/planner_state.dart';
import '../widgets/blurred_dialog.dart';
import '../widgets/circular_icon_button.dart';
import '../widgets/confirmation_dialog_actions.dart';
import '../widgets/pill_action_button.dart';
import '../widgets/calendar/calendar_feed_editor.dart';
import '../widgets/calendar/calendar_provider_panel.dart';

class AddCalendarsScreen extends StatefulWidget {
  const AddCalendarsScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  State<AddCalendarsScreen> createState() => _AddCalendarsScreenState();
}

class _AddCalendarsScreenState extends State<AddCalendarsScreen> {
  CalendarProvider? _expandedProvider;
  CalendarProvider? _loadingProvider;
  CalendarProvider? _connectingProvider;
  String? _message;
  String? _error;

  Future<void> _continue() async {
    if (widget.onboarding) {
      await OnboardingPreferences.markComplete();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
      return;
    }

    final navigator = Navigator.of(context);
    if (!navigator.canPop()) {
      navigator.pushNamedAndRemoveUntil('/dashboard', (_) => false);
      return;
    }

    var foundPreviousScreen = false;
    navigator.popUntil((route) {
      if (route.settings.name == '/calendars') {
        return !navigator.canPop();
      }
      foundPreviousScreen = true;
      return true;
    });
    if (!foundPreviousScreen) {
      navigator.pushNamedAndRemoveUntil('/dashboard', (_) => false);
    }
  }

  Future<void> _toggleProvider(CalendarProvider provider) async {
    if (_expandedProvider == provider) {
      setState(() {
        _expandedProvider = null;
        _loadingProvider = null;
        _message = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _expandedProvider = provider;
      _loadingProvider = provider;
      _message = null;
      _error = null;
    });
    await _loadProvider(provider);
  }

  Future<void> _loadProvider(CalendarProvider provider) async {
    try {
      final planner = context.read<PlannerState>();
      final status = await planner.refreshProviderStatus(provider);
      if (!mounted || _expandedProvider != provider) return;

      final account = planner.accountForProvider(provider);
      final accountChanged =
          account == null ||
          (status.remoteUserId != null &&
              account.remoteUserId != status.remoteUserId) ||
          (status.providerUrl != null &&
              account.providerUrl != status.providerUrl);
      final syncIsDue =
          account == null ||
          accountChanged ||
          account.lastSyncTime == null ||
          status.lastSyncTime == null ||
          DateTime.now().difference(status.lastSyncTime!) >=
              const Duration(minutes: 15);

      if (status.connected &&
          syncIsDue &&
          !planner.isProviderSyncing(provider)) {
        await _syncProvider(provider, automatic: true);
      }
    } catch (error) {
      if (mounted && _expandedProvider == provider) {
        setState(() => _error = _readableError(error));
      }
    } finally {
      if (mounted && _loadingProvider == provider) {
        setState(() => _loadingProvider = null);
      }
    }
  }

  Future<bool> _connect(CalendarProvider provider, String enteredUrl) async {
    final icsUrl = _normalizeIcsUrl(enteredUrl);
    if (icsUrl == null) {
      setState(() {
        _message = null;
        _error =
            'Paste a valid HTTPS .ics link published by ${provider.title}.';
      });
      return false;
    }

    setState(() {
      _connectingProvider = provider;
      _message = null;
      _error = null;
    });
    try {
      final planner = context.read<PlannerState>();
      await planner.connectCalendarIcsFeed(provider, icsUrl);
      await planner.syncProvider(provider);
      if (mounted) {
        setState(() {
          _connectingProvider = null;
          _message = _connectedMessage(provider);
        });
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _connectingProvider = null;
          _error = _readableError(error);
        });
      }
      return false;
    }
  }

  Future<void> _syncProvider(
    CalendarProvider provider, {
    bool automatic = false,
  }) async {
    if (!automatic) {
      setState(() {
        _message = null;
        _error = null;
      });
    }
    try {
      await context.read<PlannerState>().syncProvider(provider);
      if (mounted && _expandedProvider == provider) {
        setState(() => _message = 'Sync complete.');
      }
    } catch (error) {
      if (mounted && _expandedProvider == provider) {
        setState(() => _error = _readableError(error));
      }
    }
  }

  Future<void> _disconnect(CalendarProvider provider) async {
    final confirmed = await showBlurredDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = (MediaQuery.sizeOf(dialogContext).width - 32)
            .clamp(280.0, 400.0)
            .toDouble();
        final buttonRowWidth = dialogWidth - (AppSpacing.md * 2);
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          backgroundColor: AppColors.background,
          title: Text(
            'Disconnect ${provider.title}?',
            style: Theme.of(dialogContext).textTheme.titleMedium,
          ),
          content: Text(
            'Imported items will remain in Momentum.',
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          actions: [
            SizedBox(
              width: buttonRowWidth,
              child: DialogActionButtons(
                cancelLabel: 'Cancel',
                actionLabel: 'Disconnect',
                onCancel: () => Navigator.pop(dialogContext, false),
                onAction: () => Navigator.pop(dialogContext, true),
                actionColor: AppColors.error,
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _message = null;
      _error = null;
    });
    try {
      await context.read<PlannerState>().disconnectProvider(provider);
      if (mounted && _expandedProvider == provider) {
        setState(
          () => _message =
              '${provider.title} disconnected. Imported items remain.',
        );
      }
    } catch (error) {
      if (mounted && _expandedProvider == provider) {
        setState(() => _error = _readableError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();

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
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sync your calendars',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: AppColors.primary),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.focusPreset,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < CalendarProvider.values.length;
                                      index++
                                    )
                                      _providerSection(
                                        planner,
                                        CalendarProvider.values[index],
                                        isLast:
                                            index ==
                                            CalendarProvider.values.length - 1,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: widget.onboarding
                    ? PillActionButton(
                        label: 'Skip',
                        onPressed: _continue,
                        trailingIcon: Icons.chevron_right,
                      )
                    : CircularIconButton(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        icon: Icons.chevron_right,
                        onPressed: _continue,
                        tooltip: 'Return to planner',
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _providerSection(
    PlannerState planner,
    CalendarProvider provider, {
    required bool isLast,
  }) {
    final expanded = _expandedProvider == provider;
    final status = planner.statusForProvider(provider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CalendarRow(
                  provider: provider,
                  connected: status?.connected == true,
                  syncing:
                      planner.isProviderSyncing(provider) ||
                      _loadingProvider == provider,
                  hasError:
                      planner.errorForProvider(provider) != null ||
                      (expanded && _error != null),
                  expanded: expanded,
                  onTap: () => _toggleProvider(provider),
                ),
                if (expanded) ...[
                  const SizedBox(height: AppSpacing.md),
                  _providerPanel(planner, provider, isLast: isLast),
                  if (!isLast) const SizedBox(height: AppSpacing.md),
                ] else
                  const SizedBox(width: double.infinity, height: 0),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: AppSpacing.md + 28 + AppSpacing.md,
            endIndent: AppSpacing.md,
            color: AppColors.background,
          ),
      ],
    );
  }

  Widget _providerPanel(
    PlannerState planner,
    CalendarProvider provider, {
    required bool isLast,
  }) {
    final status = planner.statusForProvider(provider);
    final connected = status?.connected == true;
    return CalendarProviderPanel(
      provider: provider,
      status: status,
      loading: _loadingProvider == provider,
      syncing: planner.isProviderSyncing(provider),
      isLast: isLast,
      message: _message,
      error: _error,
      feedEditor: _calendarFeedEditor(provider, connected: connected),
      onRetry: () {
        setState(() {
          _loadingProvider = provider;
          _error = null;
        });
        unawaited(_loadProvider(provider));
      },
      onSync: () => _syncProvider(provider),
      onDisconnect: () => _disconnect(provider),
    );
  }

  Widget _calendarFeedEditor(
    CalendarProvider provider, {
    required bool connected,
  }) => CalendarFeedEditor(
    key: ValueKey('calendar-feed-editor-${provider.key}'),
    provider: provider,
    iconAsset: _iconAssetFor(provider),
    connected: connected,
    connecting: _connectingProvider == provider,
    onConnect: (url) => _connect(provider, url),
    onEditingStarted: connected
        ? () => setState(() {
            _message = null;
            _error = null;
          })
        : null,
    onCancelled: connected
        ? () => setState(() {
            _message = null;
            _error = null;
          })
        : null,
  );
  String? _normalizeIcsUrl(String value) {
    var input = value.trim();
    if (input.isEmpty) return null;
    if (input.toLowerCase().startsWith('webcal://')) {
      input = 'https://${input.substring('webcal://'.length)}';
    }
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !uri.path.toLowerCase().endsWith('.ics')) {
      return null;
    }
    return uri.toString();
  }

  String _connectedMessage(CalendarProvider provider) =>
      provider == CalendarProvider.googleCalendar
      ? 'Google Calendar connected and synced.'
      : '${provider.title} calendar connected and synced.';

  String _readableError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');

  static String _iconAssetFor(CalendarProvider provider) => switch (provider) {
    CalendarProvider.canvas => 'assets/img/import/canvas.png',
    CalendarProvider.googleCalendar => 'assets/img/import/gcalendar.png',
    CalendarProvider.outlook => 'assets/img/import/outlook.png',
  };
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({
    required this.provider,
    required this.connected,
    required this.syncing,
    required this.hasError,
    required this.expanded,
    required this.onTap,
  });

  final CalendarProvider provider;
  final bool connected;
  final bool syncing;
  final bool hasError;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: '${provider.title}${connected ? ', connected' : ''}',
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          key: ValueKey('calendar-provider-row-${provider.key}'),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              expanded ? 0.0 : AppSpacing.md,
            ),
            child: Row(
              children: [
                Image.asset(
                  _CalendarRow._iconAssetFor(provider),
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    provider.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                if (syncing)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (hasError)
                  const Icon(Icons.error_outline, color: AppColors.error)
                else if (expanded)
                  const Icon(Icons.expand_less, color: AppColors.onSurface)
                else if (connected)
                  const Icon(Icons.check_circle, color: AppColors.secondary)
                else
                  const Icon(Icons.expand_more, color: AppColors.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _iconAssetFor(CalendarProvider provider) => switch (provider) {
    CalendarProvider.canvas => 'assets/img/import/canvas.png',
    CalendarProvider.googleCalendar => 'assets/img/import/gcalendar.png',
    CalendarProvider.outlook => 'assets/img/import/outlook.png',
  };
}
