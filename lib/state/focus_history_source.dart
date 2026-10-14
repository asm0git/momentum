import 'package:flutter/foundation.dart';

import '../data_models.dart';

/// The focus history operations needed by the Pomodoro state.
abstract interface class FocusHistorySource {
  int get focusHistoryRevision;

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);

  Future<void> addFocusSeconds(
    DateTime date,
    int seconds,
    FocusTaskSelection selection,
  );

  Future<int> getFocusSecondsForDate(DateTime date);

  FocusTaskSelection? eventFocusSelectionAt(DateTime instant);

  DateTime? nextEventFocusBoundaryAfter(DateTime instant, DateTime through);
}
