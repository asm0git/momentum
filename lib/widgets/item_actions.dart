import 'package:flutter/material.dart';
import 'package:provider/provider.dart' hide Selector;

import '../app_theme.dart';
import '../data_models.dart';
import '../state/planner_state.dart';
import 'add_item_popup.dart';
import 'blurred_dialog.dart';
import 'confirmation_dialog_actions.dart';
import 'selector.dart';

Future<void> showItemEditor(BuildContext context, PlannerItem item) async {
  await showBlurredDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: AddItemPopup(
          initialItem: item,
          onCancel: () => Navigator.of(dialogContext).pop(),
          onSaved: (_) => Navigator.of(dialogContext).pop(),
        ),
      ),
    ),
  );
}

Future<void> confirmDeleteItem(BuildContext context, PlannerItem item) async {
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
        title: Text(
          'Delete item?',
          style: Theme.of(
            dialogContext,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.primary),
        ),
        content: Text(
          'Delete “${item.title}”? This cannot be undone.',
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
              actionLabel: 'Delete',
              onCancel: () => Navigator.pop(dialogContext, false),
              onAction: () => Navigator.pop(dialogContext, true),
              actionColor: AppColors.error,
            ),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await context.read<PlannerState>().deleteItem(item);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this item.')),
      );
    }
  }
}

Future<void> confirmDeleteCategory(
  BuildContext context,
  TaskCategory category,
  List<TaskCategory> categories,
) async {
  final categoryId = category.id;
  if (categoryId == null) return;

  final choice = await showBlurredDialog<_CategoryDeleteChoice>(
    context: context,
    builder: (dialogContext) => _DeleteCategoryDialog(
      category: category,
      destinations: categories
          .where((candidate) => candidate.id != categoryId)
          .toList(),
    ),
  );
  if (choice == null || !context.mounted) return;

  try {
    await context.read<PlannerState>().deleteCategory(
      categoryId,
      disposition: choice.disposition,
      destinationCategoryId: choice.destinationCategoryId,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this category.')),
      );
    }
  }
}

class _CategoryDeleteChoice {
  const _CategoryDeleteChoice({
    required this.disposition,
    this.destinationCategoryId,
  });

  final CategoryDeleteDisposition disposition;
  final int? destinationCategoryId;
}

class _DeleteCategoryDialog extends StatefulWidget {
  const _DeleteCategoryDialog({
    required this.category,
    required this.destinations,
  });

  final TaskCategory category;
  final List<TaskCategory> destinations;

  @override
  State<_DeleteCategoryDialog> createState() => _DeleteCategoryDialogState();
}

class _DeleteCategoryDialogState extends State<_DeleteCategoryDialog> {
  CategoryDeleteDisposition? _disposition;
  int? _destinationCategoryId;

  bool get _hasItems => widget.category.items.isNotEmpty;

  bool get _canSubmit {
    if (!_hasItems) return true;
    if (_disposition == CategoryDeleteDisposition.deleteItems) return true;
    return _disposition == CategoryDeleteDisposition.moveItems &&
        _destinationCategoryId != null;
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = (MediaQuery.sizeOf(context).width - 32)
        .clamp(280.0, 400.0)
        .toDouble();
    final textTheme = Theme.of(context).textTheme;
    final tasks = widget.category.items.whereType<Task>().length;
    final events = widget.category.items.whereType<Event>().length;
    final itemSummary = [
      if (tasks > 0) '$tasks ${tasks == 1 ? 'task' : 'tasks'}',
      if (events > 0) '$events ${events == 1 ? 'event' : 'events'}',
    ].join(' and ');
    final isMovingItems = _disposition == CategoryDeleteDisposition.moveItems;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: SizedBox(
        width: dialogWidth,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.xs,
            left: AppSpacing.md,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Delete category?',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _hasItems
                      ? '“${widget.category.title}” contains $itemSummary. '
                            'Choose what happens to these items.'
                      : 'Delete “${widget.category.title}”? '
                            'This cannot be undone.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                if (_hasItems) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _CategoryDispositionTile(
                    key: const ValueKey('delete-category-items'),
                    selected:
                        _disposition == CategoryDeleteDisposition.deleteItems,
                    title: 'Delete all items',
                    description: 'Permanently delete $itemSummary.',
                    selectedColor: AppColors.error,
                    onTap: () => setState(() {
                      _disposition = CategoryDeleteDisposition.deleteItems;
                      _destinationCategoryId = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _CategoryDispositionTile(
                    key: const ValueKey('move-category-items'),
                    selected:
                        _disposition == CategoryDeleteDisposition.moveItems,
                    title: 'Move items to another category',
                    description: widget.destinations.isEmpty
                        ? 'No other categories are available.'
                        : 'Keep the items by choosing a destination.',
                    onTap: widget.destinations.isEmpty
                        ? null
                        : () => setState(() {
                            _disposition = CategoryDeleteDisposition.moveItems;
                            _destinationCategoryId = null;
                          }),
                  ),
                  if (_disposition == CategoryDeleteDisposition.moveItems &&
                      widget.destinations.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.popup),
                      ),
                      child: SizedBox(
                        height: AppSpacing.popupFieldHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.md,
                            right: AppSpacing.sm,
                          ),
                          child: Selector(
                            options: [
                              for (final destination in widget.destinations)
                                SelectorOption(
                                  value: destination.id?.toString(),
                                  label: destination.title,
                                  iconName: destination.iconName,
                                ),
                            ],
                            selectedValue: _destinationCategoryId?.toString(),
                            placeholder: 'Choose a category',
                            isExpanded: true,
                            contentColor: AppColors.secondary,
                            onChanged: (value) => setState(
                              () => _destinationCategoryId = int.tryParse(
                                value ?? '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.md),
                DialogActionButtons(
                  cancelLabel: 'Cancel',
                  actionLabel: !_hasItems
                      ? 'Delete category'
                      : isMovingItems
                      ? 'Move & delete'
                      : 'Delete all',
                  onCancel: () => Navigator.pop(context),
                  onAction: _canSubmit
                      ? () {
                          final disposition = _hasItems
                              ? _disposition!
                              : CategoryDeleteDisposition.deleteItems;
                          Navigator.pop(
                            context,
                            _CategoryDeleteChoice(
                              disposition: disposition,
                              destinationCategoryId: _destinationCategoryId,
                            ),
                          );
                        }
                      : null,
                  actionColor: isMovingItems
                      ? AppColors.primary
                      : AppColors.error,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryDispositionTile extends StatelessWidget {
  const _CategoryDispositionTile({
    super.key,
    required this.selected,
    required this.title,
    required this.description,
    this.selectedColor,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String description;
  final Color? selectedColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = onTap == null ? AppColors.disabled : AppColors.primary;
    final isSelectedColor = selected && selectedColor != null;
    final foregroundColor = isSelectedColor ? AppColors.onPrimary : color;

    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: '$title. $description',
      child: Material(
        color: isSelectedColor ? selectedColor : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.popup),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelectedColor ? AppColors.onPrimary : color,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.bodyMedium?.copyWith(
                          color: foregroundColor,
                        ),
                      ),
                      Text(
                        description,
                        style: textTheme.labelSmall?.copyWith(
                          color: isSelectedColor
                              ? AppColors.onPrimary
                              : AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
