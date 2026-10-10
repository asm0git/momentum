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

class CalendarProviderConnectionScreen extends StatefulWidget {
  const CalendarProviderConnectionScreen({super.key, required this.provider});

  final CalendarProvider provider;

  @override
  State<CalendarProviderConnectionScreen> createState() =>
      _CalendarProviderConnectionScreenState();
}

class _CalendarProviderConnectionScreenState
    extends State<CalendarProviderConnectionScreen> {
  final _categoryController = TextEditingController();
  bool _loading = true;
  bool _connecting = false;
  bool _savingCategory = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConnection());
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadConnection() async {
    try {
      final planner = context.read<PlannerState>();
      final status = await planner.refreshProviderStatus(widget.provider);
      if (!mounted) return;
      _categoryController.text = _categoryFor(planner) ?? widget.provider.title;
      final account = planner.accountForProvider(widget.provider);
      final accountChanged =
          account == null ||
          (status.remoteUserId != null &&
              account.remoteUserId != status.remoteUserId) ||
          (status.providerUrl != null &&
              account.providerUrl != status.providerUrl);
      if (status.connected &&
          (accountChanged ||
              account.lastSyncTime == null ||
              status.lastSyncTime == null ||
              DateTime.now().difference(status.lastSyncTime!) >=
                  const Duration(minutes: 15))) {
        await _sync();
      }
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _categoryFor(PlannerState planner) {
    final account = planner.accountForProvider(widget.provider);
    final categoryId = account?.categoryId;
    if (categoryId == null) return null;
    return planner.categories
        .where((category) => category.id == categoryId)
        .firstOrNull
        ?.title;
  }

  void _connect() {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final uri = context.read<PlannerState>().providerOAuthStartUri(
        widget.provider,
      );
      oauth.redirectToCanvasOAuth(uri.toString());
    } catch (error) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = _readableError(error);
        });
      }
    }
  }

  Future<void> _sync() async {
    setState(() {
      _message = null;
      _error = null;
    });
    try {
      await context.read<PlannerState>().syncProvider(widget.provider);
      if (mounted) setState(() => _message = 'Sync complete.');
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    }
  }

  Future<void> _replaceImportedItems() async {
    final confirmed = await showBlurredDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Replace imported items?',
          style: Theme.of(dialogContext).textTheme.titleMedium,
        ),
        content: Text(
          'Momentum will remove this provider\'s imported items, then import the current calendar again. Your own tasks and events, and items from other calendars, will stay. This does not change the calendar itself.',
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace and sync'),
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
      await context.read<PlannerState>().syncProvider(
        widget.provider,
        replaceExistingImports: true,
      );
      if (mounted) setState(() => _message = 'Imported items replaced.');
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    }
  }

  Future<void> _saveCategoryName() async {
    final planner = context.read<PlannerState>();
    final account = planner.accountForProvider(widget.provider);
    final categoryId = account?.categoryId;
    final title = _categoryController.text.trim();
    if (categoryId == null || title.isEmpty) {
      setState(() => _error = 'Enter a category name before saving.');
      return;
    }
    final category = planner.categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    if (category == null) {
      setState(() => _error = 'The calendar category could not be found.');
      return;
    }
    setState(() {
      _savingCategory = true;
      _error = null;
      _message = null;
    });
    try {
      category.title = title;
      await planner.updateCategory(category);
      if (mounted) setState(() => _message = 'Category name saved.');
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    } finally {
      if (mounted) setState(() => _savingCategory = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showBlurredDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Disconnect ${widget.provider.title}?',
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
    try {
      await context.read<PlannerState>().disconnectProvider(widget.provider);
      if (mounted) {
        _categoryController.text = widget.provider.title;
        setState(() => _message = 'Disconnected. Imported items remain.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    }
  }

  Future<void> _backToSetup() async {
    final complete = await OnboardingPreferences.isComplete();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed('/calendars', arguments: !complete);
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final status = planner.statusForProvider(widget.provider);
    final connected = status?.connected == true;
    final syncing = planner.isProviderSyncing(widget.provider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.provider.title, style: textTheme.headlineLarge),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppRadii.appBarBottom),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.screenEdgePadding),
              children: [
                Text(
                  connected
                      ? '${widget.provider.title} account'
                      : 'Link your ${widget.provider.title} account',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  connected
                      ? '${status?.accountName ?? 'Connected'}${status?.accountEmail == null ? '' : '\n${status!.accountEmail}'}'
                      : 'Sign in securely with ${widget.provider.title}. Momentum only reads calendar data.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                if (!connected) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: AppSpacing.popupFieldHeight,
                    child: FilledButton.icon(
                      onPressed: _connecting ? null : _connect,
                      icon: const Icon(Icons.link),
                      label: Text(
                        'Connect with ${widget.provider.title}',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${widget.provider.title} category',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _categoryController,
                          decoration: _decoration(context, 'Category name'),
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.filled(
                        tooltip: 'Save category name',
                        onPressed: _savingCategory ? null : _saveCategoryName,
                        icon: _savingCategory
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    status?.lastSyncTime == null
                        ? 'Not synced yet'
                        : 'Last synced ${MaterialLocalizations.of(context).formatMediumDate(status!.lastSyncTime!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(status.lastSyncTime!.toLocal()))}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  if (syncing) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Syncing…', style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: AppSpacing.popupFieldHeight,
                    child: FilledButton.icon(
                      onPressed: syncing ? null : _sync,
                      icon: const Icon(Icons.sync),
                      label: Text(
                        'Sync now',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: AppSpacing.popupFieldHeight,
                    child: OutlinedButton.icon(
                      onPressed: syncing ? null : _replaceImportedItems,
                      icon: const Icon(Icons.sync_alt),
                      label: Text(
                        'Replace imported items',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: AppSpacing.popupFieldHeight,
                    child: OutlinedButton.icon(
                      onPressed: syncing ? null : _disconnect,
                      icon: const Icon(Icons.link_off),
                      label: Text(
                        'Disconnect',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _message!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: _backToSetup,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to calendars'),
                ),
              ],
            ),
    );
  }

  InputDecoration _decoration(BuildContext context, String hint) =>
      InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.focusPreset),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.focusPreset),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.focusPreset),
          borderSide: const BorderSide(color: AppColors.secondary),
        ),
        hintStyle: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.disabled),
      );

  String _readableError(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
