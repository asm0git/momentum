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
          title: 'Grade first-year assignments',
          isChecked: false,
          date: today.add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: const Duration(hours: 2),
        ),
        Task(
          title: 'Read Flutter layout documentation',
          isChecked: false,
          date: today.add(const Duration(days: 2)),
          time: const TimeOfDay(hour: 10, minute: 0),
          estimatedDuration: const Duration(minutes: 45),
        ),
        Task(
          title: 'Submit project reflection',
          isChecked: false,
          date: today.add(const Duration(days: 3)),
          time: const TimeOfDay(hour: 15, minute: 0),
          estimatedDuration: const Duration(hours: 1),
        ),
        Task(
          title: 'Review presentation slides',
          isChecked: false,
          date: today.add(const Duration(days: 4)),
          time: const TimeOfDay(hour: 16, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
        ),
      ],
    ),
    TaskCategory(
      title: 'Personal',
      iconName: 'personal',
      items: [
        Task(
          title: 'Review monthly budget',
          isChecked: false,
          date: today,
          time: const TimeOfDay(hour: 12, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
        ),
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
        Task(
          title: 'Plan weekend errands',
          isChecked: false,
          date: today.add(const Duration(days: 4)),
          time: const TimeOfDay(hour: 8, minute: 30),
          estimatedDuration: const Duration(minutes: 30),
        ),
        Task(
          title: 'Organize study desk',
          isChecked: false,
          date: today.add(const Duration(days: 5)),
          time: const TimeOfDay(hour: 11, minute: 0),
          estimatedDuration: const Duration(minutes: 45),
        ),
        Task(
          title: 'Call family',
          isChecked: false,
          date: today.add(const Duration(days: 6)),
          time: const TimeOfDay(hour: 18, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
        ),
      ],
    ),
    TaskCategory(
      title: 'Work',
      iconName: 'work',
      items: [
        Task(
          title: 'Prepare team update',
          isChecked: false,
          date: today,
          time: const TimeOfDay(hour: 10, minute: 0),
          estimatedDuration: const Duration(minutes: 45),
        ),
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
        Task(
          title: 'Prepare weekly status report',
          isChecked: false,
          date: today.add(const Duration(days: 3)),
          time: const TimeOfDay(hour: 9, minute: 30),
          estimatedDuration: const Duration(hours: 1),
        ),
        Task(
          title: 'Reply to project emails',
          isChecked: false,
          date: today.add(const Duration(days: 4)),
          time: const TimeOfDay(hour: 13, minute: 0),
          estimatedDuration: const Duration(minutes: 45),
        ),
        Task(
          title: 'Plan next sprint',
          isChecked: false,
          date: today.add(const Duration(days: 5)),
          time: const TimeOfDay(hour: 10, minute: 0),
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
        Task(
          title: 'Schedule recovery walk',
          isChecked: false,
          date: today.add(const Duration(days: 2)),
          time: const TimeOfDay(hour: 7, minute: 30),
          estimatedDuration: const Duration(minutes: 30),
        ),
        Task(
          title: 'Track weekly measurements',
          isChecked: false,
          date: today.add(const Duration(days: 3)),
          time: const TimeOfDay(hour: 8, minute: 0),
          estimatedDuration: const Duration(minutes: 20),
        ),
        Task(
          title: 'Restock workout supplies',
          isChecked: false,
          date: today.add(const Duration(days: 4)),
          time: const TimeOfDay(hour: 12, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
        ),
      ],
    ),
  ];
}

final mockCategories = createMockCategories();
