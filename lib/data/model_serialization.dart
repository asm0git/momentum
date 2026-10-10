import 'dart:convert';

import 'package:flutter/material.dart';

import '../data_models.dart';

DateTime taskDateTime(Task task) => DateTime(
  task.date.year,
  task.date.month,
  task.date.day,
  task.time.hour,
  task.time.minute,
);

DateTime eventStartDateTime(Event event) => DateTime(
  event.date.year,
  event.date.month,
  event.date.day,
  event.start.hour,
  event.start.minute,
);

DateTime eventEndDateTime(Event event) => DateTime(
  event.endDate.year,
  event.endDate.month,
  event.endDate.day,
  event.end.hour,
  event.end.minute,
);

Map<String, Object?> taskToMap(Task task) => {
  if (task.id != null) 'id': task.id,
  'category_id': task.categoryId,
  'title': task.title,
  'description': task.description,
  'due': taskDateTime(task).toIso8601String(),
  'repeat': task.repeat,
  'repeat_until': task.repeatUntil == null
      ? null
      : DateTime(
          task.repeatUntil!.year,
          task.repeatUntil!.month,
          task.repeatUntil!.day,
        ).toIso8601String(),
  'estimated_duration_minutes': task.estimatedDuration.inMinutes,
  'priority': task.priority,
  'is_completed': task.isChecked ? 1 : 0,
  'src_platform': task.srcPlatform,
  'external_id': task.externalId,
};

Task taskFromMap(Map<String, Object?> map) {
  final due = DateTime.parse(map['due']! as String);
  return Task(
    id: map['id'] as int?,
    categoryId: map['category_id'] as int?,
    title: map['title']! as String,
    date: DateTime(due.year, due.month, due.day),
    time: TimeOfDay(hour: due.hour, minute: due.minute),
    estimatedDuration: Duration(
      minutes: map['estimated_duration_minutes']! as int,
    ),
    repeat: map['repeat'] as String? ?? 'Never',
    repeatUntil: map['repeat_until'] == null
        ? null
        : DateTime.parse(map['repeat_until']! as String),
    isChecked: map['is_completed'] == 1,
    description: map['description'] as String? ?? '',
    priority: map['priority'] as int?,
    srcPlatform: map['src_platform'] as String?,
    externalId: map['external_id'] as String?,
  );
}

Map<String, Object?> eventToMap(Event event) => {
  if (event.id != null) 'id': event.id,
  'category_id': event.categoryId,
  'title': event.title,
  'start_time': eventStartDateTime(event).toIso8601String(),
  'end_time': eventEndDateTime(event).toIso8601String(),
  'location': event.location,
  'is_all_day': event.allDay ? 1 : 0,
  'is_current': event.isCurrent ? 1 : 0,
  'repeat': event.repeat,
  'repeat_until': event.repeatUntil == null
      ? null
      : DateTime(
          event.repeatUntil!.year,
          event.repeatUntil!.month,
          event.repeatUntil!.day,
        ).toIso8601String(),
  'notes': event.notes,
  'src_platform': event.srcPlatform,
  'external_id': event.externalId,
};

Event eventFromMap(Map<String, Object?> map) {
  final start = DateTime.parse(map['start_time']! as String);
  final end = DateTime.parse(map['end_time']! as String);
  return Event(
    id: map['id'] as int?,
    categoryId: map['category_id'] as int?,
    title: map['title']! as String,
    date: DateTime(start.year, start.month, start.day),
    endDate: DateTime(end.year, end.month, end.day),
    start: TimeOfDay(hour: start.hour, minute: start.minute),
    end: TimeOfDay(hour: end.hour, minute: end.minute),
    isCurrent: map['is_current'] == 1,
    allDay: map['is_all_day'] == 1,
    location: map['location'] as String?,
    notes: map['notes'] as String? ?? '',
    repeat: map['repeat'] as String? ?? 'Never',
    repeatUntil: map['repeat_until'] == null
        ? null
        : DateTime.parse(map['repeat_until']! as String),
    srcPlatform: map['src_platform'] as String?,
    externalId: map['external_id'] as String?,
  );
}

Map<String, Object?> categoryToMap(TaskCategory category) => {
  if (category.id != null) 'id': category.id,
  'title': category.title,
  'icon_name': category.iconName,
};

TaskCategory categoryFromMap(Map<String, Object?> map) => TaskCategory(
  id: map['id'] as int?,
  title: map['title']! as String,
  iconName: map['icon_name']! as String,
  items: const [],
);

Map<String, Object?> dailyPlanToMap(DailyPlan plan) => {
  if (plan.id != null) 'id': plan.id,
  'plan_date': DateTime(
    plan.planDate.year,
    plan.planDate.month,
    plan.planDate.day,
  ).toIso8601String(),
  'ordered_task_ids': jsonEncode(plan.orderedTaskIds),
  'generated_timestamp': plan.generatedTimestamp.toIso8601String(),
};

DailyPlan dailyPlanFromMap(Map<String, Object?> map) => DailyPlan(
  id: map['id'] as int?,
  planDate: DateTime.parse(map['plan_date']! as String),
  orderedTaskIds: (jsonDecode(map['ordered_task_ids']! as String) as List)
      .cast<int>(),
  generatedTimestamp: DateTime.parse(map['generated_timestamp']! as String),
);

Map<String, Object?> linkedAccountToMap(LinkedAccount account) => {
  if (account.id != null) 'id': account.id,
  'platform_name': account.platformName,
  'account_name': account.accountName,
  'account_email': account.accountEmail,
  'provider_url': account.providerUrl,
  'remote_user_id': account.remoteUserId,
  'category_id': account.categoryId,
  'last_sync_time': account.lastSyncTime?.toIso8601String(),
};

LinkedAccount linkedAccountFromMap(Map<String, Object?> map) => LinkedAccount(
  id: map['id'] as int?,
  platformName: map['platform_name']! as String,
  accountName: map['account_name'] as String? ?? 'Linked account',
  accountEmail: map['account_email'] as String?,
  providerUrl: map['provider_url'] as String?,
  remoteUserId: map['remote_user_id'] as String?,
  categoryId: map['category_id'] as int?,
  lastSyncTime: map['last_sync_time'] == null
      ? null
      : DateTime.parse(map['last_sync_time']! as String),
);
