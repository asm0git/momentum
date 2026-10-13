import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/screens/add_calendars_screen.dart';
import 'package:momentum/services/calendar_backend_client.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late _FakeCalendarBackend backend;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('momentum_calendar_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/planner.db',
      seedOnCreate: false,
    );
    backend = _FakeCalendarBackend();
    planner = PlannerState(
      repository: PlannerRepository(databaseHelper: databaseHelper),
      calendarBackend: backend,
      autoSyncCalendarsOnStartup: false,
    );
    await planner.initialize();
  });

  tearDown(() async {
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets('Canvas expands inline and validates its feed link', (
    tester,
  ) async {
    _setIPhone13Viewport(tester);
    await tester.pumpWidget(_app(planner, home: const AddCalendarsScreen()));
    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Outlook'), findsOneWidget);
    expect(find.text('Coming soon'), findsNothing);

    await tester.tap(find.text('Canvas'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Connect Canvas calendar'), findsOneWidget);

    await tester.tap(find.text('Connect Canvas calendar'));
    await tester.pump();
    expect(
      find.text('Paste a valid HTTPS .ics link published by Canvas.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the selected provider panel remains expanded', (
    tester,
  ) async {
    _setIPhone13Viewport(tester); // <-- add this line
    await tester.pumpWidget(_app(planner, home: const AddCalendarsScreen()));

    await tester.tap(find.text('Google Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Google Calendar'), findsOneWidget);

    await tester.tap(find.text('Outlook'));
    await tester.pumpAndSettle();
    expect(find.text('Connect Outlook calendar'), findsOneWidget);
    expect(find.text('Connect Google Calendar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google Calendar connects with its published ICS link', (
    tester,
  ) async {
    _setIPhone13Viewport(tester); // <-- add this line
    await tester.pumpWidget(_app(planner, home: const AddCalendarsScreen()));
    await tester.tap(find.text('Google Calendar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('secret address in iCal format'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'https://calendar.google.com/calendar/ical/a/private/b/basic.ics',
    );
    await tester.tap(find.text('Connect Google Calendar'));
    await tester.pump(); // <-- replaces pumpAndSettle()

    // Real SQLite I/O needs the real event loop, not the test's fake clock.
    await tester.runAsync(() async {
      final timeout = DateTime.now().add(const Duration(seconds: 5));
      while ((planner
                      .statusForProvider(CalendarProvider.googleCalendar)
                      ?.connected !=
                  true ||
              planner.isProviderSyncing(CalendarProvider.googleCalendar)) &&
          DateTime.now().isBefore(timeout)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('Google Calendar connected and synced.'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-sync-success-google')),
      findsOneWidget,
    );
    expect(find.text('Connect Canvas calendar'), findsNothing);
  });

  testWidgets('connected feed editor can cancel or update its link', (
    tester,
  ) async {
    _setIPhone13Viewport(tester);
    await tester.runAsync(() async {
      await planner.connectCalendarIcsFeed(
        CalendarProvider.googleCalendar,
        'https://calendar.google.test/initial.ics',
      );
      await planner.syncProvider(CalendarProvider.googleCalendar);
    });
    await tester.pumpWidget(_app(planner, home: const AddCalendarsScreen()));
    await tester.tap(find.text('Google Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Change published link'), findsOneWidget);
    await tester.tap(find.text('Change published link'));
    await tester.pumpAndSettle();
    expect(find.text('Update link'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'https://calendar.google.test/unused.ics',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Change published link'), findsOneWidget);

    await tester.tap(find.text('Change published link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://calendar.google.test/updated.ics',
    );
    await tester.ensureVisible(find.text('Update link'));
    await tester.tap(find.text('Update link'));
    await tester.pump();
    await tester.runAsync(() async {
      final timeout = DateTime.now().add(const Duration(seconds: 5));
      while ((backend.connectedFeedUrls[CalendarProvider.googleCalendar] !=
                  'https://calendar.google.test/updated.ics' ||
              planner.isProviderSyncing(CalendarProvider.googleCalendar)) &&
          DateTime.now().isBefore(timeout)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(
      backend.connectedFeedUrls[CalendarProvider.googleCalendar],
      'https://calendar.google.test/updated.ics',
    );
    expect(find.text('Change published link'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Google Calendar connected and synced.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a connected stale provider syncs automatically', (
    tester,
  ) async {
    backend.providerStatuses[CalendarProvider.canvas] =
        const CalendarConnectionStatus(
          connected: true,
          providerUrl: 'https://canvas.school.edu',
          accountName: 'Student',
          accountEmail: 'student@example.test',
          remoteUserId: '18',
        );
    await tester.pumpWidget(_app(planner, home: const AddCalendarsScreen()));
    await tester.tap(find.text('Canvas'));
    await tester.pump();
    await tester.runAsync(() async {
      final timeout = DateTime.now().add(const Duration(seconds: 5));
      while ((backend.canvasSyncCount == 0 ||
              planner.isProviderSyncing(CalendarProvider.canvas)) &&
          DateTime.now().isBefore(timeout)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(backend.canvasSyncCount, 1);
    expect(find.text('Sync complete.'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
  });

  testWidgets('inline sync and disconnect preserve imported tasks', (
    tester,
  ) async {
    backend.providerStatuses[CalendarProvider.canvas] =
        CalendarConnectionStatus(
          connected: true,
          providerUrl: 'https://canvas.school.edu',
          accountName: 'Student',
          accountEmail: 'student@example.test',
          remoteUserId: '18',
          lastSyncTime: DateTime.now(),
        );
    await tester.runAsync(() async {
      await planner.refreshProviderStatus(CalendarProvider.canvas);
      await planner.syncProvider(CalendarProvider.canvas);
    });

    backend.nextCanvasSync = CalendarSyncPayload(
      accountName: 'Student',
      accountEmail: 'student@example.test',
      remoteUserId: '18',
      providerUrl: 'https://canvas.school.edu',
      syncedAt: DateTime.now(),
      tasks: [
        CalendarTaskImport(
          externalId: 'assignment:course_1:8',
          title: 'Biology quiz',
          due: DateTime(2026, 10, 12, 15),
          description: 'Chapter 4',
        ),
      ],
      events: const [],
    );
    await tester.pumpWidget(_app(planner, home: const AddCalendarsScreen()));
    await tester.tap(find.text('Canvas'));
    await tester.pumpAndSettle();
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.textContaining('Last synced'), findsOneWidget);

    await tester.tap(find.text('Sync now'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(planner.items.whereType<Task>().single.title, 'Biology quiz');
    expect(find.text('Sync complete.'), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(
      find.text('Imported items will remain in Momentum.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final timeout = DateTime.now().add(const Duration(seconds: 5));
      while (planner.statusForProvider(CalendarProvider.canvas)?.connected ==
              true &&
          DateTime.now().isBefore(timeout)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(
      planner.statusForProvider(CalendarProvider.canvas)?.connected,
      isFalse,
    );
    expect(planner.items.whereType<Task>().single.title, 'Biology quiz');
    expect(find.text('Connect Canvas calendar'), findsOneWidget);
  });

  testWidgets('inline sync shows progress and reports provider errors', (
    tester,
  ) async {
    backend.providerStatuses[CalendarProvider.canvas] =
        CalendarConnectionStatus(
          connected: true,
          providerUrl: 'https://canvas.school.edu',
          accountName: 'Student',
          remoteUserId: '18',
          lastSyncTime: DateTime.now(),
        );
    await tester.runAsync(() async {
      await planner.refreshProviderStatus(CalendarProvider.canvas);
      await planner.syncProvider(CalendarProvider.canvas);
    });

    await tester.pumpWidget(_app(planner, home: const AddCalendarsScreen()));
    await tester.tap(find.text('Canvas'));
    await tester.pumpAndSettle();

    final pendingSync = Completer<CalendarSyncPayload>();
    backend.pendingCanvasSync = pendingSync;
    await tester.tap(find.text('Sync now'));
    await tester.pump();
    expect(find.text('Syncing…'), findsOneWidget);

    pendingSync.complete(_payloadForTest());
    await _waitForCanvasSync(tester, planner);
    expect(find.text('Sync complete.'), findsOneWidget);

    backend.nextCanvasSyncError = StateError('Calendar service unavailable.');
    await tester.tap(find.text('Sync now'));
    await tester.pump();
    await _waitForCanvasSync(tester, planner);
    expect(find.text('Calendar service unavailable.'), findsOneWidget);
  });
}

void _setIPhone13Viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1170, 2532);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _waitForCanvasSync(
  WidgetTester tester,
  PlannerState planner,
) async {
  await tester.runAsync(() async {
    final timeout = DateTime.now().add(const Duration(seconds: 5));
    while (planner.isProviderSyncing(CalendarProvider.canvas) &&
        DateTime.now().isBefore(timeout)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpAndSettle();
}

CalendarSyncPayload _payloadForTest({
  String taskTitle = 'Test calendar item',
  String externalId = 'test-item',
}) => CalendarSyncPayload(
  accountName: 'Student',
  accountEmail: 'student@example.test',
  remoteUserId: '18',
  providerUrl: 'https://canvas.school.edu',
  syncedAt: DateTime.now(),
  tasks: [
    CalendarTaskImport(
      externalId: externalId,
      title: taskTitle,
      due: DateTime(2026, 10, 12, 15),
      description: '',
    ),
  ],
  events: const [],
);

Widget _app(PlannerState planner, {required Widget home}) =>
    ChangeNotifierProvider<PlannerState>.value(
      value: planner,
      child: MaterialApp(theme: appTheme, home: home),
    );

class _FakeCalendarBackend implements ProviderCalendarBackend {
  final Map<CalendarProvider, String> connectedFeedUrls = {};
  final Map<CalendarProvider, CalendarConnectionStatus> providerStatuses = {
    CalendarProvider.canvas: const CalendarConnectionStatus(connected: false),
    CalendarProvider.googleCalendar: const CalendarConnectionStatus(
      connected: false,
    ),
    CalendarProvider.outlook: const CalendarConnectionStatus(connected: false),
  };
  CalendarSyncPayload? nextCanvasSync;
  Completer<CalendarSyncPayload>? pendingCanvasSync;
  Object? nextCanvasSyncError;
  int canvasSyncCount = 0;

  @override
  Uri providerOAuthStartUri(CalendarProvider provider, {String? siteUrl}) =>
      Uri.parse('https://calendar.example.test/${provider.key}/oauth');

  @override
  Future<void> connectCalendarIcsFeed(
    CalendarProvider provider,
    String url,
  ) async {
    connectedFeedUrls[provider] = url;
    providerStatuses[provider] = CalendarConnectionStatus(
      connected: true,
      providerUrl: '${provider.key}-published-ics',
      accountName: '${provider.title} published calendar',
      remoteUserId: 'test-feed',
    );
  }

  @override
  Future<CalendarConnectionStatus> providerStatus(
    CalendarProvider provider,
  ) async =>
      providerStatuses[provider] ??
      const CalendarConnectionStatus(connected: false);

  @override
  Future<CalendarSyncPayload> syncProvider(CalendarProvider provider) async {
    if (provider == CalendarProvider.canvas) canvasSyncCount++;
    final error = provider == CalendarProvider.canvas
        ? nextCanvasSyncError
        : null;
    nextCanvasSyncError = null;
    if (error != null) throw error;
    final pending = provider == CalendarProvider.canvas
        ? pendingCanvasSync
        : null;
    if (provider == CalendarProvider.canvas) pendingCanvasSync = null;
    final payload = pending == null
        ? (provider == CalendarProvider.canvas ? nextCanvasSync : null) ??
              _payload(provider)
        : await pending.future;
    if (provider == CalendarProvider.canvas) nextCanvasSync = null;
    providerStatuses[provider] = CalendarConnectionStatus(
      connected: true,
      providerUrl: payload.providerUrl,
      accountName: payload.accountName,
      accountEmail: payload.accountEmail,
      remoteUserId: payload.remoteUserId,
      lastSyncTime: payload.syncedAt,
    );
    return payload;
  }

  @override
  Future<void> disconnectProvider(CalendarProvider provider) async {
    providerStatuses[provider] = const CalendarConnectionStatus(
      connected: false,
    );
  }

  CalendarSyncPayload _payload(CalendarProvider provider) =>
      CalendarSyncPayload(
        accountName: 'Student',
        accountEmail: 'student@example.test',
        remoteUserId: '18',
        providerUrl: provider == CalendarProvider.canvas
            ? 'https://canvas.school.edu'
            : 'https://${provider.key}.example.test',
        syncedAt: DateTime.now(),
        tasks: const [],
        events: const [],
        providerName: provider.key,
      );
}
