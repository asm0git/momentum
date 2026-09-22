import '../models/category.dart';
import '../models/task.dart';
import '../models/event.dart';

/// Plain in-memory data store - no state-management package involved.
///
/// One AppData instance is created in RootShell's State and passed
/// down to every tab through constructors. Screens call its methods
/// (addTask, toggleTask, ...) to mutate it, then call the onChanged /
/// refresh callback they were given, which just does setState((){})
/// back in RootShell to rebuild everything with the new data.
///
/// When you're ready to add a real backend, keep these same method
/// names and swap the bodies for API/database calls - the UI code
/// won't need to change.
class AppData {
  final List<TaskCategory> categories = List.from(defaultCategories);
  final List<TaskItem> tasks = [];
  final List<EventItem> events = [];

  AppData() {
    _seed();
  }

  TaskCategory categoryById(String id) =>
      categories.firstWhere((c) => c.id == id, orElse: () => categories.first);

  List<TaskItem> tasksForCategory(TaskCategory category) =>
      tasks.where((t) => t.category.id == category.id).toList();

  List<TaskItem> get dueToday {
    final now = DateTime.now();
    return tasks
        .where((t) =>
            !t.isCompleted &&
            t.dueDate.year == now.year &&
            t.dueDate.month == now.month &&
            t.dueDate.day == now.day)
        .toList();
  }

  void addTask(TaskItem task) => tasks.add(task);

  void toggleTask(String id) {
    final task = tasks.firstWhere((t) => t.id == id);
    task.isCompleted = !task.isCompleted;
  }

  void addEvent(EventItem event) => events.add(event);

  // Seed data so the app looks like the mockup on first run.
  void _seed() {
    final work = categoryById('work');
    final personal = categoryById('personal');
    final school = categoryById('school');
    final now = DateTime.now();

    tasks.addAll([
      TaskItem(
        id: 't1',
        title: 'Push day',
        category: personal,
        dueDate: DateTime(now.year, now.month, now.day, 10, 0),
        estimate: const Duration(hours: 2),
      ),
      TaskItem(
        id: 't2',
        title: 'Drink medicine',
        category: personal,
        dueDate: DateTime(now.year, now.month, now.day, 22, 0),
        estimate: const Duration(minutes: 1),
      ),
      TaskItem(
        id: 't3',
        title: 'Draft speech',
        category: work,
        dueDate: DateTime(now.year, now.month, now.day, 20, 0)
            .add(const Duration(days: 2)),
        estimate: const Duration(hours: 2),
      ),
      TaskItem(
        id: 't4',
        title: '6ADET Final Project',
        category: school,
        dueDate: DateTime(now.year, now.month, now.day, 23, 59)
            .add(const Duration(days: 5)),
        estimate: const Duration(hours: 10),
      ),
    ]);
  }
}
