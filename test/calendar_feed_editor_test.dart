import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/widgets/calendar/calendar_feed_editor.dart';

void main() {
  testWidgets('feed editor shows provider-specific instructions and labels', (
    tester,
  ) async {
    const cases = <(CalendarProvider, String, String)>[
      (
        CalendarProvider.canvas,
        'Paste the calendar feed link from Canvas.',
        'Connect Canvas calendar',
      ),
      (
        CalendarProvider.googleCalendar,
        'secret address in iCal format',
        'Connect Google Calendar',
      ),
      (
        CalendarProvider.outlook,
        'Paste the published ICS link from Outlook.',
        'Connect Outlook calendar',
      ),
    ];

    for (final (provider, instruction, buttonLabel) in cases) {
      await tester.pumpWidget(
        _app(
          CalendarFeedEditor(
            provider: provider,
            iconAsset: 'assets/img/import/canvas.png',
            connected: false,
            connecting: false,
            onConnect: (_) async => false,
          ),
        ),
      );

      expect(find.textContaining(instruction), findsOneWidget);
      expect(find.text(buttonLabel), findsOneWidget);
      expect(
        find.text('${provider.title} published .ics link'),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'connected feed editing keeps rejected input and clears on success',
    (tester) async {
      var acceptUpdate = false;
      final submittedUrls = <String>[];

      await tester.pumpWidget(
        _app(
          CalendarFeedEditor(
            provider: CalendarProvider.googleCalendar,
            iconAsset: 'assets/img/import/gcalendar.png',
            connected: true,
            connecting: false,
            onConnect: (url) async {
              submittedUrls.add(url);
              return acceptUpdate;
            },
          ),
        ),
      );

      await tester.tap(find.text('Change published link'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.enterText(field, 'https://calendar.example.test/new.ics');
      await tester.tap(find.text('Update link'));
      await tester.pumpAndSettle();

      expect(submittedUrls, ['https://calendar.example.test/new.ics']);
      expect(tester.widget<TextField>(field).controller!.text, isNotEmpty);

      acceptUpdate = true;
      await tester.tap(find.text('Update link'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Change published link'), findsOneWidget);
    },
  );

  testWidgets('connection changes clear the edit draft and leave edit mode', (
    tester,
  ) async {
    const key = ValueKey('feed-editor');
    CalendarFeedEditor editor({required bool connected}) => CalendarFeedEditor(
      key: key,
      provider: CalendarProvider.canvas,
      iconAsset: 'assets/img/import/canvas.png',
      connected: connected,
      connecting: false,
      onConnect: (_) async => true,
    );

    await tester.pumpWidget(_app(editor(connected: true)));
    await tester.tap(find.text('Change published link'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'draft link');

    await tester.pumpWidget(_app(editor(connected: false)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(find.text('Change published link'), findsNothing);
    expect(
      find.textContaining('Paste the calendar feed link from Canvas.'),
      findsOneWidget,
    );
  });
}

Widget _app(Widget editor) => MaterialApp(
  theme: appTheme,
  home: Scaffold(body: editor),
);
