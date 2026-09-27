import 'package:flutter/material.dart';

abstract class PlannerItem {
  PlannerItem({
    required this.title,
    required this.date,
  });

  String title;
  DateTime date;
}

class Task extends PlannerItem {
  Task({
    required super.title,
    required super.date,
    required this.isChecked,
    required this.time,
    required this.estimatedDuration,
  });

  bool isChecked;
  TimeOfDay time;
  Duration estimatedDuration;
}

class Event extends PlannerItem {
  Event({
    required super.title,
    required super.date,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.allDay,
  });

  TimeOfDay start;
  TimeOfDay end;
  bool isCurrent;
  bool allDay;
}

class TaskCategory {
  TaskCategory({
    required this.title,
    required this.iconName,
    required this.items,
  });

  String title;
  String iconName;
  List<PlannerItem> items;

  int get pendingCount =>
      items.whereType<Task>().where((task) => !task.isChecked).length;
}

List<TaskCategory> createMockCategories() {
  final today = DateTime.now();

  return [
    TaskCategory(
      title: 'School',
      iconName: 'school',
      items: [
        Task(
          title: '6ADET Final Project',
          isChecked: false,
          date: today,
          time: const TimeOfDay(hour: 13, minute: 0),
          estimatedDuration: const Duration(hours: 8),
        ),
        Task(
          title: 'Grade first-year Python logic formulation assignments',
          isChecked: false,
          date: today.add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: const Duration(hours: 2),
        ),
      ],
    ),
    TaskCategory(
      title: 'Personal',
      iconName: 'personal',
      items: [
        Event(
          title: "Janisa's Birthday",
          date: today.add(const Duration(days: 2)),
          start: const TimeOfDay(hour: 18, minute: 0),
          end: const TimeOfDay(hour: 21, minute: 0),
          isCurrent: false,
          allDay: false,
        ),
        Task(
          title: 'Consolidate grade 2 math reviewer',
          isChecked: false,
          date: today.add(const Duration(days: 3)),
          time: const TimeOfDay(hour: 10, minute: 0),
          estimatedDuration: const Duration(hours: 1),
        ),
      ],
    ),
    TaskCategory(
      title: 'Work',
      iconName: 'work',
      items: [
        Task(
          title: 'Draft USC Executive Order No. 2',
          isChecked: false,
          date: today.add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 14, minute: 0),
          estimatedDuration: const Duration(hours: 3),
        ),
        Task(
          title: 'Review TOSFI financial statements',
          isChecked: false,
          date: today.add(const Duration(days: 2)),
          time: const TimeOfDay(hour: 11, minute: 0),
          estimatedDuration: const Duration(hours: 2),
        ),
      ],
    ),
    TaskCategory(
      title: 'Gym',
      iconName: 'gym',
      items: [
        Task(
          title: 'Push Day',
          isChecked: false,
          date: today,
          time: const TimeOfDay(hour: 17, minute: 0),
          estimatedDuration: const Duration(hours: 1),
        ),
        Task(
          title: 'Prep high-protein chicken wraps',
          isChecked: false,
          date: today.add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 19, minute: 0),
          estimatedDuration: const Duration(minutes: 45),
        ),
      ],
    ),
  ];
}

final mockCategories = createMockCategories();