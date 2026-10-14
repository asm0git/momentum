import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/main.dart';
import 'package:momentum/state/focus_timer_state.dart';
import 'package:momentum/state/planner_state.dart';
import 'package:momentum/widgets/planner_load_gate.dart';
import 'package:momentum/widgets/navigation/responsive_app_viewport.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('app opens its configured dashboard route', (tester) async {
    final planner = _GatePlannerState();
    final focusTimer = FocusTimerState(startTicker: false);
    addTearDown(planner.dispose);
    addTearDown(focusTimer.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlannerState>.value(value: planner),
          ChangeNotifierProvider<FocusTimerState>.value(value: focusTimer),
        ],
        child: const MyApp(initialRoute: '/dashboard', firstRun: false),
      ),
    );

    expect(find.byKey(const ValueKey('dashboard-screen')), findsOneWidget);
  });

  testWidgets('planner load gate shows loading and retries after failure', (
    tester,
  ) async {
    final planner = _GatePlannerState(isLoading: true);
    addTearDown(planner.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<PlannerState>.value(
        value: planner,
        child: const MaterialApp(
          home: PlannerLoadGate(child: Text('Planner ready')),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Planner ready'), findsNothing);

    planner.fail(StateError('internal database details'));
    await tester.pump();
    expect(find.text('Could not load your planner data.'), findsOneWidget);
    expect(find.textContaining('internal database details'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(planner.retryCount, 1);
    expect(find.text('Planner ready'), findsOneWidget);
  });

  testWidgets('responsive viewport fits a phone frame on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveAppViewport(
          child: ColoredBox(
            key: ValueKey('viewport-content'),
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('viewport-content'))),
      const Size(430, 900),
    );
  });

  testWidgets('responsive viewport uses the available size on phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveAppViewport(
          child: ColoredBox(
            key: ValueKey('viewport-content'),
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('viewport-content'))),
      const Size(390, 844),
    );
  });
}

class _GatePlannerState extends PlannerState {
  // Keep the injected public label while the test override remains private.
  // ignore: prefer_initializing_formals
  _GatePlannerState({bool isLoading = false}) : _isLoading = isLoading;

  bool _isLoading;
  Object? _error;
  int retryCount = 0;

  @override
  bool get isLoading => _isLoading;

  @override
  Object? get error => _error;

  @override
  Future<void> retry() async {
    retryCount++;
    _isLoading = true;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void fail(Object error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }
}
