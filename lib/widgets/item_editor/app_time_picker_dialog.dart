import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import 'time_picker_dial.dart';

/// A Material-style time picker that validates before returning its selection.
class AppTimePickerDialog extends StatefulWidget {
  const AppTimePickerDialog({
    super.key,
    required this.initialTime,
    this.validateSelection,
  });

  final TimeOfDay initialTime;
  final String? Function(TimeOfDay time)? validateSelection;

  @override
  State<AppTimePickerDialog> createState() => _AppTimePickerDialogState();
}

class _AppTimePickerDialogState extends State<AppTimePickerDialog> {
  late TimeOfDay _time = widget.initialTime;
  final _hourController = TextEditingController();
  final _minuteController = TextEditingController();
  final _hourFocus = FocusNode();
  final _minuteFocus = FocusNode();
  bool _inputMode = false;
  bool _selectingHour = true;
  String? _error;

  bool get _use24Hours =>
      MediaQuery.alwaysUse24HourFormatOf(context) ||
      hourFormat(of: MaterialLocalizations.of(context).timeOfDayFormat()) !=
          HourFormat.h;

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _changeTime(TimeOfDay value) {
    setState(() {
      _time = value;
      // Only revalidate after a confirmation has exposed an error.
      if (_error != null) _error = widget.validateSelection?.call(value);
    });
  }

  TimeOfDay? _readInput() {
    final hour = int.tryParse(_hourController.text);
    final minute = int.tryParse(_minuteController.text);
    if (hour == null || minute == null || minute < 0 || minute > 59) {
      return null;
    }
    if (_use24Hours) {
      if (hour < 0 || hour > 23) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }
    if (hour < 1 || hour > 12) return null;
    return TimeOfDay(
      hour: hour % 12 + (_time.period == DayPeriod.pm ? 12 : 0),
      minute: minute,
    );
  }

  void _inputChanged(String _) {
    final value = _readInput();
    if (value != null) {
      _changeTime(value);
    } else if (_error != null) {
      setState(
        () => _error = MaterialLocalizations.of(context).invalidTimeLabel,
      );
    }
  }

  void _toggleEntryMode() {
    if (_inputMode) {
      final value = _readInput();
      if (value == null) {
        setState(
          () => _error = MaterialLocalizations.of(context).invalidTimeLabel,
        );
        return;
      }
      _changeTime(value);
    } else {
      _hourController.text = (_use24Hours ? _time.hour : _displayHour)
          .toString()
          .padLeft(2, '0');
      _minuteController.text = _time.minute.toString().padLeft(2, '0');
    }
    setState(() => _inputMode = !_inputMode);
    if (_inputMode) {
      _hourFocus.requestFocus();
    } else {
      _hourFocus.unfocus();
      _minuteFocus.unfocus();
    }
  }

  int get _displayHour => _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;

  void _confirm() {
    final selected = _inputMode ? _readInput() : _time;
    final error = selected == null
        ? MaterialLocalizations.of(context).invalidTimeLabel
        : widget.validateSelection?.call(selected);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(selected);
  }

  void _changePeriod(DayPeriod period) {
    final value = _time.replacing(
      hour: _time.hourOfPeriod + (period == DayPeriod.pm ? 12 : 0),
    );
    if (!_inputMode) {
      _changeTime(value);
      return;
    }
    setState(() {
      _time = value;
      final enteredTime = _readInput();
      if (enteredTime != null) _time = enteredTime;
      if (_error != null) {
        _error = enteredTime == null
            ? MaterialLocalizations.of(context).invalidTimeLabel
            : widget.validateSelection?.call(enteredTime);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pickerTheme = TimePickerTheme.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Dialog(
      backgroundColor:
          pickerTheme.backgroundColor ?? theme.colorScheme.surfaceContainerHigh,
      elevation: pickerTheme.elevation ?? 6,
      shape:
          pickerTheme.shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.popup),
          ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: pickerTheme.padding ?? const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: 310,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.timePickerDialHelpText,
                  key: const ValueKey('time-picker-heading'),
                  style: theme.textTheme.titleMedium,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        key: const ValueKey('time-picker-error'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                _buildTimeFields(theme, pickerTheme, localizations),
                if (!_inputMode) ...[
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: SizedBox.square(
                      key: const ValueKey('time-picker-dial-size'),
                      dimension: 256,
                      child: AppTimePickerDial(
                        time: _time,
                        selectingHour: _selectingHour,
                        use24Hours: _use24Hours,
                        onChanged: _changeTime,
                        onHourSelected: () =>
                            setState(() => _selectingHour = false),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('time-picker-entry-mode'),
                      tooltip: _inputMode
                          ? localizations.dialModeButtonLabel
                          : localizations.inputTimeModeButtonLabel,
                      onPressed: _toggleEntryMode,
                      icon: Icon(
                        _inputMode
                            ? Icons.access_time
                            : Icons.keyboard_outlined,
                      ),
                    ),
                    Expanded(
                      child: OverflowBar(
                        alignment: MainAxisAlignment.end,
                        overflowAlignment: OverflowBarAlignment.end,
                        spacing: AppSpacing.sm,
                        overflowSpacing: AppSpacing.sm,
                        children: [
                          TextButton(
                            key: const ValueKey('time-picker-cancel'),
                            style: pickerTheme.cancelButtonStyle,
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(localizations.cancelButtonLabel),
                          ),
                          IconButton(
                            key: const ValueKey('time-picker-confirm'),
                            tooltip: localizations.okButtonLabel,
                            style: pickerTheme.confirmButtonStyle,
                            onPressed: _confirm,
                            icon: const Icon(Icons.check),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFields(
    ThemeData theme,
    TimePickerThemeData pickerTheme,
    MaterialLocalizations localizations,
  ) => Row(
    key: const ValueKey('time-picker-controls'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _timeField(
          theme,
          pickerTheme,
          hour: true,
          label: localizations.timePickerHourLabel,
        ),
      ),
      SizedBox(
        width: AppSpacing.lg,
        height: 80,
        child: Center(child: Text(':', style: theme.textTheme.displayMedium)),
      ),
      Expanded(
        child: _timeField(
          theme,
          pickerTheme,
          hour: false,
          label: localizations.timePickerMinuteLabel,
        ),
      ),
      if (!_use24Hours) ...[
        const SizedBox(width: AppSpacing.base * 1.5),
        SizedBox(
          width: AppSpacing.base * 8,
          height: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final period in DayPeriod.values)
                Expanded(
                  child: TextButton(
                    key: ValueKey('time-picker-${period.name}'),
                    onPressed: () => _changePeriod(period),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      backgroundColor: _time.period == period
                          ? AppColors.primary
                          : AppColors.surface,
                      foregroundColor: _time.period == period
                          ? AppColors.onPrimary
                          : AppColors.onSurface,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      period == DayPeriod.am
                          ? localizations.anteMeridiemAbbreviation
                          : localizations.postMeridiemAbbreviation,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _timeField(
    ThemeData theme,
    TimePickerThemeData pickerTheme, {
    required bool hour,
    required String label,
  }) {
    final selected = _inputMode || hour == _selectingHour;
    final states = selected ? {WidgetState.selected} : <WidgetState>{};
    final color = pickerTheme.hourMinuteColor;
    final foreground = pickerTheme.hourMinuteTextColor;
    final fill = color == null
        ? (selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest)
        : WidgetStateProperty.resolveAs<Color>(color, states);
    final textColor = foreground == null
        ? (selected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurface)
        : WidgetStateProperty.resolveAs<Color>(foreground, states);
    final textStyle =
        (pickerTheme.hourMinuteTextStyle ??
                (_inputMode
                    ? theme.textTheme.displayMedium
                    : theme.textTheme.displayLarge))
            ?.copyWith(color: textColor);
    final value = hour
        ? (_use24Hours ? _time.hour : _displayHour).toString().padLeft(2, '0')
        : _time.minute.toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: fill,
          shape:
              pickerTheme.hourMinuteShape ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.base * 12),
              ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 80,
            child: _inputMode
                ? Center(
                    child: TextField(
                      key: ValueKey(
                        'time-picker-${hour ? 'hour' : 'minute'}-input',
                      ),
                      controller: hour ? _hourController : _minuteController,
                      focusNode: hour ? _hourFocus : _minuteFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: hour
                          ? TextInputAction.next
                          : TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      textAlign: TextAlign.center,
                      style: textStyle,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        hintText: hour ? 'HH' : 'MM',
                      ),
                      onChanged: _inputChanged,
                      onSubmitted: (_) {
                        if (hour) {
                          _minuteFocus.requestFocus();
                        } else {
                          _confirm();
                        }
                      },
                    ),
                  )
                : InkWell(
                    key: ValueKey(
                      'time-picker-${hour ? 'hour' : 'minute'}-select',
                    ),
                    onTap: () => setState(() => _selectingHour = hour),
                    child: Semantics(
                      label: label,
                      button: true,
                      selected: selected,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(value, style: textStyle),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (_inputMode) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
