import 'package:shared_preferences/shared_preferences.dart';

import '../data_models.dart';

class OnboardingPreferences {
  static const _completedKey = 'first_run_calendar_setup_completed';

  static Future<bool> isComplete() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completedKey) ?? false;
  }

  static Future<void> markComplete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
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
