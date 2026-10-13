import 'package:flutter/material.dart';
import 'package:provider/provider.dart' hide Selector;

import '../../app_theme.dart';
import '../../data_models.dart';
import '../../state/planner_state.dart';
import '../blurred_dialog.dart';
import 'date_picker_dialog.dart';
import 'estimated_duration_picker.dart';
import '../category_icon_picker.dart';
import '../planner/planner_write_feedback.dart';
import '../selector.dart';
import 'time_picker_dialog.dart';

enum _PopupItemType { event, task }

String _repeatLabel(RecurrenceRule rule) => switch (rule) {
  RecurrenceRule.never => 'Never',
  RecurrenceRule.daily => 'Every day',
  RecurrenceRule.weekly => 'Every week',
  RecurrenceRule.monthly => 'Every month',
  RecurrenceRule.yearly => 'Every year',
};

const _newCategoryValue = '__new_category__';
const _noneCategoryValue = '__none_category__';

Future<TaskCategory?> showNewCategoryDialog(BuildContext context) =>
    showBlurredDialog<TaskCategory>(
      context: context,
      builder: (context) => const _NewCategoryDialog(),
    );

class AddItemPopup extends StatefulWidget {
  const AddItemPopup({
    super.key,
    this.initialItem,
    this.onSaved,
    this.onCancel,
  });

  final PlannerItem? initialItem;
  final ValueChanged<PlannerItem>? onSaved;
  final VoidCallback? onCancel;

  @override
  State<AddItemPopup> createState() => _AddItemPopupState();
}

class _AddItemPopupState extends State<AddItemPopup> {
  _PopupItemType _selectedType = _PopupItemType.event;
  final _titleController = TextEditingController();
  final _eventNotesController = TextEditingController();
  final _notesController = TextEditingController();
  int? _selectedCategoryId;
  bool _allDay = false;
  DateTime _taskDeadline = DateTime.now();
  TimeOfDay _taskDeadlineTime = const TimeOfDay(hour: 9, minute: 0);
  Duration _taskEstimatedDuration = const Duration(hours: 1);
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  RecurrenceRule _repeat = RecurrenceRule.never;
  DateTime? _repeatUntil;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item == null) return;
    _titleController.text = item.title;
    _selectedCategoryId = item.categoryId;
    if (item is Task) {
      _selectedType = _PopupItemType.task;
      _taskDeadline = item.date;
      _taskDeadlineTime = item.time;
      _taskEstimatedDuration = item.estimatedDuration;
      _repeat = item.repeat;
      _repeatUntil = item.repeatUntil;
      _notesController.text = item.description;
    } else if (item is Event) {
      _selectedType = _PopupItemType.event;
      _allDay = item.allDay;
      _startDate = item.date;
      _startTime = item.start;
      _endDate = item.endDate;
      _endTime = item.end;
      _repeat = item.repeat;
      _repeatUntil = item.repeatUntil;
      _eventNotesController.text = item.notes;
      if (!_allDay) _normalizeEndDateTime();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _eventNotesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setAllDay(bool value) {
    setState(() {
      _allDay = value;
      if (value) {
        _endDate = _dateOnly(_startDate);
      } else {
        _normalizeEndDateTime();
      }
    });
  }

  void _setAllDayDate(DateTime value) {
    setState(() {
      _startDate = _dateOnly(value);
      _endDate = _startDate;
      _clampRepeatUntil(_startDate);
    });
  }

  void _setStartDate(DateTime value) {
    setState(() {
      _startDate = _dateOnly(value);
      _clampRepeatUntil(_startDate);
      if (_dateOnly(_endDate).isBefore(_startDate)) _endDate = _startDate;
      _normalizeEndDateTime();
    });
  }

  void _setStartTime(TimeOfDay value) {
    setState(() {
      _startTime = value;
      _normalizeEndDateTime();
    });
  }

  void _setEndDate(DateTime value) {
    setState(() {
      final selectedDate = _dateOnly(value);
      _endDate = selectedDate.isBefore(_dateOnly(_startDate))
          ? _dateOnly(_startDate)
          : selectedDate;
      _normalizeEndDateTime();
    });
  }

  void _setEndTime(TimeOfDay value) {
    setState(() {
      _endTime = value;
      _normalizeEndDateTime();
    });
  }

  void _setTaskDeadline(DateTime value) {
    setState(() {
      _taskDeadline = _dateOnly(value);
      _clampRepeatUntil(_taskDeadline);
    });
  }

  void _setRepeat(RecurrenceRule value) {
    setState(() {
      _repeat = value;
      if (value == RecurrenceRule.never) _repeatUntil = null;
    });
  }

  void _setRepeatUntil(DateTime? value) {
    setState(() {
      _repeatUntil = value == null
          ? null
          : _dateOnly(
              value.isBefore(_repeatStartDate) ? _repeatStartDate : value,
            );
    });
  }

  void _clampRepeatUntil(DateTime repeatStart) {
    final until = _repeatUntil;
    if (until != null && _dateOnly(until).isBefore(repeatStart)) {
      _repeatUntil = repeatStart;
    }
  }

  DateTime get _repeatStartDate =>
      _selectedType == _PopupItemType.task ? _taskDeadline : _startDate;

  void _normalizeEndDateTime() {
    if (_allDay) return;

    final startsAt = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endsAt = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (!endsAt.isAfter(startsAt)) {
      final earliestEnd = startsAt.add(const Duration(minutes: 1));
      _endDate = _dateOnly(earliestEnd);
      _endTime = TimeOfDay.fromDateTime(earliestEnd);
    }
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.popup),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.initialItem == null)
              _ItemTypeSelector(
                selectedType: _selectedType,
                onTypeChanged: (type) => setState(() {
                  _selectedType = type;
                  _clampRepeatUntil(
                    type == _PopupItemType.task ? _taskDeadline : _startDate,
                  );
                  _validationMessage = null;
                }),
              ),
            const SizedBox(height: AppSpacing.sm),
            _TitleCategoryFields(
              titleController: _titleController,
              onTitleChanged: (_) {
                if (_validationMessage != null) {
                  setState(() => _validationMessage = null);
                }
              },
              selectedCategoryId: _selectedCategoryId,
              onCategoryChanged: (categoryId) => setState(() {
                _selectedCategoryId = categoryId;
                if (categoryId != null) _validationMessage = null;
              }),
            ),
            if (_selectedType == _PopupItemType.event) ...[
              const SizedBox(height: AppSpacing.sm),
              _EventFields(
                allDay: _allDay,
                onAllDayChanged: _setAllDay,
                startDate: _startDate,
                onAllDayDateChanged: _setAllDayDate,
                onStartDateChanged: _setStartDate,
                startTime: _startTime,
                onStartTimeChanged: _setStartTime,
                endDate: _endDate,
                onEndDateChanged: _setEndDate,
                endTime: _endTime,
                onEndTimeChanged: _setEndTime,
                repeat: _repeat,
                repeatUntil: _repeatUntil,
                onRepeatChanged: _setRepeat,
                onRepeatUntilChanged: _setRepeatUntil,
              ),
              const SizedBox(height: AppSpacing.sm),
              _NotesField(controller: _eventNotesController),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              _TaskFields(
                deadline: _taskDeadline,
                onDeadlineChanged: _setTaskDeadline,
                deadlineTime: _taskDeadlineTime,
                onDeadlineTimeChanged: (value) =>
                    setState(() => _taskDeadlineTime = value),
                estimatedDuration: _taskEstimatedDuration,
                onEstimatedDurationChanged: (value) =>
                    setState(() => _taskEstimatedDuration = value),
                repeat: _repeat,
                repeatUntil: _repeatUntil,
                onRepeatChanged: _setRepeat,
                onRepeatUntilChanged: _setRepeatUntil,
                notesController: _notesController,
              ),
            ],
            if (_validationMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _ValidationMessage(message: _validationMessage!),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      textStyle: _itemTypeTextStyle(context),
                    ),
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      textStyle: _itemTypeTextStyle(context),
                    ),
                    onPressed: _save,
                    child: Text(
                      widget.initialItem == null
                          ? 'Add ${_selectedType == _PopupItemType.task ? 'Task' : 'Event'}'
                          : 'Save changes',
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

  Future<void> _save() async {
    if (_validationMessage != null) {
      setState(() => _validationMessage = null);
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showValidationError('Enter a title.');
      return;
    }
    if (_selectedCategoryId == null) {
      _showValidationError('Select a category to continue.');
      return;
    }
    final state = context.read<PlannerState>();
    try {
      if (_selectedType == _PopupItemType.task) {
        final previous = widget.initialItem;
        final task = Task(
          id: previous is Task ? previous.id : null,
          categoryId: _selectedCategoryId,
          title: title,
          date: DateTime(
            _taskDeadline.year,
            _taskDeadline.month,
            _taskDeadline.day,
          ),
          time: _taskDeadlineTime,
          estimatedDuration: _taskEstimatedDuration,
          repeat: _repeat,
          repeatUntil: _repeatUntil,
          isChecked: previous is Task ? previous.isChecked : false,
          description: _notesController.text.trim(),
          priority: previous is Task ? previous.priority : null,
          sourcePlatform: previous is Task ? previous.sourcePlatform : null,
          externalId: previous is Task ? previous.externalId : null,
        );
        final saved = await state.saveTask(task);
        widget.onSaved?.call(saved);
        return;
      }

      _normalizeEndDateTime();
      final previous = widget.initialItem;
      final event = Event(
        id: previous is Event ? previous.id : null,
        categoryId: _selectedCategoryId,
        title: title,
        date: DateTime(_startDate.year, _startDate.month, _startDate.day),
        endDate: DateTime(_endDate.year, _endDate.month, _endDate.day),
        start: _allDay ? const TimeOfDay(hour: 0, minute: 0) : _startTime,
        end: _allDay ? const TimeOfDay(hour: 0, minute: 0) : _endTime,
        isCurrent: previous is Event ? previous.isCurrent : false,
        allDay: _allDay,
        location: previous is Event ? previous.location : null,
        notes: _eventNotesController.text.trim(),
        repeat: _repeat,
        repeatUntil: _repeatUntil,
        sourcePlatform: previous is Event ? previous.sourcePlatform : null,
        externalId: previous is Event ? previous.externalId : null,
      );
      final saved = await state.saveEvent(event);
      widget.onSaved?.call(saved);
    } catch (error) {
      debugPrint('Could not save planner item: $error');
      _showValidationError(
        plannerWriteFailureMessage(error, action: PlannerWriteAction.saveItem),
      );
    }
  }

  void _showValidationError(String message) {
    if (!mounted) return;
    setState(() => _validationMessage = message);
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.focusPreset),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventFields extends StatelessWidget {
  const _EventFields({
    required this.allDay,
    required this.onAllDayChanged,
    required this.startDate,
    required this.onAllDayDateChanged,
    required this.onStartDateChanged,
    required this.startTime,
    required this.onStartTimeChanged,
    required this.endDate,
    required this.onEndDateChanged,
    required this.endTime,
    required this.onEndTimeChanged,
    required this.repeat,
    required this.repeatUntil,
    required this.onRepeatChanged,
    required this.onRepeatUntilChanged,
  });

  final bool allDay;
  final ValueChanged<bool> onAllDayChanged;
  final DateTime startDate;
  final ValueChanged<DateTime> onAllDayDateChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final TimeOfDay startTime;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final DateTime endDate;
  final ValueChanged<DateTime> onEndDateChanged;
  final TimeOfDay endTime;
  final ValueChanged<TimeOfDay> onEndTimeChanged;
  final RecurrenceRule repeat;
  final DateTime? repeatUntil;
  final ValueChanged<RecurrenceRule> onRepeatChanged;
  final ValueChanged<DateTime?> onRepeatUntilChanged;

  @override
  Widget build(BuildContext context) {
    final minimumEndDateTime = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    ).add(const Duration(minutes: 1));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: AppSpacing.popupFieldHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'All-day',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: allDay,
                    onChanged: onAllDayChanged,
                    activeTrackColor: AppColors.primary,
                    trackOutlineWidth: const WidgetStatePropertyAll(0.75),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (allDay)
              _EventDateRow(
                label: 'Date',
                date: startDate,
                onDateChanged: onAllDayDateChanged,
              )
            else ...[
              _EventDateTimeRow(
                label: 'Start Time',
                date: startDate,
                time: startTime,
                enabled: true,
                onDateChanged: onStartDateChanged,
                onTimeChanged: onStartTimeChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              _EventDateTimeRow(
                label: 'End Time',
                date: endDate,
                time: endTime,
                enabled: true,
                minimumDate: startDate,
                minimumDateTime: minimumEndDateTime,
                onDateChanged: onEndDateChanged,
                onTimeChanged: onEndTimeChanged,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _RepeatFields(
              repeat: repeat,
              repeatUntil: repeatUntil,
              startDate: startDate,
              onRepeatChanged: onRepeatChanged,
              onRepeatUntilChanged: onRepeatUntilChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFields extends StatelessWidget {
  const _TaskFields({
    required this.deadline,
    required this.onDeadlineChanged,
    required this.deadlineTime,
    required this.onDeadlineTimeChanged,
    required this.estimatedDuration,
    required this.onEstimatedDurationChanged,
    required this.repeat,
    required this.repeatUntil,
    required this.onRepeatChanged,
    required this.onRepeatUntilChanged,
    required this.notesController,
  });

  final DateTime deadline;
  final ValueChanged<DateTime> onDeadlineChanged;
  final TimeOfDay deadlineTime;
  final ValueChanged<TimeOfDay> onDeadlineTimeChanged;
  final Duration estimatedDuration;
  final ValueChanged<Duration> onEstimatedDurationChanged;
  final RecurrenceRule repeat;
  final DateTime? repeatUntil;
  final ValueChanged<RecurrenceRule> onRepeatChanged;
  final ValueChanged<DateTime?> onRepeatUntilChanged;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.popup),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EventDateTimeRow(
                  label: 'Deadline',
                  date: deadline,
                  time: deadlineTime,
                  enabled: true,
                  onDateChanged: onDeadlineChanged,
                  onTimeChanged: onDeadlineTimeChanged,
                ),
                const SizedBox(height: AppSpacing.xxs),
                _RepeatFields(
                  repeat: repeat,
                  repeatUntil: repeatUntil,
                  startDate: deadline,
                  onRepeatChanged: onRepeatChanged,
                  onRepeatUntilChanged: onRepeatUntilChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        EstimatedDurationPicker(
          value: estimatedDuration,
          onChanged: onEstimatedDurationChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        _NotesField(controller: notesController),
      ],
    );
  }
}

class _RepeatFields extends StatelessWidget {
  const _RepeatFields({
    required this.repeat,
    required this.repeatUntil,
    required this.startDate,
    required this.onRepeatChanged,
    required this.onRepeatUntilChanged,
  });

  static const List<RecurrenceRule> _repeatOptions = [
    RecurrenceRule.never,
    RecurrenceRule.daily,
    RecurrenceRule.weekly,
    RecurrenceRule.monthly,
    RecurrenceRule.yearly,
  ];

  final RecurrenceRule repeat;
  final DateTime? repeatUntil;
  final DateTime startDate;
  final ValueChanged<RecurrenceRule> onRepeatChanged;
  final ValueChanged<DateTime?> onRepeatUntilChanged;

  Future<void> _pickUntil(BuildContext context) async {
    final selected = await showAppDatePickerDialog(
      context,
      initialDate: repeatUntil ?? startDate,
      minimumDate: startDate,
    );
    if (selected != null) onRepeatUntilChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.normal);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: AppSpacing.popupFieldHeight,
          child: Row(
            children: [
              Expanded(child: Text('Repeat every', style: textStyle)),
              Selector(
                options: [
                  for (final option in _repeatOptions)
                    SelectorOption(value: option, label: _repeatLabel(option)),
                ],
                selectedValue: repeat,
                placeholder: 'Repeat',
                alignment: AlignmentDirectional.centerEnd,
                onChanged: (value) {
                  if (value != null) onRepeatChanged(value);
                },
              ),
            ],
          ),
        ),
        if (repeat != RecurrenceRule.never) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.onSurface.withValues(alpha: 0.12),
          ),
          SizedBox(
            height: AppSpacing.popupFieldHeight,
            child: Row(
              children: [
                Expanded(child: Text('Until', style: textStyle)),
                _EventValueButton(
                  value: repeatUntil == null
                      ? 'No end date'
                      : MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(repeatUntil!),
                  color: AppColors.onSurface,
                  onPressed: () => _pickUntil(context),
                ),
                if (repeatUntil != null)
                  IconButton(
                    tooltip: 'Clear end date',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onRepeatUntilChanged(null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.normal);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: TextField(
          controller: controller,
          minLines: 5,
          maxLines: 5,
          textAlignVertical: TextAlignVertical.top,
          style: textStyle.copyWith(color: AppColors.onSurface),
          decoration: InputDecoration.collapsed(
            hintText: 'Notes',
            hintStyle: textStyle.copyWith(
              color: AppColors.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDateTimeRow extends StatelessWidget {
  const _EventDateTimeRow({
    required this.label,
    required this.date,
    required this.time,
    required this.enabled,
    required this.onDateChanged,
    required this.onTimeChanged,
    this.minimumDate,
    this.minimumDateTime,
  });

  final String label;
  final DateTime date;
  final TimeOfDay time;
  final bool enabled;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;
  final DateTime? minimumDate;
  final DateTime? minimumDateTime;

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showAppDatePickerDialog(
      context,
      initialDate: date,
      minimumDate: minimumDate,
    );
    if (selected != null) onDateChanged(selected);
  }

  Future<void> _pickTime(BuildContext context) async {
    final minimum = minimumDateTime;
    final minimumTime = minimum != null && DateUtils.isSameDay(date, minimum)
        ? TimeOfDay.fromDateTime(minimum)
        : null;
    final selected = await showAppTimePickerDialog(
      context,
      initialTime: time,
      minimumTime: minimumTime,
    );
    if (selected != null) onTimeChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final valueColor = enabled ? AppColors.onSurface : AppColors.disabled;
    return SizedBox(
      height: AppSpacing.popupFieldHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.normal),
            ),
          ),
          _EventValueButton(
            value: localizations.formatMediumDate(date),
            color: valueColor,
            onPressed: enabled ? () => _pickDate(context) : null,
          ),
          const SizedBox(width: AppSpacing.xxs),
          _EventValueButton(
            value: localizations.formatTimeOfDay(time),
            color: valueColor,
            onPressed: enabled ? () => _pickTime(context) : null,
          ),
        ],
      ),
    );
  }
}

class _EventDateRow extends StatelessWidget {
  const _EventDateRow({
    required this.label,
    required this.date,
    required this.onDateChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showAppDatePickerDialog(context, initialDate: date);
    if (selected != null) onDateChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return SizedBox(
      height: AppSpacing.popupFieldHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.normal),
            ),
          ),
          _EventValueButton(
            value: localizations.formatMediumDate(date),
            color: AppColors.onSurface,
            onPressed: () => _pickDate(context),
          ),
        ],
      ),
    );
  }
}

class _EventValueButton extends StatelessWidget {
  const _EventValueButton({
    required this.value,
    required this.color,
    required this.onPressed,
  });

  final String value;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppRadii.focusPreset),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.focusPreset),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: SizedBox(
            height: 32,
            child: Center(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.normal,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleCategoryFields extends StatelessWidget {
  const _TitleCategoryFields({
    required this.titleController,
    required this.onTitleChanged,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
  });

  final TextEditingController titleController;
  final ValueChanged<String> onTitleChanged;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<PlannerState>().categories;
    final categoryOptions = [
      const SelectorOption(value: _noneCategoryValue, label: 'None'),
      for (final category in categories)
        SelectorOption(
          value: category.id?.toString(),
          label: category.title,
          iconName: category.iconName,
        ),
      const SelectorOption(value: _newCategoryValue, label: 'New category…'),
    ];
    final fieldStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.normal,
      color: AppColors.onSurface.withValues(alpha: 0.55),
    );
    final inputStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.normal,
      color: AppColors.onSurface,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: AppSpacing.popupFieldHeight,
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  child: TextField(
                    controller: titleController,
                    onChanged: onTitleChanged,
                    style: inputStyle,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Title',
                      hintStyle: fieldStyle,
                    ),
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.onSurface.withValues(alpha: 0.12),
            ),
            SizedBox(
              height: AppSpacing.popupFieldHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Selector(
                      options: categoryOptions,
                      selectedValue:
                          selectedCategoryId?.toString() ?? _noneCategoryValue,
                      placeholder: 'Category',
                      isExpanded: true,
                      onChanged: (value) {
                        if (value == _newCategoryValue) {
                          _createCategory(context);
                        } else if (value == _noneCategoryValue) {
                          onCategoryChanged(null);
                        } else {
                          onCategoryChanged(int.tryParse(value ?? ''));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCategory(BuildContext context) async {
    final category = await showNewCategoryDialog(context);
    if (category == null || !context.mounted) return;
    try {
      final saved = await context.read<PlannerState>().addCategory(category);
      onCategoryChanged(saved.id);
    } catch (error) {
      debugPrint('Could not create category from item editor: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              plannerWriteFailureMessage(
                error,
                action: PlannerWriteAction.createCategory,
              ),
            ),
          ),
        );
      }
    }
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _controller = TextEditingController();
  String _iconName = 'mi_school';
  String? _validationMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = (MediaQuery.sizeOf(context).width - 32)
        .clamp(280.0, 400.0)
        .toDouble();
    final fieldStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.normal,
      color: AppColors.onSurface,
    );
    final hintStyle = fieldStyle.copyWith(
      color: AppColors.onSurface.withValues(alpha: 0.55),
    );

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
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New category',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.popup),
                      ),
                      child: SizedBox(
                        height: AppSpacing.popupFieldHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Center(
                            child: SizedBox(
                              height: 28,
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                onChanged: (_) {
                                  if (_validationMessage != null) {
                                    setState(() => _validationMessage = null);
                                  }
                                },
                                style: fieldStyle,
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  hintText: 'Name',
                                  hintStyle: hintStyle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CategoryIconSelector(
                    selectedIconName: _iconName,
                    onChanged: (iconName) =>
                        setState(() => _iconName = iconName),
                  ),
                ],
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _ValidationMessage(message: _validationMessage!),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        textStyle: _itemTypeTextStyle(context),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        textStyle: _itemTypeTextStyle(context),
                      ),
                      onPressed: () {
                        final title = _controller.text.trim();
                        if (title.isEmpty) {
                          setState(() => _validationMessage = 'Enter a name.');
                          return;
                        }
                        Navigator.pop(
                          context,
                          TaskCategory(
                            title: title,
                            iconName: _iconName,
                            items: [],
                          ),
                        );
                      },
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTypeSelector extends StatelessWidget {
  const _ItemTypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
  });

  final _PopupItemType selectedType;
  final ValueChanged<_PopupItemType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.surface),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          for (final type in _PopupItemType.values)
            Expanded(
              child: Material(
                color: type == selectedType
                    ? AppColors.primary
                    : AppColors.transparent,
                borderRadius: BorderRadius.circular(100),
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => onTypeChanged(type),
                  child: Center(
                    child: Text(
                      type == _PopupItemType.event ? 'Event' : 'Task',
                      style: _itemTypeTextStyle(context).copyWith(
                        color: type == selectedType
                            ? AppColors.onPrimary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

TextStyle _itemTypeTextStyle(BuildContext context) => Theme.of(
  context,
).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.normal);
