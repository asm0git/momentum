import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/data/pomodoro_preset.dart';
import 'package:momentum/screens/timer_screen.dart';
import 'package:momentum/services/focus_preset_preferences.dart';
import 'package:momentum/state/focus_timer_state.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/pill_action_button.dart';
import 'package:momentum/widgets/focus_preset.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('add preset button saves, selects, and rejects duplicates', (
    tester,
  ) async {
    const existingPreset = PomodoroPreset(workMinutes: 20, breakMinutes: 5);
    final focusTimer = FocusTimerState(
      workMinutes: 12,
      breakMinutes: 3,
      startTicker: false,
      customPresets: [existingPreset],
    );
    addTearDown(focusTimer.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PlannerState()),
          ChangeNotifierProvider.value(value: focusTimer),
        ],
        child: MaterialApp(theme: appTheme, home: const TimerScreen()),
      ),
    );

    final addButtonFinder = find.byKey(const ValueKey('timer-add-preset'));
    expect(addButtonFinder, findsOneWidget);
    final addButton = tester.widget<PillActionButton>(addButtonFinder);
    expect(addButton.label, 'Add preset');
    expect(addButton.leadingIcon, Icons.add_circle_outline);
    expect(addButton.backgroundColor, AppColors.surface);
    expect(addButton.outlineColor, AppColors.surface);
    expect(
      tester.getRect(addButtonFinder).left,
      greaterThan(tester.getRect(find.text('Presets')).right),
    );
    expect(find.byType(FocusPreset), findsNWidgets(5));

    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();
    expect(find.text('Work minutes'), findsOneWidget);
    expect(find.text('Rest minutes'), findsOneWidget);
    expect(find.text('Estimated duration'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(focusTimer.customPresets, [existingPreset]);

    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    const preset = PomodoroPreset(workMinutes: 25, breakMinutes: 5);
    expect(focusTimer.customPresets, [preset, existingPreset]);
    expect(await FocusPresetPreferences.load(), [preset, existingPreset]);
    expect(
      tester.getRect(find.text('25 minutes').first).left,
      lessThan(tester.getRect(find.text('20 minutes')).left),
    );

    final customCardLabel = find.text('25 minutes').first;
    await tester.ensureVisible(customCardLabel);
    await tester.tap(customCardLabel);
    await tester.pumpAndSettle();
    expect(focusTimer.workMinutes, 25);
    expect(focusTimer.breakMinutes, 5);

    await tester.ensureVisible(addButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(addButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('That preset already exists.'), findsOneWidget);
    expect(focusTimer.customPresets, [preset, existingPreset]);
  });
}
