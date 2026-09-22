import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_data.dart';
import '../widgets/event_form.dart';
import '../widgets/task_form.dart';

/// The shared "New Event / New Task" bottom sheet, opened from the
/// floating + button on every tab - it isn't owned by any single
/// screen, which is why it lives in its own feature folder.
class NewEntrySheet extends StatefulWidget {
  final AppData appData;
  final VoidCallback onSaved;

  const NewEntrySheet({super.key, required this.appData, required this.onSaved});

  @override
  State<NewEntrySheet> createState() => _NewEntrySheetState();
}

class _NewEntrySheetState extends State<NewEntrySheet> {
  bool _isEvent = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _ToggleTab(
                        label: 'Event',
                        selected: _isEvent,
                        onTap: () => setState(() => _isEvent = true),
                      ),
                    ),
                    Expanded(
                      child: _ToggleTab(
                        label: 'Task',
                        selected: !_isEvent,
                        onTap: () => setState(() => _isEvent = false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _isEvent
                  ? EventForm(
                      appData: widget.appData,
                      onSave: (event) {
                        widget.appData.addEvent(event);
                        widget.onSaved();
                        Navigator.pop(context);
                      },
                    )
                  : TaskForm(
                      appData: widget.appData,
                      onSave: (task) {
                        widget.appData.addTask(task);
                        widget.onSaved();
                        Navigator.pop(context);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
