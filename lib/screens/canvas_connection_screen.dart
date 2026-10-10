import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../services/canvas_oauth_redirect_stub.dart'
    if (dart.library.js_interop) '../services/canvas_oauth_redirect_web.dart'
    as oauth;
import '../state/planner_state.dart';
import '../widgets/blurred_dialog.dart';

class CanvasConnectionScreen extends StatefulWidget {
  const CanvasConnectionScreen({super.key});

  @override
  State<CanvasConnectionScreen> createState() => _CanvasConnectionScreenState();
}

class _CanvasConnectionScreenState extends State<CanvasConnectionScreen> {
  final _siteController = TextEditingController();
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
    _siteController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadConnection() async {
    final planner = context.read<PlannerState>();
    final queryError = Uri.base.queryParameters['canvas_error'];
    setState(() {
      _error = queryError == null
          ? null
          : queryError == 'authorization_cancelled'
          ? 'Canvas authorization was canceled.'
          : 'Canvas authorization did not finish. Please try again.';
    });
    try {
      final status = await planner.refreshCanvasStatus();
      if (!mounted) return;
      _siteController.text = status.providerUrl ?? '';
      final account = planner.canvasAccount;
      final category = account?.categoryId == null
          ? null
          : planner.categories
                .where((item) => item.id == account!.categoryId)
                .firstOrNull;
      _categoryController.text = category?.title ?? 'Canvas';
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

  Future<void> _connect() async {
    final siteUrl = _normalizeInputUrl(_siteController.text);
    if (siteUrl == null) {
      setState(() => _error = 'Enter a valid Canvas site URL.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final uri = context.read<PlannerState>().canvasOAuthStartUri(siteUrl);
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
      await context.read<PlannerState>().syncCanvas();
      if (!mounted) return;
      final status = context.read<PlannerState>().canvasConnectionStatus;
      setState(() {
        _message = 'Sync complete.';
        _siteController.text = status?.providerUrl ?? _siteController.text;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    }
  }

  Future<void> _saveCategoryName() async {
    final planner = context.read<PlannerState>();
    final account = planner.canvasAccount;
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
      setState(() => _error = 'The Canvas category could not be found.');
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
    final shouldDisconnect = await showBlurredDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDisconnectDialog(
        onCancel: () => Navigator.pop(context, false),
        onDisconnect: () => Navigator.pop(context, true),
      ),
    );
    if (shouldDisconnect != true || !mounted) return;
    setState(() {
      _error = null;
      _message = null;
    });
    try {
      await context.read<PlannerState>().disconnectCanvas();
      if (mounted) {
        setState(() {
          _siteController.clear();
          _categoryController.text = 'Canvas';
          _message = 'Canvas disconnected. Imported items remain in Momentum.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerState>();
    final status = planner.canvasConnectionStatus;
    final connected = status?.connected == true;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: Text('Canvas', style: textTheme.headlineLarge),
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
                  connected ? 'Canvas account' : 'Link your Canvas account',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  connected
                      ? '${status?.accountName ?? 'Connected'}${status?.accountEmail == null ? '' : '\n${status!.accountEmail}'}'
                      : 'Enter your institution’s Canvas site. You will sign in securely on Canvas.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!connected) ...[
                  TextField(
                    controller: _siteController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: _decoration(context, 'Canvas site URL'),
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: AppSpacing.popupFieldHeight,
                    child: FilledButton(
                      onPressed: _connecting ? null : _connect,
                      child: _connecting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Connect with Canvas',
                              style: textTheme.labelMedium?.copyWith(
                                color: AppColors.onPrimary,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Canvas category',
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
                  if (status?.lastSyncTime != null)
                    Text(
                      'Last synced ${MaterialLocalizations.of(context).formatMediumDate(status!.lastSyncTime!.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(status.lastSyncTime!.toLocal()))}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurface,
                      ),
                    )
                  else
                    Text(
                      'Not synced yet',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  if (planner.isCanvasSyncing) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Syncing Canvas…', style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: AppSpacing.popupFieldHeight,
                    child: FilledButton.icon(
                      onPressed: planner.isCanvasSyncing ? null : _sync,
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
                      onPressed: planner.isCanvasSyncing ? null : _disconnect,
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

  String? _normalizeInputUrl(String value) {
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
}

class _ConfirmDisconnectDialog extends StatelessWidget {
  const _ConfirmDisconnectDialog({
    required this.onCancel,
    required this.onDisconnect,
  });

  final VoidCallback onCancel;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Disconnect Canvas?', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Imported tasks and events will remain in Momentum.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text('Cancel', style: textTheme.labelMedium),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton(
                    onPressed: onDisconnect,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    child: Text(
                      'Disconnect',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
