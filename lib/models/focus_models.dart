import 'package:flutter/foundation.dart';

@immutable
class FocusTaskSelection {
  const FocusTaskSelection({
    required this.taskId,
    required this.taskTitle,
    required this.categoryId,
    required this.categoryTitle,
    required this.categoryIcon,
    this.isEvent = false,
  });

  static const unassigned = FocusTaskSelection(
    taskId: 0,
    taskTitle: 'No task or event',
    categoryId: -1,
    categoryTitle: 'Unassigned',
    categoryIcon: 'mi_timer',
  );

  final int taskId;
  final String taskTitle;
  final int categoryId;
  final String categoryTitle;
  final String categoryIcon;
  final bool isEvent;

  @override
  bool operator ==(Object other) =>
      other is FocusTaskSelection &&
      taskId == other.taskId &&
      taskTitle == other.taskTitle &&
      categoryId == other.categoryId &&
      categoryTitle == other.categoryTitle &&
      categoryIcon == other.categoryIcon &&
      isEvent == other.isEvent;

  @override
  int get hashCode => Object.hash(
    taskId,
    taskTitle,
    categoryId,
    categoryTitle,
    categoryIcon,
    isEvent,
  );
}

@immutable
class FocusCategoryTotal {
  const FocusCategoryTotal({
    required this.categoryId,
    required this.categoryTitle,
    required this.categoryIcon,
    required this.totalSeconds,
  });

  final int categoryId;
  final String categoryTitle;
  final String categoryIcon;
  final int totalSeconds;
}
