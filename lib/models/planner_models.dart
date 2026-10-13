import 'package:flutter/material.dart';

enum RecurrenceRule { never, daily, weekly, monthly, yearly }

abstract class PlannerItem {
  PlannerItem({
    this.id,
    this.categoryId,
    required this.title,
    required this.date,
  });

  int? id;
  int? categoryId;
  String title;
  DateTime date;
}

class Task extends PlannerItem {
  Task({
    super.id,
    super.categoryId,
    required super.title,
    required super.date,
    required this.isChecked,
    required this.time,
    required this.estimatedDuration,
    this.repeat = RecurrenceRule.never,
    this.repeatUntil,
    this.occurrenceDate,
    this.description = '',
    this.priority,
    this.sourcePlatform,
    this.externalId,
  });

  bool isChecked;
  TimeOfDay time;
  Duration estimatedDuration;
  RecurrenceRule repeat;
  DateTime? repeatUntil;
  // Set only on a generated calendar/to-do instance of a recurring series.
  // This value is not serialized into the tasks table.
  DateTime? occurrenceDate;
  String description;
  int? priority;
  String? sourcePlatform;
  String? externalId;
}

class Event extends PlannerItem {
  Event({
    super.id,
    super.categoryId,
    required super.title,
    required super.date,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.allDay,
    DateTime? endDate,
    this.location,
    this.notes = '',
    this.repeat = RecurrenceRule.never,
    this.repeatUntil,
    this.occurrenceDate,
    this.sourcePlatform,
    this.externalId,
  }) : endDate = endDate ?? date;

  TimeOfDay start;
  TimeOfDay end;
  DateTime endDate;
  bool isCurrent;
  bool allDay;
  String? location;
  String notes;
  RecurrenceRule repeat;
  DateTime? repeatUntil;
  // Set only on a generated calendar instance; the database stores the series.
  DateTime? occurrenceDate;
  String? sourcePlatform;
  String? externalId;
}

class TaskCategory {
  TaskCategory({
    this.id,
    required this.title,
    required this.iconName,
    required this.items,
  });

  int? id;
  String title;
  String iconName;
  List<PlannerItem> items;

  int get pendingCount => items
      .where((item) => item is Event || (item is Task && !item.isChecked))
      .length;
}

enum CategoryDeleteDisposition { deleteItems, moveItems }

class DailyPlan {
  DailyPlan({
    this.id,
    required this.planDate,
    required this.orderedTaskIds,
    required this.generatedTimestamp,
  });

  int? id;
  DateTime planDate;
  List<int> orderedTaskIds;
  DateTime generatedTimestamp;
}
