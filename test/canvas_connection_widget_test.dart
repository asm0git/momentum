import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/database_helper.dart';
import 'package:momentum/data/planner_repository.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/screens/add_calendars_screen.dart';
import 'package:momentum/screens/canvas_connection_screen.dart';
import 'package:momentum/screens/calendar_provider_connection_screen.dart';
import 'package:momentum/services/canvas_backend_client.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late DatabaseHelper databaseHelper;
  late _FakeCanvasBackend backend;
  late PlannerState planner;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('momentum_canvas_');
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/planner.db',
      seedOnCreate: false,
    );
    backend = _FakeCanvasBackend();
    planner = PlannerState(
      repository: PlannerRepository(databaseHelper: databaseHelper),
      canvasBackend: backend,
      autoSyncCanvasOnStartup: false,
    );
    await planner.initialize();
  });

  tearDown(() async {
    planner.dispose();
    await databaseHelper.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets('Add Calendars opens the Canvas connection screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        planner,
        home: const AddCalendarsScreen(),
        routes: {'/canvas': (_) => const CanvasConnectionScreen()},
      ),
    );
    expect(find.text('Google Calendar'), findsOneWidget);
    expect(find.text('Outlook'), findsOneWidget);
    expect(find.text('Coming soon'), findsNothing);
    await tester.tap(find.text('Canvas'));
    await tester.pumpAndSettle();

    expect(find.text('Connect with Canvas'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Google and Outlook are selectable providers', (tester) async {
    await tester.pumpWidget(
      _app(
        planner,
        home: const AddCalendarsScreen(),
        routes: {
          '/google': (_) => const CalendarProviderConnectionScreen(
            provider: CalendarProvider.googleCalendar,
          ),
          '/outlook': (_) => const CalendarProviderConnectionScreen(
            provider: CalendarProvider.outlook,
          ),
        },
      ),
    );
    await tester.tap(find.text('Google Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Connect with Google Calendar'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outlook'));
    await tester.pumpAndSettle();
    expect(find.text('Connect with Outlook'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('category rename and Canvas sync refresh planner data', (
    tester,
  ) async {
    backend.connectionStatus = CanvasConnectionStatus(
      connected: true,
      providerUrl: 'https://canvas.school.edu',
      accountName: 'Student',
      accountEmail: 'student@example.test',
      remoteUserId: '18',
      lastSyncTime: DateTime.now(),
    );
    await tester.runAsync(() async {
      await planner.refreshCanvasStatus();
      await planner.syncCanvas();
    });
    await tester.pumpWidget(
      _app(planner, home: const CanvasConnectionScreen()),
    );
    await tester.pumpAndSettle();

    expect(planner.canvasAccount?.categoryId, isNotNull);
    expect(find.text('Canvas category'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Classes');
    await tester.tap(find.byTooltip('Save category name'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(planner.categories.single.title, 'Classes');

    backend.nextSync = CanvasSyncPayload(
      accountName: 'Student',
      accountEmail: 'student@example.test',
      remoteUserId: '18',
      providerUrl: 'https://canvas.school.edu',
      syncedAt: DateTime.now(),
      tasks: [
        CanvasTaskImport(
          externalId: 'assignment:course_1:8',
          title: 'Biology quiz',
          due: DateTime(2026, 10, 12, 15),
          description: 'Chapter 4',
        ),
      ],
      events: const [],
    );
    await tester.tap(find.text('Sync now'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(planner.items.whereType<Task>().single.title, 'Biology quiz');
    expect(
      planner.items.whereType<Task>().single.categoryId,
      planner.categories.single.id,
    );
    expect(find.text('Sync complete.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(planner.isCanvasConnected, isFalse);
    expect(planner.items.whereType<Task>().single.title, 'Biology quiz');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _app(
  PlannerState planner, {
  required Widget home,
  Map<String, WidgetBuilder> routes = const {},
}) => ChangeNotifierProvider<PlannerState>.value(
  value: planner,
  child: MaterialApp(theme: appTheme, home: home, routes: routes),
);

class _FakeCanvasBackend implements CanvasBackend {
  CanvasConnectionStatus connectionStatus = const CanvasConnectionStatus(
    connected: false,
  );
  CanvasSyncPayload? nextSync;

  @override
  Uri oauthStartUri(String siteUrl) =>
      Uri.parse('https://canvas.school.edu/oauth');

  @override
  Future<CanvasConnectionStatus> status() async => connectionStatus;

  @override
  Future<CanvasSyncPayload> sync() async =>
      nextSync ??
      CanvasSyncPayload(
        accountName: 'Student',
        accountEmail: 'student@example.test',
        remoteUserId: '18',
        providerUrl: 'https://canvas.school.edu',
        syncedAt: DateTime.now(),
        tasks: const [],
        events: const [],
      );

  @override
  Future<void> disconnect() async {
    connectionStatus = const CanvasConnectionStatus(connected: false);
  }
}
