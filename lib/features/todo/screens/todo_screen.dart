import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/app_data.dart';

/// Single To-Do screen that covers both the "To-Do" and "To-Do
/// Condensed" mockup screens through one toggle (top-right icon)
/// instead of building two near-duplicate widgets.
class TodoScreen extends StatefulWidget {
  final AppData appData;
  final VoidCallback onChanged;

  const TodoScreen({super.key, required this.appData, required this.onChanged});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  bool _condensed = false;

  @override
  Widget build(BuildContext context) {
    final appData = widget.appData;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 90,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          actions: [
            IconButton(
              icon: Icon(_condensed ? Icons.unfold_more : Icons.unfold_less, color: Colors.white),
              tooltip: _condensed ? 'Expand' : 'Condense',
              onPressed: () => setState(() => _condensed = !_condensed),
            ),
          ],
          flexibleSpace: const FlexibleSpaceBar(
            title: Text('To-Do',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              appData.categories.map((category) {
                final tasks = appData.tasksForCategory(category);
                final pending = tasks.where((t) => !t.isCompleted).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: !_condensed,
                      leading: CategoryChip(category: category, size: 24),
                      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$pending pending', style: const TextStyle(color: AppColors.accent)),
                      children: tasks.map((t) {
                        return CheckboxListTile(
                          value: t.isCompleted,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) {
                            appData.toggleTask(t.id);
                            widget.onChanged();
                            setState(() {});
                          },
                          title: Text(t.title),
                          subtitle: _condensed
                              ? null
                              : Text(
                                  '${formatWeekdayDate(t.dueDate)} · ${formatTime(t.dueDate)} · ${formatEstimate(t.estimate)}'),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
