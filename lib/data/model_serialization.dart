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
  'repeat': _recurrenceRuleToDatabaseValue(task.repeat),
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
  'src_platform': task.sourcePlatform,
  'external_id': task.externalId,
};

Task taskFromMap(Map<String, Object?> map) {
  final due = _requiredDateTime(map, 'due');
  return Task(
    id: _optionalInt(map, 'id'),
    categoryId: _optionalInt(map, 'category_id'),
    title: _requiredString(map, 'title'),
    date: DateTime(due.year, due.month, due.day),
    time: TimeOfDay(hour: due.hour, minute: due.minute),
    estimatedDuration: Duration(
      minutes: _requiredInt(map, 'estimated_duration_minutes'),
    ),
    repeat: _recurrenceRuleFromDatabaseValue(map['repeat']),
    repeatUntil: _optionalDateTime(map, 'repeat_until'),
    isChecked: map['is_completed'] == 1,
    description: optionalStringFromMap(map, 'description') ?? '',
    priority: _optionalInt(map, 'priority'),
    sourcePlatform: optionalStringFromMap(map, 'src_platform'),
    externalId: optionalStringFromMap(map, 'external_id'),
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
  'repeat': _recurrenceRuleToDatabaseValue(event.repeat),
  'repeat_until': event.repeatUntil == null
      ? null
      : DateTime(
          event.repeatUntil!.year,
          event.repeatUntil!.month,
          event.repeatUntil!.day,
        ).toIso8601String(),
  'notes': event.notes,
  'src_platform': event.sourcePlatform,
  'external_id': event.externalId,
};

Event eventFromMap(Map<String, Object?> map) {
  final start = _requiredDateTime(map, 'start_time');
  final end = _requiredDateTime(map, 'end_time');
  return Event(
    id: _optionalInt(map, 'id'),
    categoryId: _optionalInt(map, 'category_id'),
    title: _requiredString(map, 'title'),
    date: DateTime(start.year, start.month, start.day),
    endDate: DateTime(end.year, end.month, end.day),
    start: TimeOfDay(hour: start.hour, minute: start.minute),
    end: TimeOfDay(hour: end.hour, minute: end.minute),
    isCurrent: map['is_current'] == 1,
    allDay: map['is_all_day'] == 1,
    location: optionalStringFromMap(map, 'location'),
    notes: optionalStringFromMap(map, 'notes') ?? '',
    repeat: _recurrenceRuleFromDatabaseValue(map['repeat']),
    repeatUntil: _optionalDateTime(map, 'repeat_until'),
    sourcePlatform: optionalStringFromMap(map, 'src_platform'),
    externalId: optionalStringFromMap(map, 'external_id'),
  );
}

Map<String, Object?> categoryToMap(TaskCategory category) => {
  if (category.id != null) 'id': category.id,
  'title': category.title,
  'icon_name': category.iconName,
};

TaskCategory categoryFromMap(Map<String, Object?> map) => TaskCategory(
  id: _optionalInt(map, 'id'),
  title: _requiredString(map, 'title'),
  iconName: _requiredString(map, 'icon_name'),
  items: const [],
);

String _recurrenceRuleToDatabaseValue(RecurrenceRule rule) => switch (rule) {
  RecurrenceRule.never => 'Never',
  RecurrenceRule.daily => 'Every day',
  RecurrenceRule.weekly => 'Every week',
  RecurrenceRule.monthly => 'Every month',
  RecurrenceRule.yearly => 'Every year',
};

RecurrenceRule _recurrenceRuleFromDatabaseValue(Object? value) =>
    switch (value) {
      'Never' => RecurrenceRule.never,
      'Every day' => RecurrenceRule.daily,
      'Every week' => RecurrenceRule.weekly,
      'Every month' => RecurrenceRule.monthly,
      'Every year' => RecurrenceRule.yearly,
      _ => RecurrenceRule.never,
    };

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
  id: _optionalInt(map, 'id'),
  planDate: _requiredDateTime(map, 'plan_date'),
  orderedTaskIds: _requiredIntegerList(map, 'ordered_task_ids'),
  generatedTimestamp: _requiredDateTime(map, 'generated_timestamp'),
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
  id: _optionalInt(map, 'id'),
  platformName: _requiredString(map, 'platform_name'),
  accountName: optionalStringFromMap(map, 'account_name') ?? 'Linked account',
  accountEmail: optionalStringFromMap(map, 'account_email'),
  providerUrl: optionalStringFromMap(map, 'provider_url'),
  remoteUserId: optionalStringFromMap(map, 'remote_user_id'),
  categoryId: _optionalInt(map, 'category_id'),
  lastSyncTime: _optionalDateTime(map, 'last_sync_time'),
);

String _requiredString(Map<String, Object?> map, String column) {
  final value = map[column];
  if (value is String) return value;
  throw FormatException('Required column "$column" must be a string.', value);
}

int _requiredInt(Map<String, Object?> map, String column) {
  final value = map[column];
  if (value is int) return value;
  throw FormatException('Required column "$column" must be an integer.', value);
}

int? _optionalInt(Map<String, Object?> map, String column) {
  final value = map[column];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException(
    'Optional column "$column" must be an integer or null.',
    value,
  );
}

String? optionalStringFromMap(Map<String, Object?> map, String column) {
  final value = map[column];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException(
    'Optional column "$column" must be a string or null.',
    value,
  );
}

DateTime _requiredDateTime(Map<String, Object?> map, String column) =>
    _parseDateTime(_requiredString(map, column), column);

DateTime? _optionalDateTime(Map<String, Object?> map, String column) {
  final value = map[column];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException(
      'Optional column "$column" must be a date/time string or null.',
      value,
    );
  }
  return _parseDateTime(value, column);
}

DateTime _parseDateTime(String value, String column) {
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw FormatException(
      'Column "$column" must contain a valid date/time.',
      value,
    );
  }
}

List<int> _requiredIntegerList(Map<String, Object?> map, String column) {
  final encoded = _requiredString(map, column);
  Object? decoded;
  try {
    decoded = jsonDecode(encoded);
  } on FormatException {
    throw FormatException('Column "$column" must contain valid JSON.', encoded);
  }
  if (decoded is List && decoded.every((value) => value is int)) {
    return decoded.cast<int>().toList(growable: false);
  }
  throw FormatException(
    'Column "$column" must contain a JSON list of integers.',
    encoded,
  );
}
