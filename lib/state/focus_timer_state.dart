// Public constructor labels keep the implementation fields private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/pomodoro_preset.dart';
import '../data/recurrence.dart';
import '../models/focus_models.dart';
import '../services/focus_preset_preferences.dart';
import 'focus_history_source.dart';

enum FocusPhase { work, rest }

enum CustomPresetSaveResult { saved, duplicate, invalid, notPersisted }

/// App-wide Pomodoro state and local-day focus accounting.
class FocusTimerState extends ChangeNotifier {
  FocusTimerState({
    int workMinutes = 25,
    int breakMinutes = 5,
    DateTime Function()? clock,
    bool startTicker = true,
    List<PomodoroPreset> customPresets = const [],
  }) : _workMinutes = workMinutes,
       _breakMinutes = breakMinutes,
       _clock = clock ?? DateTime.now,
       _startTicker = startTicker,
       _remainingSeconds = workMinutes * 60,
       _focusDate = dateOnly((clock ?? DateTime.now)()),
       _customPresets = List.of(customPresets);

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
  FocusHistorySource? _focusHistorySource;
  Timer? _ticker;
  bool _isTicking = false;
  bool _hasPendingFocusHistoryWriteFailure = false;
  Future<void>? _flushInProgress;
  int _lastFocusHistoryRevision = 0;
  final Map<DateTime, int> _pendingSeconds = {};
  final Map<DateTime, Map<int, _PendingCategoryFocus>> _pendingCategorySeconds =
      {};
  final List<PomodoroPreset> _customPresets;

  int get workMinutes => _workMinutes;
  int get breakMinutes => _breakMinutes;
  List<PomodoroPreset> get customPresets => List.unmodifiable(_customPresets);
  int get remainingSeconds => _remainingSeconds;
  FocusPhase get phase => _phase;
  bool get isRunning => _isRunning;
  FocusTaskSelection? get selectedTask => _selectedTask;
  bool get hasPendingFocusHistoryWriteFailure =>
      _hasPendingFocusHistoryWriteFailure;
  int get totalFocusSecondsToday =>
      _persistedToday + (_pendingSeconds[_focusDate] ?? 0);
  int get phaseDurationSeconds =>
      (_phase == FocusPhase.work ? _workMinutes : _breakMinutes) * 60;

  double get progress => phaseDurationSeconds <= 0
      ? 1
      : (_remainingSeconds / phaseDurationSeconds).clamp(0.0, 1.0);

  void attachFocusHistorySource(FocusHistorySource source) {
    if (identical(_focusHistorySource, source)) return;
    _focusHistorySource?.removeListener(_onFocusHistoryChanged);
    _focusHistorySource = source;
    _lastFocusHistoryRevision = source.focusHistoryRevision;
    source.addListener(_onFocusHistoryChanged);
    unawaited(_reloadToday(dateOnly(_clock())));
  }

  void _onFocusHistoryChanged() {
    final source = _focusHistorySource;
    if (source == null ||
        source.focusHistoryRevision == _lastFocusHistoryRevision) {
      return;
    }
    _lastFocusHistoryRevision = source.focusHistoryRevision;
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

  Future<CustomPresetSaveResult> addCustomPreset(PomodoroPreset preset) async {
    if (preset.workMinutes < 1 ||
        preset.breakMinutes < 1 ||
        preset.workMinutes > 1435 ||
        preset.breakMinutes > 1435) {
      return CustomPresetSaveResult.invalid;
    }
    if (_customPresets.contains(preset)) {
      return CustomPresetSaveResult.duplicate;
    }

    _customPresets.insert(0, preset);
    notifyListeners();
    try {
      await FocusPresetPreferences.save(_customPresets);
      return CustomPresetSaveResult.saved;
    } catch (error) {
      debugPrint('Could not persist custom focus preset: $error');
      return CustomPresetSaveResult.notPersisted;
    }
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

  Future<void> retryPendingFocusHistoryWrite() => _flushPending();

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
        final eventBoundary = _focusHistorySource?.nextEventFocusBoundaryAfter(
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
        _recordWorkChunk(cursor, chunk);
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

  void _recordWorkChunk(DateTime cursor, int seconds) {
    if (seconds <= 0 ||
        _focusHistorySource?.eventFocusSelectionAt(cursor) != null) {
      return;
    }

    final day = dateOnly(cursor);
    _pendingSeconds.update(
      day,
      (total) => total + seconds,
      ifAbsent: () => seconds,
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
        seconds: seconds,
      );
    } else {
      pending
        ..selection = activeTask
        ..seconds += seconds;
    }
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
    final source = _focusHistorySource;
    if (source == null) return;
    try {
      final total = await source.getFocusSecondsForDate(day);
      if (loadGeneration == _dailyTotalLoadGeneration &&
          _sameDay(day, _focusDate)) {
        _persistedToday = total;
        notifyListeners();
      }
    } catch (error) {
      // Keep the in-memory session usable if a storage read fails.
      debugPrint('Could not reload persisted focus totals: $error');
    }
  }

  Future<void> _flushPending() async {
    final activeFlush = _flushInProgress;
    if (activeFlush != null) return activeFlush;
    final source = _focusHistorySource;
    if (source == null || _pendingCategorySeconds.isEmpty) return;

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
    var writeFailed = false;
    final flush = () async {
      try {
        for (final dayEntry in snapshot.entries) {
          for (final categoryEntry in dayEntry.value.entries) {
            final amount = categoryEntry.value.seconds;
            await source.addFocusSeconds(
              dayEntry.key,
              amount,
              categoryEntry.value.selection,
            );
            wroteSeconds = true;
            _reconcilePendingCategoryEntry(
              dayEntry.key,
              categoryEntry.key,
              amount,
            );
          }
        }
      } catch (error) {
        // Keep uncommitted seconds in memory so the next flush can retry.
        writeFailed = true;
        if (!_hasPendingFocusHistoryWriteFailure) {
          _hasPendingFocusHistoryWriteFailure = true;
          if (hasListeners) notifyListeners();
        }
        debugPrint(
          'Could not save pending focus time; it will be retried: $error',
        );
      }
      if (wroteSeconds) {
        await _reloadToday(_focusDate);
      }
      if (!writeFailed && _hasPendingFocusHistoryWriteFailure) {
        _hasPendingFocusHistoryWriteFailure = false;
        if (hasListeners) notifyListeners();
      }
    }();
    _flushInProgress = flush;
    try {
      await flush;
    } finally {
      _flushInProgress = null;
    }
  }

  void _reconcilePendingCategoryEntry(
    DateTime day,
    int categoryId,
    int amount,
  ) {
    final stillPending = _pendingSeconds[day] ?? 0;
    final dailyRemaining = stillPending - amount;
    if (dailyRemaining <= 0) {
      _pendingSeconds.remove(day);
    } else {
      _pendingSeconds[day] = dailyRemaining;
    }

    final categories = _pendingCategorySeconds[day];
    final current = categories?[categoryId];
    if (categories == null || current == null) return;

    current.seconds -= amount;
    if (current.seconds <= 0) categories.remove(categoryId);
    if (categories.isEmpty) _pendingCategorySeconds.remove(day);
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  @override
  void dispose() {
    _ticker?.cancel();
    _focusHistorySource?.removeListener(_onFocusHistoryChanged);
    unawaited(_flushPending());
    super.dispose();
  }
}

class _PendingCategoryFocus {
  _PendingCategoryFocus({required this.selection, required this.seconds});

  FocusTaskSelection selection;
  int seconds;
}
