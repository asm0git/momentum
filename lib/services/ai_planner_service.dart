import '../models/task.dart';

/// Placeholder for the real AI Planner backend call.
///
/// Today AiPlannerScreen just sorts today's tasks by time. When
/// you're ready, implement this to call your AI/scheduling API and
/// have it return an ordered (or time-blocked) list of tasks/events
/// for the day, then have AiPlannerScreen call this instead.
class AiPlannerService {
  Future<List<TaskItem>> generatePlanForDay(DateTime day, List<TaskItem> candidateTasks) async {
    // TODO: replace with a real API/LLM call.
    final sorted = List<TaskItem>.from(candidateTasks)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return sorted;
  }
}
