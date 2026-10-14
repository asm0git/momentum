import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/widgets/calendar/calendar.dart';
import 'package:momentum/widgets/item_editor/date_picker_dialog.dart';
import 'package:momentum/widgets/item_editor/time_picker_dialog.dart';

void main() {
  testWidgets(
    'date picker clamps the initial day and returns the selected date',
    (tester) async {
      DateTime? selectedDate;
      final minimum = DateTime(2026, 10, 5, 17);

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                selectedDate = await showAppDatePickerDialog(
                  context,
                  initialDate: DateTime(2026, 10, 1, 8),
                  minimumDate: minimum,
                );
              },
              child: const Text('Pick date'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pick date'));
      await tester.pumpAndSettle();

      final calendar = tester.widget<CalendarWidget>(
        find.byType(CalendarWidget),
      );
      expect(calendar.initialDate, DateTime(2026, 10, 5));
      expect(calendar.minimumDate, DateTime(2026, 10, 5));
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      expect(selectedDate, DateTime(2026, 10, 5));
    },
  );

  testWidgets('time picker clamps an early initial time and can be dismissed', (
    tester,
  ) async {
    TimeOfDay? selectedTime;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              selectedTime = await showAppTimePickerDialog(
                context,
                initialTime: const TimeOfDay(hour: 8, minute: 0),
                minimumTime: const TimeOfDay(hour: 9, minute: 30),
              );
            },
            child: const Text('Pick time'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick time'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 9, minute: 30),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(selectedTime, isNull);
  });
}

Widget _app(Widget home) => MaterialApp(
  theme: appTheme,
  home: Scaffold(body: home),
);
