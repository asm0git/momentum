import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/recurrence.dart';
import '../data_models.dart';
import 'planner_state.dart';

enum FocusPhase { work, rest }

/// App-wide Pomodoro state and local-day focus accounting.
class FocusTimerState extends ChangeNotifier {
  FocusTimerState({
    int workMinutes = 25,
    int breakMinutes = 5,
    DateTime Function()? clock,
    bool startTicker = true,
  }) : this._(workMinutes, breakMinutes, clock ?? DateTime.now, startTicker);

  FocusTimerState._(
    this._workMinutes,
    this._breakMinutes,
    this._clock,
    this._startTicker,
  ) : _remainingSeconds = _workMinutes * 60,
      _focusDate = dateOnly(_clock());

  int _workMinutes;
  int _breakMinutes;
  final DateTime Function() _clock;
  final bool _startTicker;
  int _remainingSeconds;
  FocusPhase _phase = FocusPhase.work;
  bool _isRunning = false;
  FocusTaskSelection? _selectedTask;
  FocusTaskSelection? _activeTask;
  int _persistedToday = 0;
  int _dailyTotalLoadGeneration = 0;
  int _flushCounter = 0;
  DateTime _focusDate;
  DateTime? _lastTick;
  PlannerState? _planner;
  Timer? _ticker;
  bool _isTicking = false;
  Future<void>? _flushInProgress;
  int _lastPlannerFocusHistoryRevision = 0;
  final Map<DateTime, int> _pendingSeconds = {};
  final Map<DateTime, Map<int, _PendingCategoryFocus>> _pendingCategorySeconds =
      {};

  int get workMinutes => _workMinutes;
  int get breakMinutes => _breakMinutes;
  int get remainingSeconds => _remainingSeconds;
  FocusPhase get phase => _phase;
  bool get isRunning => _isRunning;
  FocusTaskSelection? get selectedTask => _selectedTask;
  int get totalFocusSecondsToday =>
      _persistedToday + (_pendingSeconds[_focusDate] ?? 0);
  int get phaseDurationSeconds =>
      (_phase == FocusPhase.work ? _workMinutes : _breakMinutes) * 60;

  double get progress => phaseDurationSeconds <= 0
      ? 1
      : (_remainingSeconds / phaseDurationSeconds).clamp(0.0, 1.0);

  void attachPlannerState(PlannerState planner) {
    if (identical(_planner, planner)) return;
    _planner?.removeListener(_onPlannerChanged);
    _planner = planner;
    _lastPlannerFocusHistoryRevision = planner.focusHistoryRevision;
    planner.addListener(_onPlannerChanged);
    unawaited(_reloadToday(dateOnly(_clock())));
  }

  void _onPlannerChanged() {
    final planner = _planner;
    if (planner == null ||
        planner.focusHistoryRevision == _lastPlannerFocusHistoryRevision) {
      return;
    }
    _lastPlannerFocusHistoryRevision = planner.focusHistoryRevision;
    unawaited(_reloadToday(dateOnly(_clock())));
  }

  bool selectTask(FocusTaskSelection? selection) {
    if (_isRunning) return false;
    _selectedTask = selection;
    notifyListeners();
    return true;
  }

  void selectPreset({required int workMinutes, required int breakMinutes}) {
    final now = _clock();
    if (_isRunning) _advanceTime(now);
    _workMinutes = workMinutes.clamp(1, 1440).toInt();
    _breakMinutes = breakMinutes.clamp(1, 1440).toInt();
    _phase = FocusPhase.work;
    _remainingSeconds = _workMinutes * 60;
    if (_isRunning) _lastTick = now;
    unawaited(_ensureToday(now));
    unawaited(_flushPending());
    notifyListeners();
  }

  bool toggleRunning() {
    if (_isRunning) {
      final now = _clock();
      _advanceTime(now);
      _isRunning = false;
      _activeTask = null;
      _lastTick = null;
      _ticker?.cancel();
      _ticker = null;
      unawaited(_ensureToday(now));
      unawaited(_flushPending());
    } else {
      if (_remainingSeconds <= 0) {
        _phase = FocusPhase.work;
        _remainingSeconds = _workMinutes * 60;
      }
      _isRunning = true;
      _activeTask = _selectedTask ?? FocusTaskSelection.unassigned;
      _lastTick = _clock();
      unawaited(_ensureToday(_lastTick!));
      if (_startTicker) {
        _ticker ??= Timer.periodic(
          const Duration(seconds: 1),
          (_) => unawaited(_tick()),
        );
      }
    }
    notifyListeners();
    return true;
  }

  Future<void> _tick() async {
    if (!_isRunning || _isTicking) return;
    _isTicking = true;
    try {
      final now = _clock();
      _advanceTime(now);
      await _ensureToday(now);
      if (_flushCounter >= 15) {
        _flushCounter = 0;
        await _flushPending();
      }
      notifyListeners();
    } finally {
      _isTicking = false;
    }
  }

  @visibleForTesting
  Future<void> tickForTesting() => _tick();

  @visibleForTesting
  Future<void> flushPendingForTesting() => _flushPending();

  void _advanceTime(DateTime now) {
    final lastTick = _lastTick;
    if (lastTick == null || !now.isAfter(lastTick)) return;

    var wholeSeconds = now.difference(lastTick).inSeconds;
    var cursor = lastTick;
    while (wholeSeconds > 0) {
      if (_remainingSeconds <= 0) _advancePhase();
      var chunk = wholeSeconds < _remainingSeconds
          ? wholeSeconds
          : _remainingSeconds;

      if (_phase == FocusPhase.work) {
        final nextMidnight = DateTime(
          cursor.year,
          cursor.month,
          cursor.day + 1,
        );
        final secondsUntilMidnight = nextMidnight.difference(cursor).inSeconds;
        if (secondsUntilMidnight > 0 && secondsUntilMidnight < chunk) {
          chunk = secondsUntilMidnight;
        }
        final chunkEnd = cursor.add(Duration(seconds: chunk));
        final eventBoundary = _planner?.nextEventFocusBoundaryAfter(
          cursor,
          chunkEnd,
        );
        if (eventBoundary != null) {
          final secondsUntilEventBoundary = eventBoundary
              .difference(cursor)
              .inSeconds;
          if (secondsUntilEventBoundary > 0 &&
              secondsUntilEventBoundary < chunk) {
            chunk = secondsUntilEventBoundary;
          }
        }
        final eventAlreadyCountsThisTime =
            _planner?.eventFocusSelectionAt(cursor) != null;
        if (chunk > 0 && !eventAlreadyCountsThisTime) {
          final day = dateOnly(cursor);
          _pendingSeconds.update(
            day,
            (seconds) => seconds + chunk,
            ifAbsent: () => chunk,
          );
          final activeTask = _activeTask ?? FocusTaskSelection.unassigned;
          final categoryForDay = _pendingCategorySeconds.putIfAbsent(
            day,
            () => <int, _PendingCategoryFocus>{},
          );
          final pending = categoryForDay[activeTask.categoryId];
          if (pending == null) {
            categoryForDay[activeTask.categoryId] = _PendingCategoryFocus(
              selection: activeTask,
              seconds: chunk,
            );
          } else {
            pending.selection = activeTask;
            pending.seconds += chunk;
          }
        }
      }

      cursor = cursor.add(Duration(seconds: chunk));
      wholeSeconds -= chunk;
      _remainingSeconds -= chunk;
      _flushCounter += _phase == FocusPhase.work ? chunk : 0;
      if (_remainingSeconds == 0) {
        _advancePhase();
        unawaited(_flushPending());
      }
    }
    _lastTick = cursor;
  }

  void _advancePhase() {
    _phase = _phase == FocusPhase.work ? FocusPhase.rest : FocusPhase.work;
    _remainingSeconds = phaseDurationSeconds;
  }

  Future<void> _ensureToday(DateTime now) async {
    final today = dateOnly(now);
    if (_sameDay(today, _focusDate)) return;
    await _reloadToday(today);
  }

  Future<void> _reloadToday(DateTime day) async {
    _focusDate = day;
    final loadGeneration = ++_dailyTotalLoadGeneration;
    final planner = _planner;
    if (planner == null) return;
    try {
      final total = await planner.getFocusSecondsForDate(day);
      if (loadGeneration == _dailyTotalLoadGeneration &&
          _sameDay(day, _focusDate)) {
        _persistedToday = total;
        notifyListeners();
      }
    } catch (_) {
      // Keep the in-memory session usable if a storage read fails.
    }
  }

  Future<void> _flushPending() async {
    final activeFlush = _flushInProgress;
    if (activeFlush != null) return activeFlush;
    final planner = _planner;
    if (planner == null || _pendingCategorySeconds.isEmpty) return;

    final snapshot = <DateTime, Map<int, _PendingCategoryFocus>>{
      for (final dayEntry in _pendingCategorySeconds.entries)
        dayEntry.key: {
          for (final categoryEntry in dayEntry.value.entries)
            categoryEntry.key: _PendingCategoryFocus(
              selection: categoryEntry.value.selection,
              seconds: categoryEntry.value.seconds,
            ),
        },
    };
    var wroteSeconds = false;
    final flush = () async {
      try {
        for (final dayEntry in snapshot.entries) {
          for (final categoryEntry in dayEntry.value.entries) {
            final amount = categoryEntry.value.seconds;
            await planner.addFocusSeconds(
              dayEntry.key,
              amount,
              categoryEntry.value.selection,
            );
            wroteSeconds = true;
            final stillPending = _pendingSeconds[dayEntry.key] ?? 0;
            final dailyRemaining = stillPending - amount;
            if (dailyRemaining <= 0) {
              _pendingSeconds.remove(dayEntry.key);
            } else {
              _pendingSeconds[dayEntry.key] = dailyRemaining;
            }
            final categories = _pendingCategorySeconds[dayEntry.key];
            final current = categories?[categoryEntry.key];
            if (categories != null && current != null) {
              current.seconds -= amount;
              if (current.seconds <= 0) categories.remove(categoryEntry.key);
              if (categories.isEmpty) {
                _pendingCategorySeconds.remove(dayEntry.key);
              }
            }
          }
        }
      } catch (_) {
        // Keep uncommitted seconds in memory so the next flush can retry.
      }
      if (wroteSeconds) {
        await _reloadToday(_focusDate);
      }
    }();
    _flushInProgress = flush;
    try {
      await flush;
    } finally {
      _flushInProgress = null;
    }
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  @override
  void dispose() {
    _ticker?.cancel();
    _planner?.removeListener(_onPlannerChanged);
    unawaited(_flushPending());
    super.dispose();
  }
}

class _PendingCategoryFocus {
  _PendingCategoryFocus({required this.selection, required this.seconds});

  FocusTaskSelection selection;
  int seconds;
}
