import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/app_data.dart';
import '../../../models/pomodoro_preset.dart';

class DashboardScreen extends StatelessWidget {
  final AppData appData;
  final VoidCallback onChanged;

  const DashboardScreen({
    super.key,
    required this.appData,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dueToday = appData.dueToday;

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
            title: Text('Dashboard',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(formatWeekdayDate(now), style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(formatTime(now),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Row(
                children: appData.categories.take(2).map((c) {
                  final pending = appData.tasksForCategory(c).where((t) => !t.isCompleted).length;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CategoryChip(category: c, size: 24),
                            const SizedBox(height: 8),
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('$pending pending',
                                style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('To-do', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  children: dueToday.isEmpty
                      ? [
                          const Text('Nothing due today.',
                              style: TextStyle(color: AppColors.textMuted))
                        ]
                      : dueToday.map((t) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: t.isCompleted,
                            onChanged: (_) {
                              appData.toggleTask(t.id);
                              onChanged();
                            },
                            title: Text(t.title),
                            subtitle: Text('${formatTime(t.dueDate)} · ${formatEstimate(t.estimate)}'),
                          );
                        }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Focus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: defaultPomodoroPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final p = defaultPomodoroPresets[i];
                    return SectionCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${p.focusDuration.inMinutes} minutes',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${p.restDuration.inMinutes} minutes rest',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
