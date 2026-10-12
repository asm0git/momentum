import 'package:flutter/foundation.dart';

@immutable
class PomodoroPreset {
  const PomodoroPreset({required this.workMinutes, required this.breakMinutes});

  final int workMinutes;
  final int breakMinutes;

  Map<String, int> toJson() => {
    'workMinutes': workMinutes,
    'breakMinutes': breakMinutes,
  };

  @override
  bool operator ==(Object other) =>
      other is PomodoroPreset &&
      workMinutes == other.workMinutes &&
      breakMinutes == other.breakMinutes;

  @override
  int get hashCode => Object.hash(workMinutes, breakMinutes);
}
