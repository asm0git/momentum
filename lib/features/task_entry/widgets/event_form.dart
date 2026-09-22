import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_data.dart';
import '../../../models/category.dart';
import '../../../models/event.dart';

class EventForm extends StatefulWidget {
  final AppData appData;
  final ValueChanged<EventItem> onSave;

  const EventForm({super.key, required this.appData, required this.onSave});

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _titleController = TextEditingController();
  TaskCategory? _category;
  bool _isAllDay = false;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(hours: 1));
  String _repeat = 'Never';

  static const _repeatOptions = ['Never', 'Daily', 'Weekly', 'Monthly'];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = combined;
      } else {
        _end = combined;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TaskCategory>(
          value: _category,
          hint: const Text('Category'),
          decoration: const InputDecoration(
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
          items: widget.appData.categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
          onChanged: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('All-day'),
          value: _isAllDay,
          onChanged: (v) => setState(() => _isAllDay = v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Start time'),
          trailing: Text(
              '${_start.month}/${_start.day}/${_start.year}  ${TimeOfDay.fromDateTime(_start).format(context)}'),
          onTap: () => _pickDateTime(isStart: true),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('End time'),
          trailing:
              Text('${_end.month}/${_end.day}/${_end.year}  ${TimeOfDay.fromDateTime(_end).format(context)}'),
          onTap: () => _pickDateTime(isStart: false),
        ),
        DropdownButtonFormField<String>(
          value: _repeat,
          decoration: const InputDecoration(
            labelText: 'Repeat every',
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
          items: _repeatOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (r) => setState(() => _repeat = r ?? 'Never'),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            if (_titleController.text.trim().isEmpty) return;
            widget.onSave(EventItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: _titleController.text.trim(),
              category: _category,
              isAllDay: _isAllDay,
              startTime: _start,
              endTime: _end,
              repeatEvery: _repeat,
            ));
          },
          child: const Text('Save Event', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
