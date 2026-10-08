// This is your app. It runs as it is: press run and you get the screen below.
//
// Nothing here is precious. Change the title, change the colors, delete the
// counter, add your own screens. It exists so that the repository is a working
// Flutter app from minute one instead of an empty folder.
//
// Everything in this file is Module 4 and 5 material: StatelessWidget,
// StatefulWidget, setState, Scaffold, AppBar, Column, Card, FilledButton.

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'navigation_destinations.dart';
import 'screens/ai_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/todo_screen.dart';
import 'state/planner_state.dart';
import 'state/focus_timer_state.dart';
import 'widgets/planner_load_gate.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PlannerState()..initialize()),
          ChangeNotifierProxyProvider<PlannerState, FocusTimerState>(
            create: (_) => FocusTimerState(),
            update: (_, planner, timer) => timer!..attachPlannerState(planner),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

// App shell that provides theme, routing, and the initial screen.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momentum',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      builder: (context, child) => PlannerLoadGate(child: child!),
      initialRoute: AppDestination.dashboard.route,
      onGenerateRoute: _buildRoute,
    );
  }

  Route<void>? _buildRoute(RouteSettings settings) {
    switch (settings.name) {
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
        return _screenRoute(
          const AiScreen(key: ValueKey('ai-screen')),
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
