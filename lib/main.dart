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

import 'app_theme.dart';
import 'navigation_destinations.dart';
import 'screens/ai_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/todo_screen.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momentum',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
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
          const TodoScreen(key: ValueKey('todo-screen')),
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

  MaterialPageRoute<void> _screenRoute(
    Widget screen,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => screen,
    );
  }
}
