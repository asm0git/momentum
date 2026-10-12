import 'package:flutter_test/flutter_test.dart';
import 'package:momentum/data/pomodoro_preset.dart';
import 'package:momentum/services/focus_preset_preferences.dart';
import 'package:momentum/state/focus_timer_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('custom presets round-trip through local preferences', () async {
    const presets = [
      PomodoroPreset(workMinutes: 25, breakMinutes: 5),
      PomodoroPreset(workMinutes: 45, breakMinutes: 15),
    ];

    await FocusPresetPreferences.save(presets);

    expect(await FocusPresetPreferences.load(), presets);
  });

  test('invalid stored data falls back to no custom presets', () async {
    SharedPreferences.setMockInitialValues({
      'focus_timer_custom_presets': '{invalid json',
    });

    expect(await FocusPresetPreferences.load(), isEmpty);
  });

  test('timer state adds and rejects duplicate custom presets', () async {
    final timer = FocusTimerState(startTicker: false);
    const preset = PomodoroPreset(workMinutes: 35, breakMinutes: 10);
    addTearDown(timer.dispose);

    expect(await timer.addCustomPreset(preset), CustomPresetSaveResult.saved);
    expect(timer.customPresets, [preset]);
    expect(
      await timer.addCustomPreset(preset),
      CustomPresetSaveResult.duplicate,
    );
    expect(await FocusPresetPreferences.load(), [preset]);

    final restored = FocusTimerState(
      startTicker: false,
      customPresets: await FocusPresetPreferences.load(),
    );
    addTearDown(restored.dispose);
    expect(restored.customPresets, [preset]);
  });

  test('timer state rejects durations outside the picker range', () async {
    final timer = FocusTimerState(startTicker: false);
    addTearDown(timer.dispose);

    expect(
      await timer.addCustomPreset(
        const PomodoroPreset(workMinutes: 0, breakMinutes: 5),
      ),
      CustomPresetSaveResult.invalid,
    );
    expect(timer.customPresets, isEmpty);
  });
}
