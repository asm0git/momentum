import 'package:flutter/material.dart';
import 'package:provider/provider.dart' hide Selector;

import '../app_theme.dart';
import '../data_models.dart';
import '../state/planner_state.dart';
import 'blurred_dialog.dart';
import 'date_picker_dialog.dart';
import 'estimated_duration_picker.dart';
import 'selector.dart';
import 'time_picker_dialog.dart';

enum _PopupItemType { event, task }

const _newCategoryValue = '__new_category__';
const _noneCategoryValue = '__none_category__';

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
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  String _repeat = 'Never';

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
      _notesController.text = item.description;
    } else if (item is Event) {
      _selectedType = _PopupItemType.event;
      _allDay = item.allDay;
      _startDate = item.date;
      _startTime = item.start;
      _endDate = item.endDate;
      _endTime = item.end;
      _repeat = item.repeat;
      _eventNotesController.text = item.notes;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _eventNotesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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
                onTypeChanged: (type) => setState(() => _selectedType = type),
              ),
            const SizedBox(height: AppSpacing.sm),
            _TitleCategoryFields(
              titleController: _titleController,
              selectedCategoryId: _selectedCategoryId,
              onCategoryChanged: (categoryId) =>
                  setState(() => _selectedCategoryId = categoryId),
            ),
            if (_selectedType == _PopupItemType.event) ...[
              const SizedBox(height: AppSpacing.sm),
              _EventFields(
                allDay: _allDay,
                onAllDayChanged: (value) => setState(() => _allDay = value),
                startDate: _startDate,
                onAllDayDateChanged: (value) => setState(() {
                  _startDate = value;
                  _endDate = value;
                }),
                onStartDateChanged: (value) =>
                    setState(() => _startDate = value),
                startTime: _startTime,
                onStartTimeChanged: (value) =>
                    setState(() => _startTime = value),
                endDate: _endDate,
                onEndDateChanged: (value) => setState(() => _endDate = value),
                endTime: _endTime,
                onEndTimeChanged: (value) => setState(() => _endTime = value),
                repeat: _repeat,
                onRepeatChanged: (value) => setState(() => _repeat = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NotesField(controller: _eventNotesController),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              _TaskFields(
                deadline: _taskDeadline,
                onDeadlineChanged: (value) =>
                    setState(() => _taskDeadline = value),
                deadlineTime: _taskDeadlineTime,
                onDeadlineTimeChanged: (value) =>
                    setState(() => _taskDeadlineTime = value),
                estimatedDuration: _taskEstimatedDuration,
                onEstimatedDurationChanged: (value) =>
                    setState(() => _taskEstimatedDuration = value),
                notesController: _notesController,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  // The app-wide FilledButton minimum width is infinite so
                  // buttons stretch when given bounded width. This action sits
                  // in a Row, which lays out each child with an unbounded
                  // horizontal constraint, so give this button a finite width.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  onPressed: _save,
                  child: Text(
                    widget.initialItem == null
                        ? 'Add ${_selectedType == _PopupItemType.task ? 'Task' : 'Event'}'
                        : 'Save changes',
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
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showValidationError('Enter a title.');
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
          isChecked: previous is Task ? previous.isChecked : false,
          description: _notesController.text.trim(),
          priority: previous is Task ? previous.priority : null,
          srcPlatform: previous is Task ? previous.srcPlatform : null,
          externalId: previous is Task ? previous.externalId : null,
        );
        final saved = await state.saveTask(task);
        widget.onSaved?.call(saved);
        return;
      }

      final startsAt = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _allDay ? 0 : _startTime.hour,
        _allDay ? 0 : _startTime.minute,
      );
      final endsAt = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _allDay ? 0 : _endTime.hour,
        _allDay ? 0 : _endTime.minute,
      );
      if (!_allDay && !endsAt.isAfter(startsAt)) {
        _showValidationError('End time must be after start time.');
        return;
      }
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
        srcPlatform: previous is Event ? previous.srcPlatform : null,
        externalId: previous is Event ? previous.externalId : null,
      );
      final saved = await state.saveEvent(event);
      widget.onSaved?.call(saved);
    } catch (_) {
      _showValidationError('Could not save this item.');
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    required this.onRepeatChanged,
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
  final String repeat;
  final ValueChanged<String> onRepeatChanged;

  static const _repeatOptions = [
    'Never',
    'Every day',
    'Every week',
    'Every month',
    'Every year',
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.popup),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                onDateChanged: onEndDateChanged,
                onTimeChanged: onEndTimeChanged,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.popupFieldHeight,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Repeat every',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Selector(
                    options: [
                      for (final option in _repeatOptions)
                        SelectorOption(value: option, label: option),
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
    required this.notesController,
  });

  final DateTime deadline;
  final ValueChanged<DateTime> onDeadlineChanged;
  final TimeOfDay deadlineTime;
  final ValueChanged<TimeOfDay> onDeadlineTimeChanged;
  final Duration estimatedDuration;
  final ValueChanged<Duration> onEstimatedDurationChanged;
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: AppSpacing.popupFieldHeight,
                  child: _EventDateTimeRow(
                    label: 'Deadline',
                    date: deadline,
                    time: deadlineTime,
                    enabled: true,
                    onDateChanged: onDeadlineChanged,
                    onTimeChanged: onDeadlineTimeChanged,
                  ),
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
        padding: const EdgeInsets.all(AppSpacing.md),
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
  });

  final String label;
  final DateTime date;
  final TimeOfDay time;
  final bool enabled;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TimeOfDay> onTimeChanged;

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showAppDatePickerDialog(context, initialDate: date);
    if (selected != null) onDateChanged(selected);
  }

  Future<void> _pickTime(BuildContext context) async {
    final selected = await showAppTimePickerDialog(context, initialTime: time);
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
    required this.selectedCategoryId,
    required this.onCategoryChanged,
  });

  final TextEditingController titleController;
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
    final category = await showBlurredDialog<TaskCategory>(
      context: context,
      builder: (context) => const _NewCategoryDialog(),
    );
    if (category == null || !context.mounted) return;
    try {
      final saved = await context.read<PlannerState>().addCategory(category);
      onCategoryChanged(saved.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create this category.')),
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
  String _iconName = 'school';
  static const _icons = ['school', 'personal', 'work', 'gym'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _iconName,
            decoration: const InputDecoration(labelText: 'Icon'),
            items: [
              for (final icon in _icons)
                DropdownMenuItem(value: icon, child: Text(icon)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _iconName = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = _controller.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              TaskCategory(title: title, iconName: _iconName, items: []),
            );
          },
          child: const Text('Create'),
        ),
      ],
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
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.normal,
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
