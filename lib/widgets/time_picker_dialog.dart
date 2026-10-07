import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'blurred_dialog.dart';

Future<TimeOfDay?> showAppTimePickerDialog(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  const checkIcon = Icons.check;
  return showBlurredDialog<TimeOfDay>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final timePickerTheme = theme.timePickerTheme;
      return TimePickerTheme(
        data: timePickerTheme.copyWith(
          hourMinuteShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.base * 12),
          ),
          confirmButtonStyle: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(AppColors.primary),
            foregroundColor: const WidgetStatePropertyAll(AppColors.onPrimary),
            fixedSize: const WidgetStatePropertyAll(Size(48, 48)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            shape: const WidgetStatePropertyAll(CircleBorder()),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: WidgetStatePropertyAll(
              theme.textTheme.bodyLarge!.copyWith(fontFamily: 'MaterialIcons'),
            ),
          ),
          dayPeriodShape: const StadiumBorder(),
          dayPeriodBorderSide: BorderSide.none,
          dayPeriodColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surface,
          ),
          dayPeriodTextColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.onPrimary
                : AppColors.onSurface,
          ),
        ),
        child: TimePickerDialog(
          initialTime: initialTime,
          confirmText: String.fromCharCode(checkIcon.codePoint),
        ),
      );
    },
  );
}
