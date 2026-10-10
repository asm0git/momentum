import '../data_models.dart';

/// Returns the starter category names for a new local planner database.
/// Items are intentionally empty so a clean install starts with no tasks or
/// events; users can add their own calendar data from the planner screens.
List<TaskCategory> createSampleCategories() => [
  TaskCategory(title: 'School', iconName: 'school', items: []),
  TaskCategory(title: 'Personal', iconName: 'personal', items: []),
  TaskCategory(title: 'Work', iconName: 'work', items: []),
  TaskCategory(title: 'Gym', iconName: 'gym', items: []),
];
