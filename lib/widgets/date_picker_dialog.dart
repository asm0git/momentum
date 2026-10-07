import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'calendar.dart';

Future<DateTime?> showAppDatePickerDialog(
  BuildContext context, {
  required DateTime initialDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: CalendarWidget(
          initialDate: initialDate,
          compact: true,
          onDateSelected: (selectedDate) {
            Navigator.of(dialogContext).pop(selectedDate);
          },
        ),
      ),
    ),
  );
}
