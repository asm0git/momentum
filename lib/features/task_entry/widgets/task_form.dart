import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_data.dart';
import '../../../models/category.dart';
import '../../../models/task.dart';

class TaskForm extends StatefulWidget {
  final AppData appData;
  final ValueChanged<TaskItem> onSave;

  const TaskForm({super.key, required this.appData, required this.onSave});

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _titleController = TextEditingController();
  final _estimateMinutesController = TextEditingController(text: '30');
  TaskCategory? _category;
  DateTime _dueDate = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    _estimateMinutesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_dueDate));
    if (time == null) return;
    setState(() => _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Due'),
          trailing: Text(
              '${_dueDate.month}/${_dueDate.day}/${_dueDate.year}  ${TimeOfDay.fromDateTime(_dueDate).format(context)}'),
          onTap: _pickDueDateTime,
        ),
        TextField(
          controller: _estimateMinutesController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Estimated minutes',
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            if (_titleController.text.trim().isEmpty || _category == null) return;
            final minutes = int.tryParse(_estimateMinutesController.text) ?? 30;
            widget.onSave(TaskItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: _titleController.text.trim(),
              category: _category!,
              dueDate: _dueDate,
              estimate: Duration(minutes: minutes),
            ));
          },
          child: const Text('Save Task', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
