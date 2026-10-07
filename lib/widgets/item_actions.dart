import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../data_models.dart';
import '../state/planner_state.dart';
import 'add_item_popup.dart';
import 'blurred_dialog.dart';

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
          ).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
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
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
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
