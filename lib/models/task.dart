import 'category.dart';

/// A single to-do item (used on Dashboard, To-Do, Timer's "Due Today",
/// AI Planner, and Calendar).
class TaskItem {
  final String id;
  String title;
  TaskCategory category;
  DateTime dueDate;
  Duration estimate;
  bool isCompleted;
  String? repeatRule; // e.g. "Every Tuesday" - null means it doesn't repeat

  TaskItem({
    required this.id,
    required this.title,
    required this.category,
    required this.dueDate,
    required this.estimate,
    this.isCompleted = false,
    this.repeatRule,
  });
}
