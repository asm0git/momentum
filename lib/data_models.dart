import 'package:flutter/material.dart';

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
    this.description = '',
    this.priority,
    this.srcPlatform,
    this.externalId,
  });

  bool isChecked;
  TimeOfDay time;
  Duration estimatedDuration;
  String description;
  int? priority;
  String? srcPlatform;
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
    this.repeat = 'Never',
    this.srcPlatform,
    this.externalId,
  }) : endDate = endDate ?? date;

  TimeOfDay start;
  TimeOfDay end;
  DateTime endDate;
  bool isCurrent;
  bool allDay;
  String? location;
  String notes;
  String repeat;
  String? srcPlatform;
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

class LinkedAccount {
  LinkedAccount({
    this.id,
    required this.platformName,
    required this.accountEmail,
    required this.apiToken,
    this.lastSyncTime,
  });

  int? id;
  String platformName;
  String accountEmail;
  String apiToken;
  DateTime? lastSyncTime;
}
