import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/category_chip.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/app_data.dart';

/// Starter version of the AI Planner screen. For now it just lays
/// today's tasks out on a simple timeline sorted by time. When you're
/// ready, replace the body below with a call to a real planning
/// service (e.g. lib/services/ai_planner_service.dart, hitting an
/// LLM or scheduling API) that returns generated time blocks instead.
class AiPlannerScreen extends StatelessWidget {
  final AppData appData;
  final VoidCallback onChanged;

  const AiPlannerScreen({super.key, required this.appData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final today = appData.dueToday..sort((a, b) => a.dueDate.compareTo(b.dueDate));

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
            title: Text('AI Planner',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const Text("Today's plan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              if (today.isEmpty)
                const Text('Nothing scheduled - add a task to see it here.',
                    style: TextStyle(color: AppColors.textMuted))
              else
                ...today.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SectionCard(
                        child: Row(
                          children: [
                            CategoryChip(category: t.category, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatTime(t.dueDate),
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
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
