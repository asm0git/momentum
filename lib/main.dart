import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'screens/insights_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/add_calendars_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/todo_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/focus_preset_preferences.dart';
import 'services/onboarding_preferences.dart';
import 'state/planner_state.dart';
import 'state/focus_timer_state.dart';
import 'widgets/planner_load_gate.dart';
import 'widgets/responsive_app_viewport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final completed = await OnboardingPreferences.isComplete();
  final showDebugDemoData =
      kIsWeb &&
      kDebugMode &&
      await OnboardingPreferences.consumeDebugDemoDataPreview();
  final customFocusPresets = await FocusPresetPreferences.load();
  final initialRoute = resolveStartupRoute(
    setupComplete: completed,
    location: Uri.base,
  );
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                PlannerState(includeDebugDemoData: showDebugDemoData)
                  ..initialize(),
          ),
          ChangeNotifierProxyProvider<PlannerState, FocusTimerState>(
            create: (_) => FocusTimerState(customPresets: customFocusPresets),
            update: (_, planner, timer) =>
                timer!..attachFocusHistorySource(planner),
          ),
        ],
        child: MyApp(initialRoute: initialRoute, firstRun: !completed),
      ),
    ),
  );
}

// App shell that provides theme, routing, and the initial screen.
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.initialRoute, required this.firstRun});

  final String initialRoute;
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momentum',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      builder: (context, child) =>
          ResponsiveAppViewport(child: PlannerLoadGate(child: child!)),
      initialRoute: initialRoute,
      onGenerateRoute: _buildRoute,
    );
  }

  Route<void>? _buildRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/welcome':
        return _screenRoute(const WelcomeScreen(), settings);
      case '/dashboard':
        return _screenRoute(
          const DashboardScreen(key: ValueKey('dashboard-screen')),
          settings,
        );
      case '/calendar':
        return _screenRoute(
          const CalendarScreen(key: ValueKey('calendar-screen')),
          settings,
        );
      case '/todo':
        return _screenRoute(
          TodoScreen(
            key: const ValueKey('todo-screen'),
            initialCategoryId: settings.arguments is int
                ? settings.arguments! as int
                : null,
          ),
          settings,
        );
      case '/timer':
        return _screenRoute(
          const TimerScreen(key: ValueKey('timer-screen')),
          settings,
        );
      case '/ai':
      case '/insights':
        return _screenRoute(
          const InsightsScreen(key: ValueKey('insights-screen')),
          settings,
        );
      case '/calendars':
        return _screenRoute(
          AddCalendarsScreen(
            onboarding: settings.arguments is bool
                ? settings.arguments! as bool
                : firstRun,
          ),
          settings,
        );
    }

    return null;
  }

  MaterialPageRoute<void> _screenRoute(Widget screen, RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => screen,
    );
  }
}
