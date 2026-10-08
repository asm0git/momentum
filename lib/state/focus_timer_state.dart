import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/recurrence.dart';
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
  int _persistedToday = 0;
  int _dailyTotalLoadGeneration = 0;
  int _flushCounter = 0;
  DateTime _focusDate;
  DateTime? _lastTick;
  PlannerState? _planner;
  Timer? _ticker;
  bool _isTicking = false;
  Future<void>? _flushInProgress;
  final Map<DateTime, int> _pendingSeconds = {};

  int get workMinutes => _workMinutes;
  int get breakMinutes => _breakMinutes;
  int get remainingSeconds => _remainingSeconds;
  FocusPhase get phase => _phase;
  bool get isRunning => _isRunning;
  int get totalFocusSecondsToday =>
      _persistedToday + (_pendingSeconds[_focusDate] ?? 0);
  int get phaseDurationSeconds =>
      (_phase == FocusPhase.work ? _workMinutes : _breakMinutes) * 60;

  double get progress => phaseDurationSeconds <= 0
      ? 1
      : (_remainingSeconds / phaseDurationSeconds).clamp(0.0, 1.0);

  void attachPlannerState(PlannerState planner) {
    if (identical(_planner, planner)) return;
    _planner = planner;
    unawaited(_reloadToday(dateOnly(_clock())));
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

  void toggleRunning() {
    if (_isRunning) {
      final now = _clock();
      _advanceTime(now);
      _isRunning = false;
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
        if (chunk > 0) {
          final day = dateOnly(cursor);
          _pendingSeconds.update(
            day,
            (seconds) => seconds + chunk,
            ifAbsent: () => chunk,
          );
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
    if (planner == null || _pendingSeconds.isEmpty) return;

    final snapshot = Map<DateTime, int>.of(_pendingSeconds);
    var wroteSeconds = false;
    final flush = () async {
      try {
        for (final entry in snapshot.entries) {
          await planner.addFocusSeconds(entry.key, entry.value);
          wroteSeconds = true;
          final stillPending = _pendingSeconds[entry.key] ?? 0;
          final remaining = stillPending - entry.value;
          if (remaining <= 0) {
            _pendingSeconds.remove(entry.key);
          } else {
            _pendingSeconds[entry.key] = remaining;
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
    unawaited(_flushPending());
    super.dispose();
  }
}
