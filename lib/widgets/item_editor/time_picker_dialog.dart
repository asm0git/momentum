import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../blurred_dialog.dart';
import 'app_time_picker_dialog.dart';

export 'app_time_picker_dialog.dart' show AppTimePickerDialog;

Future<TimeOfDay?> showAppTimePickerDialog(
  BuildContext context, {
  required TimeOfDay initialTime,
  TimeOfDay? minimumTime,
  String? Function(TimeOfDay time)? validateSelection,
}) async {
  final initialMinutes = initialTime.hour * 60 + initialTime.minute;
  final minimumMinutes = minimumTime == null
      ? null
      : minimumTime.hour * 60 + minimumTime.minute;
  final clampedInitialTime =
      minimumMinutes != null && initialMinutes < minimumMinutes
      ? minimumTime!
      : initialTime;
  final selected = await showBlurredDialog<TimeOfDay>(
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
        child: AppTimePickerDialog(
          initialTime: clampedInitialTime,
          validateSelection: validateSelection,
        ),
      );
    },
  );
  if (selected == null || minimumTime == null) return selected;

  final selectedMinutes = selected.hour * 60 + selected.minute;
  return selectedMinutes < minimumMinutes! ? minimumTime : selected;
}
