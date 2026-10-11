import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../services/canvas_oauth_redirect_stub.dart'
    if (dart.library.js_interop) '../services/canvas_oauth_redirect_web.dart'
    as oauth;
import '../services/onboarding_preferences.dart';
import '../state/planner_state.dart';
import '../widgets/blurred_dialog.dart';
import '../widgets/pill_action_button.dart';

class AddCalendarsScreen extends StatefulWidget {
  const AddCalendarsScreen({
    super.key,
    this.onboarding = false,
    this.callbackUri,
  });

  final bool onboarding;
  final Uri? callbackUri;

  @override
  State<AddCalendarsScreen> createState() => _AddCalendarsScreenState();
}

class _AddCalendarsScreenState extends State<AddCalendarsScreen> {
  final _canvasSiteController = TextEditingController();
  CalendarProvider? _expandedProvider;
  CalendarProvider? _loadingProvider;
  CalendarProvider? _connectingProvider;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    final query = (widget.callbackUri ?? Uri.base).queryParameters;
    final callbackProvider = _providerFromKey(query['calendar_provider']);
    _expandedProvider = callbackProvider;
    if (callbackProvider != null) {
      final callbackError = query['${callbackProvider.key}_error'];
      if (callbackError != null) {
        _error = switch (callbackError) {
          'authorization_cancelled' =>
            '${callbackProvider.title} authorization was canceled.',
          'provider_not_configured' =>
            '${callbackProvider.title} is not configured yet.',
          _ => 'Could not connect ${callbackProvider.title}. Please try again.',
        };
      } else if (query['${callbackProvider.key}_connected'] == '1') {
        _message = '${callbackProvider.title} connected.';
      }
    }

    final provider = _expandedProvider;
    if (provider != null) {
      _loadingProvider = provider;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadProvider(provider));
      });
    }
  }

  @override
  void dispose() {
    _canvasSiteController.dispose();
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
      if (provider == CalendarProvider.canvas) {
        _canvasSiteController.clear();
      }
    });
    await _loadProvider(provider);
  }

  Future<void> _loadProvider(CalendarProvider provider) async {
    try {
      final planner = context.read<PlannerState>();
      final status = await planner.refreshProviderStatus(provider);
      if (!mounted || _expandedProvider != provider) return;

      if (provider == CalendarProvider.canvas) {
        _canvasSiteController.text = status.providerUrl ?? '';
      }

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
    String? siteUrl;
    if (provider == CalendarProvider.canvas) {
      siteUrl = _normalizeCanvasUrl(_canvasSiteController.text);
      if (siteUrl == null) {
        setState(() {
          _message = null;
          _error = 'Enter a valid Canvas site URL.';
        });
        return;
      }
    }

    setState(() {
      _connectingProvider = provider;
      _message = null;
      _error = null;
    });
    try {
      final planner = context.read<PlannerState>();
      final uri = provider == CalendarProvider.canvas
          ? planner.canvasOAuthStartUri(siteUrl!)
          : planner.providerOAuthStartUri(provider);
      oauth.redirectToCanvasOAuth(uri.toString());
    } catch (error) {
      if (mounted) {
        setState(() {
          _connectingProvider = null;
          _error = _readableError(error);
        });
      }
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Disconnect ${provider.title}?',
          style: Theme.of(dialogContext).textTheme.titleMedium,
        ),
        content: Text(
          'Imported items will remain in Momentum.',
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _message = null;
      _error = null;
    });
    try {
      await context.read<PlannerState>().disconnectProvider(provider);
      if (mounted && _expandedProvider == provider) {
        if (provider == CalendarProvider.canvas) _canvasSiteController.clear();
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

  void _manageSettings(CalendarProvider provider) {
    Navigator.of(context).pushNamed(_routeFor(provider));
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
                child: PillActionButton(
                  label: 'Skip',
                  onPressed: _continue,
                  trailingIcon: Icons.chevron_right,
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
            if (status.accountName != null || status.accountEmail != null)
              Text(
                '${status.accountName ?? 'Connected'}${status.accountEmail == null ? '' : '\n${status.accountEmail}'}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              status.lastSyncTime == null
                  ? 'Not synced yet'
                  : 'Last synced ${MaterialLocalizations.of(context).formatMediumDate(status.lastSyncTime!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(status.lastSyncTime!.toLocal()))}',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
            ),
            if (syncing) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.xs),
              Text('Syncing…', style: textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: syncing ? null : () => _syncProvider(provider),
                icon: const Icon(Icons.sync),
                label: Text('Sync now'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  textStyle: _actionTextStyle(context, AppColors.onPrimary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _manageSettings(provider),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.primary,
                      textStyle: _actionTextStyle(context, AppColors.primary),
                    ),
                    child: Text('Manage settings'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _disconnect(provider),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      textStyle: _actionTextStyle(context, AppColors.error),
                    ),
                    child: Text('Disconnect'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              provider == CalendarProvider.canvas
                  ? 'Enter your institution’s Canvas site. You will sign in securely on Canvas.'
                  : 'Sign in securely with ${provider.title}. Momentum only reads calendar data.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurface),
            ),
            if (provider == CalendarProvider.canvas) ...[
              const SizedBox(height: AppSpacing.xs),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadii.popup),
                ),
                child: SizedBox(
                  height: AppSpacing.popupFieldHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 24,
                        child: TextField(
                          controller: _canvasSiteController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          textAlignVertical: TextAlignVertical.center,
                          style: _fieldTextStyle(context),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Canvas site URL',
                            hintStyle: _fieldHintStyle(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(
              height: provider == CalendarProvider.canvas
                  ? AppSpacing.xs
                  : AppSpacing.md,
            ),
            SizedBox(
              height: 48,
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
                      ? 'Connecting…'
                      : 'Connect with ${provider.title}',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  textStyle: _actionTextStyle(context, AppColors.onPrimary),
                ),
              ),
            ),
          ],
          if (_message != null || _error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error ?? _message!,
              style: textTheme.bodyMedium?.copyWith(
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

  String? _normalizeCanvasUrl(String value) {
    var input = value.trim();
    if (input.isEmpty) return null;
    if (!input.contains('://')) input = 'https://$input';
    final uri = Uri.tryParse(input);
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https') return null;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  String _readableError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');

  static CalendarProvider? _providerFromKey(String? key) => CalendarProvider
      .values
      .where((provider) => provider.key == key)
      .firstOrNull;

  static String _routeFor(CalendarProvider provider) => switch (provider) {
    CalendarProvider.canvas => '/canvas',
    CalendarProvider.googleCalendar => '/google',
    CalendarProvider.outlook => '/outlook',
  };

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
