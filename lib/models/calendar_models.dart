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
    CalendarProvider.canvas => 'provider_canvas',
    CalendarProvider.googleCalendar => 'provider_google',
    CalendarProvider.outlook => 'provider_outlook',
  };
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

class CalendarTaskImport {
  const CalendarTaskImport({
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

class CalendarEventImport {
  const CalendarEventImport({
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

class CalendarSyncPayload {
  const CalendarSyncPayload({
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
  final List<CalendarTaskImport> tasks;
  final List<CalendarEventImport> events;
  final String providerName;
}
