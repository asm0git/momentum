import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'blurred_dialog.dart';
import 'calendar/calendar.dart';

Future<DateTime?> showAppDatePickerDialog(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? minimumDate,
}) {
  final minimum = minimumDate == null ? null : DateUtils.dateOnly(minimumDate);
  final initial = DateUtils.dateOnly(initialDate);
  final clampedInitial = minimum != null && initial.isBefore(minimum)
      ? minimum
      : initial;
  return showBlurredDialog<DateTime>(
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
          initialDate: clampedInitial,
          minimumDate: minimum,
          compact: true,
          onDateSelected: (selectedDate) {
            Navigator.of(dialogContext).pop(selectedDate);
          },
        ),
      ),
    ),
  );
}
