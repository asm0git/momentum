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

class AddCalendarsScreen extends StatefulWidget {
  const AddCalendarsScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  State<AddCalendarsScreen> createState() => _AddCalendarsScreenState();
}

class _AddCalendarsScreenState extends State<AddCalendarsScreen> {
  final Map<CalendarProvider, TextEditingController> _icsControllers = {
    for (final provider in CalendarProvider.values)
      provider: TextEditingController(),
  };
  CalendarProvider? _expandedProvider;
  CalendarProvider? _loadingProvider;
  CalendarProvider? _connectingProvider;
  String? _message;
  String? _error;
  CalendarProvider? _editingIcsProvider;

  @override
  void dispose() {
    for (final controller in _icsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

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
      _icsControllers[provider]!.clear();
      if (_editingIcsProvider == provider) _editingIcsProvider = null;
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

  Future<void> _connect(CalendarProvider provider) async {
    final icsUrl = _normalizeIcsUrl(_icsControllers[provider]!.text);
    if (icsUrl == null) {
      setState(() {
        _message = null;
        _error =
            'Paste a valid HTTPS .ics link published by ${provider.title}.';
      });
      return;
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
        _icsControllers[provider]!.clear();
        setState(() {
          _connectingProvider = null;
          if (_editingIcsProvider == provider) _editingIcsProvider = null;
          _message = _connectedMessage(provider);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _connectingProvider = null;
          _error = _readableError(error);
        });
      }
    }
  }

  void _editCalendarIcs(CalendarProvider provider) {
    setState(() {
      _editingIcsProvider = provider;
      _icsControllers[provider]!.clear();
      _message = null;
      _error = null;
    });
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
        _icsControllers[provider]!.clear();
        if (_editingIcsProvider == provider) _editingIcsProvider = null;
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
                                        context,
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
    BuildContext context,
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
                  _providerPanel(context, planner, provider, isLast: isLast),
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
    BuildContext context,
    PlannerState planner,
    CalendarProvider provider, {
    required bool isLast,
  }) {
    final status = planner.statusForProvider(provider);
    final textTheme = Theme.of(context).textTheme;
    final connected = status?.connected == true;
    final syncing = planner.isProviderSyncing(provider);
    final isPublishedIcsFeed =
        status?.providerUrl?.endsWith('-published-ics') ?? false;
    final showAccountIdentity =
        !isPublishedIcsFeed &&
        (status?.accountName != null || status?.accountEmail != null);

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
          if (_loadingProvider == provider && status == null)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (status == null)
            SizedBox(
              width: double.infinity,
              child: PillActionButton(
                label: 'Try again',
                leadingIcon: Icons.refresh,
                foregroundColor: AppColors.error,
                outlineColor: AppColors.error,
                onPressed: () {
                  setState(() {
                    _loadingProvider = provider;
                    _error = null;
                  });
                  unawaited(_loadProvider(provider));
                },
              ),
            )
          else if (connected) ...[
            if (showAccountIdentity)
              Text(
                '${status.accountName ?? 'Connected'}${status.accountEmail == null ? '' : '\n${status.accountEmail}'}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            if (showAccountIdentity) const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (status.lastSyncTime != null) ...[
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
                    status.lastSyncTime == null
                        ? 'Not synced yet'
                        : 'Last synced ${MaterialLocalizations.of(context).formatMediumDate(status.lastSyncTime!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(status.lastSyncTime!.toLocal()))}',
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
            if (_editingIcsProvider == provider)
              _icsEditor(context, provider: provider, connected: true)
            else
              SizedBox(
                height: AppSpacing.popupFieldHeight,
                child: OutlinedButton.icon(
                  onPressed: () => _editCalendarIcs(provider),
                  icon: const Icon(Icons.link),
                  label: const Text('Change published link'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    textStyle: _actionTextStyle(context, AppColors.primary),
                  ),
                ),
              ),
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
                onPressed: syncing ? null : () => _syncProvider(provider),
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
                onPressed: () => _disconnect(provider),
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
            Text(
              _icsInstructions(provider),
              style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            _icsEditor(context, provider: provider, connected: false),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: AppSpacing.popupFieldHeight,
              child: FilledButton.icon(
                onPressed: _connectingProvider == provider
                    ? null
                    : () => _connect(provider),
                icon: Image.asset(
                  _iconAssetFor(provider),
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
                label: Text(
                  _connectingProvider == provider
                      ? 'Checking calendar…'
                      : _connectButtonLabel(provider),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                  textStyle: _actionTextStyle(context, AppColors.onPrimary),
                ),
              ),
            ),
          ],
          if (_message != null || _error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error ?? _message!,
              style: textTheme.bodySmall?.copyWith(
                color: _error == null ? AppColors.primary : AppColors.error,
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

  TextStyle _fieldTextStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .bodyMedium!
      .copyWith(color: AppColors.onSurface, fontWeight: FontWeight.normal);

  TextStyle _fieldHintStyle(BuildContext context) => _fieldTextStyle(
    context,
  ).copyWith(color: AppColors.onSurface.withValues(alpha: 0.55));

  Widget _icsEditor(
    BuildContext context, {
    required CalendarProvider provider,
    required bool connected,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (connected) ...[
        Text(
          'Enter a new published link. The saved link is kept private and is not shown here.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
      DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadii.popup),
        ),
        child: SizedBox(
          height: AppSpacing.popupFieldHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: double.infinity,
                height: 24,
                child: TextField(
                  controller: _icsControllers[provider]!,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  textAlignVertical: TextAlignVertical.center,
                  style: _fieldTextStyle(context),
                  decoration: InputDecoration.collapsed(
                    hintText: '${provider.title} published .ics link',
                    hintStyle: _fieldHintStyle(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      if (connected) ...[
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _connectingProvider == provider
                    ? null
                    : () => _connect(provider),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                  textStyle: _actionTextStyle(context, AppColors.onPrimary),
                ),
                child: Text(
                  _connectingProvider == provider
                      ? 'Checking calendar…'
                      : 'Update link',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton(
                onPressed: _connectingProvider == provider
                    ? null
                    : () {
                        setState(() {
                          _editingIcsProvider = null;
                          _icsControllers[provider]!.clear();
                          _error = null;
                          _message = null;
                        });
                      },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.popupFieldHeight),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  textStyle: _actionTextStyle(context, AppColors.primary),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    ],
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

  String _icsInstructions(CalendarProvider provider) => switch (provider) {
    CalendarProvider.canvas =>
      'Paste the calendar feed link from Canvas. The link grants read access; keep it private.',
    CalendarProvider.googleCalendar =>
      'Paste the secret address in iCal format from Google Calendar. Anyone with the link can view the calendar, so keep it private.',
    CalendarProvider.outlook =>
      'Paste the published ICS link from Outlook. Anyone with the link can view the calendar, so keep it private.',
  };

  String _connectButtonLabel(CalendarProvider provider) =>
      provider == CalendarProvider.googleCalendar
      ? 'Connect Google Calendar'
      : 'Connect ${provider.title} calendar';

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
