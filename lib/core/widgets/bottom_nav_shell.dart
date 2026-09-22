import 'package:flutter/material.dart';
import '../../data/app_data.dart';
import '../theme/app_theme.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/timer/screens/timer_screen.dart';
import '../../features/ai_planner/screens/ai_planner_screen.dart';
import '../../features/todo/screens/todo_screen.dart';
import '../../features/task_entry/screens/new_entry_sheet.dart';

/// Persistent bottom-nav + FAB shell shown on every main tab
/// (Dashboard, Calendar, Timer, AI Planner, To-Do) - matches the
/// pill-shaped nav bar + floating "+" button in the mockup.
///
/// Holds the single AppData instance for the whole app and passes it
/// down to each tab. No state-management package: child screens call
/// back up to refresh(), which just calls setState() here, so every
/// tab rebuilds with the latest data.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final AppData appData = AppData();
  int _currentIndex = 0;

  void refresh() => setState(() {});

  void _openNewEntrySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewEntrySheet(appData: appData, onSaved: refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(appData: appData, onChanged: refresh),
      CalendarScreen(appData: appData, onChanged: refresh),
      TimerScreen(appData: appData),
      AiPlannerScreen(appData: appData, onChanged: refresh),
      TodoScreen(appData: appData, onChanged: refresh),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: _openNewEntrySheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: _NavPill(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavPill({required this.currentIndex, required this.onTap});

  static const _icons = [
    Icons.home_rounded,
    Icons.calendar_today_rounded,
    Icons.timer_rounded,
    Icons.auto_awesome_rounded,
    Icons.check_circle_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_icons.length, (i) {
            final selected = i == currentIndex;
            return IconButton(
              onPressed: () => onTap(i),
              icon: Icon(
                _icons[i],
                color: selected ? AppColors.primary : Colors.white70,
              ),
              style: selected
                  ? IconButton.styleFrom(backgroundColor: Colors.white)
                  : null,
            );
          }),
        ),
      ),
    );
  }
}
