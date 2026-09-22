/// A focus/rest duration pair, shown as a chip on the Dashboard's
/// "Focus" row and selectable on the Timer screen.
class PomodoroPreset {
  final String id;
  final Duration focusDuration;
  final Duration restDuration;

  const PomodoroPreset({
    required this.id,
    required this.focusDuration,
    required this.restDuration,
  });
}

const List<PomodoroPreset> defaultPomodoroPresets = [
  PomodoroPreset(
    id: '30',
    focusDuration: Duration(minutes: 30),
    restDuration: Duration(minutes: 5),
  ),
  PomodoroPreset(
    id: '45',
    focusDuration: Duration(minutes: 45),
    restDuration: Duration(minutes: 10),
  ),
  PomodoroPreset(
    id: '60',
    focusDuration: Duration(minutes: 60),
    restDuration: Duration(minutes: 15),
  ),
];
