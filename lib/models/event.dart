import 'category.dart';

/// A calendar event, created from the "Event" side of the New
/// Event/Task bottom sheet.
class EventItem {
  final String id;
  String title;
  TaskCategory? category;
  bool isAllDay;
  DateTime startTime;
  DateTime endTime;
  String repeatEvery; // "Never", "Daily", "Weekly", "Monthly"

  EventItem({
    required this.id,
    required this.title,
    this.category,
    this.isAllDay = false,
    required this.startTime,
    required this.endTime,
    this.repeatEvery = 'Never',
  });
}
