import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data_models.dart';
import '../state/planner_state.dart';
import 'add_item_popup.dart';

Future<void> showItemEditor(BuildContext context, PlannerItem item) async {
  await showDialog<void>(
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete item?'),
      content: Text('Delete “${item.title}”? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
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
