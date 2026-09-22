import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/app_data.dart';

class CalendarScreen extends StatefulWidget {
  final AppData appData;
  final VoidCallback onChanged;

  const CalendarScreen({super.key, required this.appData, required this.onChanged});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();

  List<DateTime?> get _gridDays {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = first.weekday % 7; // Sunday-first grid
    return [
      ...List<DateTime?>.filled(leadingBlanks, null),
      ...List.generate(daysInMonth, (i) => DateTime(_visibleMonth.year, _visibleMonth.month, i + 1)),
    ];
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final tasksForDay = widget.appData.tasks.where((t) =>
        t.dueDate.year == _selectedDay.year &&
        t.dueDate.month == _selectedDay.month &&
        t.dueDate.day == _selectedDay.day).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 90,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          flexibleSpace: const FlexibleSpaceBar(
            title: Text('Calendar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
                  ),
                  Text('${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: _gridDays.map((day) {
                  if (day == null) return const SizedBox.shrink();
                  final isSelected = day.year == _selectedDay.year &&
                      day.month == _selectedDay.month &&
                      day.day == _selectedDay.day;
                  final now = DateTime.now();
                  final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.accent : (isToday ? AppColors.cardBackground : null),
                      ),
                      child: Text('${day.day}',
                          style: TextStyle(color: isSelected ? Colors.white : AppColors.textDark)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(formatWeekdayDate(_selectedDay), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              if (tasksForDay.isEmpty)
                const Text('Nothing scheduled.', style: TextStyle(color: AppColors.textMuted))
              else
                ...tasksForDay.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SectionCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.title),
                          subtitle: Text('${formatTime(t.dueDate)} · ${t.category.name}'),
                        ),
                      ),
                    )),
            ]),
          ),
        ),
      ],
    );
  }
}
