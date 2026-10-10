import 'package:shared_preferences/shared_preferences.dart';

import '../calendar_view_mode.dart';

class CalendarViewPreferences {
  static const _modeKey = 'calendar_view_mode';

  static Future<CalendarViewMode> load() async {
    final preferences = await SharedPreferences.getInstance();
    return CalendarViewMode.fromPreferenceValue(
      preferences.getString(_modeKey),
    );
  }

  static Future<void> save(CalendarViewMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modeKey, mode.name);
  }
}
