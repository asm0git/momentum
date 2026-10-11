import 'package:shared_preferences/shared_preferences.dart';

import '../data_models.dart';

class OnboardingPreferences {
  static const _completedKey = 'first_run_calendar_setup_completed';
  static const _debugDemoShownKey = 'momentum_debug_demo_data_shown';

  static Future<bool> isComplete() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completedKey) ?? false;
  }

  static Future<void> markComplete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
  }

  /// Enables the temporary debug sample once, then leaves it out on the next
  /// app restart. The sample records themselves are never stored here.
  static Future<bool> consumeDebugDemoDataPreview() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_debugDemoShownKey) ?? false) return false;
    await preferences.setBool(_debugDemoShownKey, true);
    return true;
  }
}

String resolveStartupRoute({
  required bool setupComplete,
  required Uri location,
}) {
  final provider = location.queryParameters['calendar_provider'];
  final isProviderCallback = CalendarProvider.values.any(
    (candidate) => candidate.key == provider,
  );
  if (isProviderCallback) return '/calendars';
  return setupComplete ? '/dashboard' : '/welcome';
}
