import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../services/onboarding_preferences.dart';
import '../state/planner_state.dart';
import '../widgets/blurred_dialog.dart';
import '../widgets/circular_icon_button.dart';
import '../widgets/primary_app_bar.dart';

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
      await planner.refreshProviderStatus(widget.provider);
      if (!mounted) return;
      _categoryController.text = _categoryFor(planner) ?? widget.provider.title;
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _categoryFor(PlannerState planner) {
    final categoryId = planner.accountForProvider(widget.provider)?.categoryId;
    if (categoryId == null) return null;
    return planner.categories
        .where((category) => category.id == categoryId)
        .firstOrNull
        ?.title;
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
          'Momentum will remove this provider’s imported items, then import the current calendar again. Your own tasks and events, and items from other calendars, will stay. This does not change the calendar itself.',
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
    final categoryId = planner.accountForProvider(widget.provider)?.categoryId;
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

  Future<void> _backToSetup() async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    final complete = await OnboardingPreferences.isComplete();
    if (!mounted) return;
    navigator.pushReplacementNamed('/calendars', arguments: !complete);
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final status = planner.statusForProvider(widget.provider);
    final connected = status?.connected == true;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PrimaryAppBar.withTitle(
        title: widget.provider.title,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: AppSpacing.addIconSize + AppSpacing.md * 2 + AppSpacing.xs,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenEdgePadding,
              0,
              AppSpacing.screenEdgePadding,
              AppSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CircularIconButton(
                backgroundColor: AppColors.secondary,
                icon: Icons.chevron_left,
                onPressed: _backToSetup,
                tooltip: 'Back to calendars',
              ),
            ),
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
                      ? '${widget.provider.title} settings'
                      : '${widget.provider.title} is not connected',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  connected
                      ? '${status?.accountName ?? 'Connected'}${status?.accountEmail == null ? '' : '\n${status!.accountEmail}'}'
                      : 'Connect ${widget.provider.title} from the Add calendars screen.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                if (connected) ...[
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
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: AppSpacing.popupFieldHeight,
                    child: OutlinedButton.icon(
                      onPressed: _replaceImportedItems,
                      icon: const Icon(Icons.sync_alt),
                      label: Text(
                        'Replace imported items',
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
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
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
