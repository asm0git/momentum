import 'package:flutter/material.dart';

enum CalendarProvider {
  canvas,
  googleCalendar,
  outlook;

  String get key => switch (this) {
    CalendarProvider.canvas => 'canvas',
    CalendarProvider.googleCalendar => 'google',
    CalendarProvider.outlook => 'outlook',
  };

  String get title => switch (this) {
    CalendarProvider.canvas => 'Canvas',
    CalendarProvider.googleCalendar => 'Google Calendar',
    CalendarProvider.outlook => 'Outlook',
  };

  String get categoryIcon => switch (this) {
    CalendarProvider.canvas => 'mi_school',
    CalendarProvider.googleCalendar ||
    CalendarProvider.outlook => 'mi_calendar_month',
  };
}

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
    this.repeat = 'Never',
    this.repeatUntil,
    this.occurrenceDate,
    this.description = '',
    this.priority,
    this.srcPlatform,
    this.externalId,
  });

  bool isChecked;
  TimeOfDay time;
  Duration estimatedDuration;
  String repeat;
  DateTime? repeatUntil;
  // Set only on a generated calendar/to-do instance of a recurring series.
  // This value is not serialized into the tasks table.
  DateTime? occurrenceDate;
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
    this.repeatUntil,
    this.occurrenceDate,
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
  DateTime? repeatUntil;
  // Set only on a generated calendar instance; the database stores the series.
  DateTime? occurrenceDate;
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

class LinkedAccount {
  LinkedAccount({
    this.id,
    required this.platformName,
    required this.accountName,
    this.accountEmail,
    this.providerUrl,
    this.remoteUserId,
    this.categoryId,
    this.lastSyncTime,
  });

  int? id;
  String platformName;
  String accountName;
  String? accountEmail;
  String? providerUrl;
  String? remoteUserId;
  int? categoryId;
  DateTime? lastSyncTime;
}

class CanvasTaskImport {
  const CanvasTaskImport({
    required this.externalId,
    required this.title,
    required this.due,
    this.description = '',
  });

  final String externalId;
  final String title;
  final DateTime due;
  final String description;
}

class CanvasEventImport {
  const CanvasEventImport({
    required this.externalId,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.description = '',
    this.location,
  });

  final String externalId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String description;
  final String? location;
}

class CanvasSyncPayload {
  const CanvasSyncPayload({
    required this.accountName,
    required this.accountEmail,
    required this.remoteUserId,
    required this.providerUrl,
    required this.syncedAt,
    required this.tasks,
    required this.events,
    this.providerName = 'canvas',
  });

  final String accountName;
  final String? accountEmail;
  final String remoteUserId;
  final String providerUrl;
  final DateTime syncedAt;
  final List<CanvasTaskImport> tasks;
  final List<CanvasEventImport> events;
  final String providerName;
}
