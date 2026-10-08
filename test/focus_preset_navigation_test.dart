import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/app_theme.dart';
import 'package:momentum/screens/dashboard_screen.dart';
import 'package:momentum/screens/timer_screen.dart';
import 'package:momentum/state/focus_timer_state.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/clock.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('dashboard preset opens Timer and both screens apply presets', (
    tester,
  ) async {
    late FocusTimerState focusTimer;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PlannerState()),
          ChangeNotifierProvider(
            create: (_) => focusTimer = FocusTimerState(startTicker: false),
          ),
        ],
        child: MaterialApp(
          theme: appTheme,
          home: const DashboardScreen(),
          routes: {'/timer': (_) => const TimerScreen()},
        ),
      ),
    );

    await tester.ensureVisible(find.text('30 minutes').first);
    await tester.tap(find.text('30 minutes').first);
    await tester.pumpAndSettle();
    expect(find.byType(TimerScreen), findsOneWidget);
    expect(focusTimer.workMinutes, 30);
    expect(focusTimer.breakMinutes, 5);

    await tester.ensureVisible(find.text('45 minutes').first);
    await tester.tap(find.text('45 minutes').first);
    await tester.pumpAndSettle();
    expect(focusTimer.workMinutes, 45);
    expect(focusTimer.breakMinutes, 10);
    expect(focusTimer.phase, FocusPhase.work);
    expect(focusTimer.remainingSeconds, 45 * 60);

    focusTimer.toggleRunning();
    await tester.pump();
    expect(find.byType(ImageFiltered), findsNWidgets(3));
    expect(
      find.ancestor(
        of: find.byType(Clock),
        matching: find.byType(ImageFiltered),
      ),
      findsNothing,
    );
  });
}
