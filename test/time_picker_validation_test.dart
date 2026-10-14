import 'dart:ui' show ImageByteFormat, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/item_editor/add_item_popup.dart';
import 'package:momentum/widgets/item_editor/time_picker_dialog.dart';
import 'package:provider/provider.dart';

const _error = 'End time cannot be before start time.';
const _confirm = ValueKey('time-picker-confirm');
const _entryMode = ValueKey('time-picker-entry-mode');
const _hourInput = ValueKey('time-picker-hour-input');
const _minuteInput = ValueKey('time-picker-minute-input');

void main() {
  testWidgets(
    'hovering a dial numeral paints a complete circular highlight above the face',
    (tester) async {
      await _openPicker(tester);
      final numeral = find.byKey(const ValueKey('time-picker-dial-hour-3'));
      final center = tester.getCenter(numeral);
      final circleProbe = center + const Offset(0, -18);
      final cornerProbe = center + const Offset(-22, -22);
      final before = await _capturePixels(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(center);
      await tester.pumpAndSettle();
      final after = await _capturePixels(tester);
      expect(
        _pixelAt(after, circleProbe),
        isNot(_pixelAt(before, circleProbe)),
      );
      expect(_pixelAt(after, cornerProbe), _pixelAt(before, cornerProbe));
      await mouse.removePointer();
    },
  );

  testWidgets(
    'confirming an invalid dial time grows the dialog and preserves its controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      TimeOfDay? result;
      await _openPicker(
        tester,
        validate: _afterNine,
        onSelected: (time) => result = time,
      );
      expect(find.text(_error), findsNothing);
      await tester.tap(find.byKey(const ValueKey('time-picker-dial-hour-8')));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsNothing);

      final dialog = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      final controls = find.byKey(const ValueKey('time-picker-controls'));
      final dial = find.byKey(const ValueKey('time-picker-dial-size'));
      final originalHeight = tester.getSize(dialog).height;
      final controlsSize = tester.getSize(controls);
      final dialSize = tester.getSize(dial);
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();

      expect(find.byType(AppTimePickerDialog), findsOneWidget);
      expect(result, isNull);
      final error = find.byKey(const ValueKey('time-picker-error'));
      expect(tester.widget<Text>(error).style?.color, AppColors.error);
      final heading = find.byKey(const ValueKey('time-picker-heading'));
      expect(
        tester.getTopLeft(error).dy - tester.getBottomLeft(heading).dy,
        closeTo(AppSpacing.sm, 0.1),
      );
      expect(
        tester.getTopLeft(controls).dy - tester.getBottomLeft(error).dy,
        closeTo(AppSpacing.sm + AppSpacing.md, 0.1),
      );
      expect(
        tester.getSize(dialog).height - originalHeight,
        closeTo(tester.getSize(error).height + AppSpacing.sm * 2, 0.1),
      );
      expect(tester.getSize(controls), controlsSize);
      expect(tester.getSize(dial), dialSize);

      // A valid hour removes the message without an additional confirmation.
      await tester.tap(find.byKey(const ValueKey('time-picker-hour-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('time-picker-dial-hour-10')));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsNothing);
      expect(tester.getSize(dialog).height, closeTo(originalHeight, 0.1));
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(result, const TimeOfDay(hour: 10, minute: 0));
    },
  );

  testWidgets(
    'keyboard confirmation validates the time and clears the error on correction',
    (tester) async {
      TimeOfDay? result;
      await _openPicker(
        tester,
        validate: _afterNine,
        onSelected: (time) => result = time,
      );
      await _enterTime(tester, '8', '30');
      expect(find.text(_error), findsNothing);
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(find.byKey(_hourInput), '9');
      await tester.pumpAndSettle();
      expect(find.text(_error), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // The hour field moves focus forward rather than accepting the dialog.
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(result, const TimeOfDay(hour: 9, minute: 30));
    },
  );

  for (final dismissal in ['cancel', 'back', 'outside']) {
    testWidgets(
      '$dismissal dismisses an invalid selection without changing its value',
      (tester) async {
        TimeOfDay? returned = const TimeOfDay(hour: 10, minute: 0);
        var completed = false;
        await _openPicker(
          tester,
          validate: _afterNine,
          onSelected: (time) {
            returned = time;
            completed = true;
          },
        );
        await _enterTime(tester, '8', '00');
        await tester.tap(find.byKey(_confirm));
        await tester.pumpAndSettle();
        expect(find.text(_error), findsOneWidget);
        if (dismissal == 'cancel') {
          await tester.tap(find.byKey(const ValueKey('time-picker-cancel')));
        } else if (dismissal == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
        await tester.pumpAndSettle();
        expect(completed, isTrue);
        expect(returned, isNull);
        expect(find.byType(AppTimePickerDialog), findsNothing);
      },
    );
  }

  testWidgets('changing AM to PM makes an earlier morning selection valid', (
    tester,
  ) async {
    TimeOfDay? result;
    await _openPicker(
      tester,
      validate: _afterNine,
      onSelected: (time) => result = time,
    );
    await _enterTime(tester, '8', '00');
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('time-picker-pm')));
    await tester.pumpAndSettle();
    expect(find.text(_error), findsNothing);
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 20, minute: 0));
  });

  testWidgets('24-hour dial and keyboard entry preserve midnight', (
    tester,
  ) async {
    TimeOfDay? result;
    await _openPicker(
      tester,
      use24Hours: true,
      onSelected: (time) => result = time,
    );
    expect(find.byKey(const ValueKey('time-picker-am')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('time-picker-dial-hour-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_entryMode));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(_hourInput)).controller?.text,
      '00',
    );
    await tester.enterText(find.byKey(_minuteInput), '15');
    await tester.tap(find.byKey(_confirm));
    await tester.pumpAndSettle();
    expect(result, const TimeOfDay(hour: 0, minute: 15));
  });

  testWidgets(
    'the clock face supports pointer dragging for individual minutes',
    (tester) async {
      TimeOfDay? result;
      await _openPicker(tester, onSelected: (time) => result = time);
      await tester.tap(find.byKey(const ValueKey('time-picker-minute-select')));
      await tester.pumpAndSettle();
      final dial = tester.getRect(
        find.byKey(const ValueKey('time-picker-dial-size')),
      );
      final gesture = await tester.startGesture(
        dial.center + const Offset(0, -100),
      );
      await gesture.moveTo(dial.center + const Offset(91.35, -40.67));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(result?.minute, 11);
    },
  );

  testWidgets(
    'empty and out-of-range keyboard values do not close the picker',
    (tester) async {
      await _openPicker(tester);
      await _enterTime(tester, '', '60');
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.byType(AppTimePickerDialog), findsOneWidget);
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(AppTimePickerDialog)),
      );
      expect(find.text(localizations.invalidTimeLabel), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('time-picker-pm')));
      await tester.pumpAndSettle();
      expect(find.text(localizations.invalidTimeLabel), findsOneWidget);
      await tester.enterText(find.byKey(_hourInput), '10');
      await tester.enterText(find.byKey(_minuteInput), '15');
      await tester.pumpAndSettle();
      expect(find.text(localizations.invalidTimeLabel), findsNothing);
    },
  );

  testWidgets(
    'small screens and larger text scroll without compressing the dial',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openPicker(tester, validate: _afterNine, textScale: 2);
      final dial = find.byKey(const ValueKey('time-picker-dial-size'));
      final dialSize = tester.getSize(dial);
      await tester.tap(find.byKey(const ValueKey('time-picker-dial-hour-8')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(_confirm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsOneWidget);
      expect(tester.getSize(dial), dialSize);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('time-picker-cancel')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('time-picker-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(AppTimePickerDialog), findsNothing);
    },
  );

  testWidgets(
    'event editor blocks an earlier same-day end and keeps its previous time',
    (tester) async {
      await _openEventEditor(tester, _event());
      await _openEndPicker(tester);
      await _enterTime(tester, '8', '00');
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('time-picker-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('10:00 AM'), findsOneWidget);
    },
  );

  testWidgets(
    'event editor accepts next-day midnight and keeps equal-time normalization',
    (tester) async {
      await _openEventEditor(
        tester,
        _event(
          start: const TimeOfDay(hour: 23, minute: 59),
          end: const TimeOfDay(hour: 1, minute: 0),
          endDate: DateTime(2026, 10, 16),
        ),
      );
      await _openEndPicker(tester);
      await _enterTime(tester, '12', '00');
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsNothing);
      expect(find.byType(AppTimePickerDialog), findsNothing);
      expect(find.text('12:00 AM'), findsOneWidget);

      await _openEventEditor(tester, _event());
      await _openEndPicker(tester);
      await _enterTime(tester, '9', '00');
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsNothing);
      expect(find.text('9:01 AM'), findsOneWidget);
    },
  );

  testWidgets(
    'same-day midnight is rejected while task deadlines have no end-time constraint',
    (tester) async {
      await _openEventEditor(
        tester,
        _event(
          start: const TimeOfDay(hour: 23, minute: 0),
          end: const TimeOfDay(hour: 23, minute: 30),
        ),
      );
      await _openEndPicker(tester);
      await _enterTime(tester, '12', '00');
      await tester.tap(find.byKey(const ValueKey('time-picker-am')));
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text(_error), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('time-picker-cancel')));
      await tester.pumpAndSettle();

      await _openEventEditor(
        tester,
        Task(
          title: 'Read chapter',
          date: DateTime(2026, 10, 15),
          isChecked: false,
          time: const TimeOfDay(hour: 9, minute: 0),
          estimatedDuration: const Duration(minutes: 30),
        ),
      );
      await tester.tap(find.text('9:00 AM'));
      await tester.pumpAndSettle();
      await _enterTime(tester, '8', '00');
      await tester.tap(find.byKey(_confirm));
      await tester.pumpAndSettle();
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text(_error), findsNothing);
    },
  );

  testWidgets('all-day events have no time picker or end-time warning', (
    tester,
  ) async {
    final event = _event()..allDay = true;
    await _openEventEditor(tester, event);
    expect(find.text('Start Time'), findsNothing);
    expect(find.text('End Time'), findsNothing);
    expect(find.byType(AppTimePickerDialog), findsNothing);
    expect(find.text(_error), findsNothing);
  });
}

String? _afterNine(TimeOfDay time) => time.hour < 9 ? _error : null;

Future<void> _openPicker(
  WidgetTester tester, {
  String? Function(TimeOfDay time)? validate,
  ValueChanged<TimeOfDay?>? onSelected,
  bool use24Hours = false,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: use24Hours,
          textScaler: TextScaler.linear(textScale),
        ),
        child: RepaintBoundary(
          key: const ValueKey('time-picker-test-surface'),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              final result = await showAppTimePickerDialog(
                context,
                initialTime: const TimeOfDay(hour: 10, minute: 0),
                validateSelection: validate,
              );
              onSelected?.call(result);
            },
            child: const Text('Open picker'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open picker'));
  await tester.pumpAndSettle();
}

Future<({List<int> pixels, int width})> _capturePixels(
  WidgetTester tester,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('time-picker-test-surface')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ImageByteFormat.rawRgba);
      return (pixels: data!.buffer.asUint8List(), width: image.width);
    } finally {
      image.dispose();
    }
  }))!;
}

List<int> _pixelAt(({List<int> pixels, int width}) image, Offset point) {
  final index = (point.dy.round() * image.width + point.dx.round()) * 4;
  return image.pixels.sublist(index, index + 4);
}

Future<void> _enterTime(WidgetTester tester, String hour, String minute) async {
  await tester.tap(find.byKey(_entryMode));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(_hourInput), hour);
  await tester.enterText(find.byKey(_minuteInput), minute);
  await tester.pumpAndSettle();
}

Event _event({
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0),
  TimeOfDay end = const TimeOfDay(hour: 10, minute: 0),
  DateTime? endDate,
}) => Event(
  title: 'Study group',
  date: DateTime(2026, 10, 15),
  start: start,
  end: end,
  endDate: endDate,
  isCurrent: false,
  allDay: false,
);

Future<void> _openEventEditor(WidgetTester tester, PlannerItem event) async {
  final planner = PlannerState(startAutomaticEventFocusTimer: false);
  addTearDown(planner.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: ChangeNotifierProvider.value(
        value: planner,
        child: Scaffold(
          body: SingleChildScrollView(
            child: AddItemPopup(key: ObjectKey(event), initialItem: event),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEndPicker(WidgetTester tester) async {
  final row = find
      .ancestor(of: find.text('End Time'), matching: find.byType(Row))
      .first;
  final button = find.descendant(of: row, matching: find.byType(InkWell)).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
