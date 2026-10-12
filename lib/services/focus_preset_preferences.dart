import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/pomodoro_preset.dart';

class FocusPresetPreferences {
  static const _presetsKey = 'focus_timer_custom_presets';
  static const _maximumPresetMinutes = 23 * 60 + 55;

  static Future<List<PomodoroPreset>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedValue = preferences.getString(_presetsKey);
      if (storedValue == null) return const [];

      final decoded = jsonDecode(storedValue);
      if (decoded is! List) return const [];

      final presets = <PomodoroPreset>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final workMinutes = value['workMinutes'];
        final breakMinutes = value['breakMinutes'];
        if (workMinutes is! int || breakMinutes is! int) continue;
        if (workMinutes < 1 ||
            breakMinutes < 1 ||
            workMinutes > _maximumPresetMinutes ||
            breakMinutes > _maximumPresetMinutes) {
          continue;
        }
        final preset = PomodoroPreset(
          workMinutes: workMinutes,
          breakMinutes: breakMinutes,
        );
        if (!presets.contains(preset)) presets.add(preset);
      }
      return List.unmodifiable(presets);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<PomodoroPreset> presets) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _presetsKey,
      jsonEncode(presets.map((preset) => preset.toJson()).toList()),
    );
  }
}
