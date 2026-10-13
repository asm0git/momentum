import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/debug_demo_data.dart';
import '../data/model_serialization.dart';
import '../data/planner_repository.dart';
import '../data/recurrence.dart';
import '../data_models.dart';
import '../services/calendar_backend_client.dart';
import 'calendar_sync_coordinator.dart';
import 'focus_history_source.dart';

/// A scheduled event's active window and the category used for focus history.
class ScheduledEventFocusInterval {
  const ScheduledEventFocusInterval(this.start, this.end, this.selection);

  final DateTime start;
  final DateTime end;
  final FocusTaskSelection selection;
}

/// Focus seconds grouped for one local day and category.
class AutomaticFocusBucket {
  const AutomaticFocusBucket({
    required this.date,
    required this.selection,
    required this.seconds,
  });

  final DateTime date;
  final FocusTaskSelection selection;
  final int seconds;
}

/// Splits event windows at their boundaries and local midnight, then groups
/// covered seconds by day and category. Overlaps prefer the earliest event.
List<AutomaticFocusBucket> aggregateAutomaticFocusBuckets({
  required Iterable<ScheduledEventFocusInterval> intervals,
  required DateTime from,
  required DateTime through,
}) {
  if (!through.isAfter(from)) return const [];

  final eventIntervals = intervals.toList()
    ..sort((first, second) {
      final byStart = first.start.compareTo(second.start);
      if (byStart != 0) return byStart;
      return first.selection.taskId.compareTo(second.selection.taskId);
    });
  final boundaries = <DateTime>{from, through};
  for (final interval in eventIntervals) {
    if (interval.start.isAfter(from) && interval.start.isBefore(through)) {
      boundaries.add(interval.start);
    }
    if (interval.end.isAfter(from) && interval.end.isBefore(through)) {
      boundaries.add(interval.end);
    }
  }

  var midnight = DateTime(from.year, from.month, from.day + 1);
  while (midnight.isBefore(through)) {
    boundaries.add(midnight);
    midnight = DateTime(midnight.year, midnight.month, midnight.day + 1);
  }

  final orderedBoundaries = boundaries.toList()..sort();
  final totals = <DateTime, Map<int, _MutableAutomaticFocusBucket>>{};
  for (var index = 0; index + 1 < orderedBoundaries.length; index++) {
    final start = orderedBoundaries[index];
    final end = orderedBoundaries[index + 1];
    if (!end.isAfter(start)) continue;

    ScheduledEventFocusInterval? active;
    for (final interval in eventIntervals) {
      if (!start.isBefore(interval.start) && !end.isAfter(interval.end)) {
        active = interval;
        break;
      }
    }
    if (active == null) continue;

    final seconds = end.difference(start).inSeconds;
    if (seconds <= 0) continue;
    final day = dateOnly(start);
    final byCategory = totals.putIfAbsent(
      day,
      () => <int, _MutableAutomaticFocusBucket>{},
    );
    final categoryId = active.selection.categoryId;
    final bucket = byCategory[categoryId];
    if (bucket == null) {
      byCategory[categoryId] = _MutableAutomaticFocusBucket(
        selection: active.selection,
        seconds: seconds,
      );
    } else {
      bucket.seconds += seconds;
    }
  }

  return [
    for (final dayEntry in totals.entries)
      for (final bucket in dayEntry.value.values)
        AutomaticFocusBucket(
          date: dayEntry.key,
          selection: bucket.selection,
          seconds: bucket.seconds,
        ),
  ];
}

class PlannerState extends ChangeNotifier implements FocusHistorySource {
  PlannerState({
    PlannerRepository? repository,
    ProviderCalendarBackend? calendarBackend,
    bool? autoSyncCalendarsOnStartup,
    @visibleForTesting DateTime Function()? clock,
    @visibleForTesting bool startAutomaticEventFocusTimer = true,
    this.includeDebugDemoData = false,
  }) : _repository = repository ?? PlannerRepository(),
       _calendarBackend = calendarBackend ?? CalendarBackendClient(),
       _autoSyncCalendarsOnStartup = autoSyncCalendarsOnStartup ?? kIsWeb,
       _clock = clock ?? DateTime.now,
       _automaticFocusTimerEnabled = startAutomaticEventFocusTimer {
    _calendarSync = CalendarSyncCoordinator(
      repository: _repository,
      calendarBackend: _calendarBackend,
      reloadSnapshot: _reloadSnapshot,
      accountForProvider: accountForProvider,
      isParentDisposed: () => _isDisposed,
    )..addListener(_onCalendarSyncChanged);
  }

  final PlannerRepository _repository;
  final ProviderCalendarBackend _calendarBackend;
  late final CalendarSyncCoordinator _calendarSync;
  final bool _autoSyncCalendarsOnStartup;
  final DateTime Function() _clock;
  final bool _automaticFocusTimerEnabled;
  final bool includeDebugDemoData;
  List<TaskCategory> _categories = [];
  List<PlannerItem> _items = [];
  Set<String> _taskOccurrenceCompletionKeys = {};
  Timer? _automaticEventFocusTimer;
  DateTime? _automaticEventFocusCursor;
  bool _isRecordingAutomaticEventFocus = false;
  bool _automaticEventFocusFailureLogged = false;
  List<LinkedAccount> _linkedAccounts = [];
  bool _isLoading = true;
  Object? _error;
  bool _isDisposed = false;
  int _focusHistoryRevision = 0;

  List<TaskCategory> get categories => List.unmodifiable(_categories);
  List<PlannerItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  Object? get error => _error;
  @override
  int get focusHistoryRevision => _focusHistoryRevision;
  LinkedAccount? accountForProvider(CalendarProvider provider) =>
      _linkedAccounts
          .where(
            (account) => account.platformName.toLowerCase() == provider.key,
          )
          .firstOrNull;

  CalendarProvider? calendarProviderForCategory(TaskCategory category) {
    final categoryId = category.id;
    if (categoryId != null) {
      for (final provider in CalendarProvider.values) {
        if (accountForProvider(provider)?.categoryId == categoryId) {
          return provider;
        }
      }
    }

    for (final provider in CalendarProvider.values) {
      if (category.iconName == provider.categoryIcon) return provider;

      final legacyDefaultIcon = switch (provider) {
        CalendarProvider.canvas => 'mi_school',
        CalendarProvider.googleCalendar ||
        CalendarProvider.outlook => 'mi_calendar_month',
      };
      if (category.iconName == legacyDefaultIcon &&
          category.items.any(
            (item) =>
                (item is Task &&
                    item.sourcePlatform?.toLowerCase() == provider.key) ||
                (item is Event &&
                    item.sourcePlatform?.toLowerCase() == provider.key),
          )) {
        return provider;
      }
    }
    return null;
  }

  String categoryDisplayIconName(TaskCategory category) {
    final provider = calendarProviderForCategory(category);
    if (provider == null) return category.iconName;

    final legacyDefaultIcon = switch (provider) {
      CalendarProvider.canvas => 'mi_school',
      CalendarProvider.googleCalendar ||
      CalendarProvider.outlook => 'mi_calendar_month',
    };
    if (category.iconName == legacyDefaultIcon ||
        category.iconName == provider.categoryIcon) {
      return provider.categoryIcon;
    }
    return category.iconName;
  }

  CalendarConnectionStatus? statusForProvider(CalendarProvider provider) =>
      _calendarSync.statusForProvider(provider);
  bool isProviderSyncing(CalendarProvider provider) =>
      _calendarSync.isProviderSyncing(provider);
  Object? errorForProvider(CalendarProvider provider) =>
      _calendarSync.errorForProvider(provider);

  Uri providerOAuthStartUri(CalendarProvider provider, {String? siteUrl}) =>
      _calendarSync.providerOAuthStartUri(provider, siteUrl: siteUrl);

  PlannerItem? get nextUpcomingItem {
    final now = DateTime.now();
    return _nextUpcomingFrom(_items, now);
  }

  FocusTaskSelection? get defaultFocusSelection {
    final activeEvent = eventFocusSelectionAt(DateTime.now());
    return activeEvent ?? focusSelectionForItem(nextUpcomingItem);
  }

  PlannerItem? nextUpcomingItemForCategory(int categoryId, DateTime now) =>
      _nextUpcomingFrom(
        _items.where((item) => item.categoryId == categoryId),
        now,
      );

  List<PlannerItem> itemsForDate(DateTime date) => _itemsForRange(date, date);

  List<PlannerItem> itemsForRange(DateTime firstDay, DateTime lastDay) =>
      _itemsForRange(firstDay, lastDay);

  /// Returns one visible row per category item. Recurring items are represented
  /// by their next date, with task completion scoped to that occurrence.
  List<PlannerItem> itemsForCategory(int categoryId) {
    final today = dateOnly(DateTime.now());
    final result = <PlannerItem>[];
    for (final series in _items.where(
      (item) => item.categoryId == categoryId,
    )) {
      if (!isRecurring(series)) {
        result.add(series);
        continue;
      }
      for (final occurrence in _incompleteOccurrences(series, from: today)) {
        result.add(occurrence);
        break;
      }
    }
    result.sort(_compareItems);
    return result;
  }

  /// The To-Do screen hides imported items after their scheduled time passes.
  /// The underlying planner snapshot and database remain unchanged.
  List<PlannerItem> todoItemsForCategory(int categoryId, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final result = <PlannerItem>[];
    for (final candidate in itemsForCategory(categoryId)) {
      if (!_isImported(candidate)) {
        result.add(candidate);
        continue;
      }

      final series = seriesFor(candidate);
      if (!isRecurring(series)) {
        if (!_hasEnded(candidate, currentTime)) result.add(candidate);
        continue;
      }

      for (final occurrence in _incompleteOccurrences(
        series,
        from: dateOnly(currentTime),
      )) {
        if (_hasEnded(occurrence, currentTime)) continue;
        result.add(occurrence);
        break;
      }
    }
    result.sort(_compareItems);
    return List.unmodifiable(result);
  }

  Iterable<PlannerItem> _incompleteOccurrences(
    PlannerItem series, {
    required DateTime from,
  }) sync* {
    for (final occurrenceDate in recurrenceDatesInRange(
      series,
      from: from,
      through: DateTime(9999, 12, 31),
    )) {
      final completed =
          series is Task &&
          series.id != null &&
          _taskOccurrenceCompletionKeys.contains(
            taskOccurrenceKey(series.id!, occurrenceDate),
          );
      if (completed) continue;
      yield occurrenceForDate(series, occurrenceDate, isCompleted: completed);
    }
  }

  /// Incomplete tasks and not-yet-ended events available to the Pomodoro
  /// selector. Each recurring series appears once at its next occurrence.
  List<FocusTaskSelection> get selectableFocusItems {
    final now = DateTime.now();
    final candidates = <(DateTime, FocusTaskSelection)>[];

    for (final category in _categories) {
      final categoryId = category.id;
      if (categoryId == null) continue;
      for (final task in todoItemsForCategory(categoryId).whereType<Task>()) {
        if (task.isChecked || task.id == null) continue;
        candidates.add((
          _scheduledDate(task),
          FocusTaskSelection(
            taskId: task.id!,
            taskTitle: task.title,
            categoryId: categoryId,
            categoryTitle: category.title,
            categoryIcon: categoryDisplayIconName(category),
          ),
        ));
      }
    }

    for (final series in _items.whereType<Event>()) {
      final occurrence = _nextSelectableEventOccurrence(series, now);
      if (occurrence == null) continue;
      final selection = focusSelectionForItem(occurrence);
      if (selection != null) {
        candidates.add((_scheduledDate(occurrence), selection));
      }
    }

    candidates.sort((first, second) {
      final byDate = first.$1.compareTo(second.$1);
      if (byDate != 0) return byDate;
      final byCategory = first.$2.categoryTitle.toLowerCase().compareTo(
        second.$2.categoryTitle.toLowerCase(),
      );
      return byCategory != 0
          ? byCategory
          : first.$2.taskTitle.toLowerCase().compareTo(
              second.$2.taskTitle.toLowerCase(),
            );
    });
    return List.unmodifiable(candidates.map((candidate) => candidate.$2));
  }

  /// Incomplete categorized tasks, with recurring series represented once.
  List<FocusTaskSelection> get selectableFocusTasks =>
      List.unmodifiable(selectableFocusItems.where((item) => !item.isEvent));

  FocusTaskSelection? focusSelectionForItem(PlannerItem? item) {
    if (item == null) return null;
    final category = _categories
        .where((candidate) => candidate.id == item.categoryId)
        .firstOrNull;
    if (item is Task && category == null) return null;
    if (item.id == null && item is Task) return null;
    return FocusTaskSelection(
      taskId: item.id ?? 0,
      taskTitle: item.title,
      categoryId: category?.id ?? -1,
      categoryTitle: category?.title ?? 'Unassigned',
      categoryIcon: category == null
          ? 'mi_timer'
          : categoryDisplayIconName(category),
      isEvent: item is Event,
    );
  }

  /// Resolves a generated calendar occurrence to the saved series record.
  PlannerItem seriesFor(PlannerItem occurrence) {
    final id = occurrence.id;
    if (id == null) return occurrence;
    return _items.firstWhere(
      (item) => item.runtimeType == occurrence.runtimeType && item.id == id,
      orElse: () => occurrence,
    );
  }

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _reloadSnapshot();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    _automaticEventFocusCursor ??= _clock();
    if (_automaticFocusTimerEnabled) {
      _automaticEventFocusTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(_recordAutomaticEventFocus()),
      );
    }
    if (_autoSyncCalendarsOnStartup) {
      _calendarSync.startBackgroundRefresh();
    }
  }

  Future<void> retry() => initialize();

  Future<void> _reloadSnapshot() async {
    final categories = await _repository.getCategoriesWithItems();
    final items = await _repository.getAllItems();
    final occurrenceCompletions = await _repository
        .getTaskOccurrenceCompletionKeys();
    final accounts = await _repository.getLinkedAccounts();
    if (includeDebugDemoData) {
      final demoCategory = DebugDemoData.googleCalendarCategory();
      categories.add(demoCategory);
      items.addAll(demoCategory.items);
    }
    _categories = categories;
    _items = items;
    _taskOccurrenceCompletionKeys = occurrenceCompletions;
    _linkedAccounts = accounts;
    _error = null;
  }

  Future<void> _afterWrite(Future<void> Function() write) async {
    await write();
    try {
      await _reloadSnapshot();
      notifyListeners();
    } catch (error) {
      _error = error;
      notifyListeners();
      rethrow;
    }
  }

  void _onCalendarSyncChanged() {
    if (!_isDisposed) notifyListeners();
  }

  Future<TaskCategory> addCategory(TaskCategory category) async {
    await _afterWrite(() async {
      await _repository.insertCategory(category);
    });
    return category;
  }

  Future<void> updateCategory(TaskCategory category) => _afterWrite(() async {
    await _repository.updateCategory(category);
  });

  Future<void> deleteCategory(
    int id, {
    required CategoryDeleteDisposition disposition,
    int? destinationCategoryId,
  }) => _afterWrite(() async {
    final deleted = await _repository.deleteCategory(
      id,
      disposition: disposition,
      destinationCategoryId: destinationCategoryId,
    );
    if (!deleted) throw StateError('The category no longer exists.');
  });

  Future<Task> saveTask(Task task) async {
    await _afterWrite(() async {
      if (task.id == null) {
        await _repository.insertTask(task);
      } else {
        final updated = await _repository.updateTask(task);
        if (!updated) {
          throw StateError('The task was not updated in local storage.');
        }
      }
    });
    final savedTask = _items
        .whereType<Task>()
        .where((saved) => saved.id == task.id)
        .firstOrNull;
    if (savedTask == null) {
      throw StateError('The saved task could not be reloaded.');
    }
    return savedTask;
  }

  Future<Event> saveEvent(Event event) async {
    await _afterWrite(() async {
      if (event.id == null) {
        await _repository.insertEvent(event);
      } else {
        await _repository.updateEvent(event);
      }
    });
    return event;
  }

  Future<void> setTaskCompleted(Task task, bool isCompleted) =>
      _afterWrite(() async {
        final occurrenceDate = task.occurrenceDate;
        if (isRecurring(task) && task.id != null && occurrenceDate != null) {
          await _repository.setTaskOccurrenceCompleted(
            task.id!,
            occurrenceDate,
            isCompleted,
          );
          return;
        }
        task.isChecked = isCompleted;
        await _repository.updateTask(task);
      });

  Future<void> deleteItem(PlannerItem item) => _afterWrite(() async {
    final id = item.id;
    if (id == null) return;
    if (item is Task) {
      await _repository.deleteTask(id);
    } else if (item is Event) {
      await _repository.deleteEvent(id);
    }
  });

  Future<PlannerItem?> getNextUpcomingItem(DateTime now) =>
      _repository.getNextUpcomingItem(now);

  Future<List<PlannerItem>> getItemsForDate(DateTime date) =>
      _repository.getItemsForDate(date);

  Future<List<Task>> getTasksForDate(DateTime date) =>
      _repository.getTasksForDate(date);

  @override
  Future<int> getFocusSecondsForDate(DateTime date) async {
    final stored = await _repository.getFocusSecondsForDate(date);
    if (!includeDebugDemoData) return stored;
    final demo = DebugDemoData.focusByDay(
      firstDay: date,
      lastDay: date,
    )[dateOnly(date)];
    return stored +
        (demo?.fold<int>(0, (sum, total) => sum + total.totalSeconds) ?? 0);
  }

  Future<Map<DateTime, int>> getFocusTotalsForRange(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final totals = await _repository.getFocusTotalsForRange(firstDay, lastDay);
    if (!includeDebugDemoData) return totals;
    final demo = DebugDemoData.focusByDay(firstDay: firstDay, lastDay: lastDay);
    for (final entry in demo.entries) {
      totals.update(
        entry.key,
        (seconds) =>
            seconds +
            entry.value.fold<int>(0, (sum, row) => sum + row.totalSeconds),
        ifAbsent: () =>
            entry.value.fold<int>(0, (sum, row) => sum + row.totalSeconds),
      );
    }
    return totals;
  }

  Future<List<FocusCategoryTotal>> getFocusCategoryTotalsForRange(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final stored = await _repository.getFocusCategoryTotalsForRange(
      firstDay,
      lastDay,
    );
    if (!includeDebugDemoData) return stored;
    final totals = <int, FocusCategoryTotal>{
      for (final total in stored) total.categoryId: total,
    };
    final demo = DebugDemoData.focusByDay(firstDay: firstDay, lastDay: lastDay);
    for (final rows in demo.values) {
      for (final row in rows) {
        final current = totals[row.categoryId];
        totals[row.categoryId] = FocusCategoryTotal(
          categoryId: row.categoryId,
          categoryTitle: row.categoryTitle,
          categoryIcon: row.categoryIcon,
          totalSeconds: row.totalSeconds + (current?.totalSeconds ?? 0),
        );
      }
    }
    final result = totals.values.toList()
      ..sort((first, second) {
        final byDuration = second.totalSeconds.compareTo(first.totalSeconds);
        return byDuration != 0
            ? byDuration
            : first.categoryTitle.toLowerCase().compareTo(
                second.categoryTitle.toLowerCase(),
              );
      });
    return result;
  }

  @override
  Future<void> addFocusSeconds(
    DateTime date,
    int seconds,
    FocusTaskSelection selection,
  ) async {
    await _repository.addFocusSeconds(date, seconds, selection);
    if (!_isDisposed) {
      _focusHistoryRevision++;
      notifyListeners();
    }
  }

  /// Returns the calendar event that owns this instant for automatic focus
  /// accounting. Pomodoro skips these seconds so simultaneous tracking does
  /// not double count the same elapsed time.
  @override
  FocusTaskSelection? eventFocusSelectionAt(DateTime instant) {
    final intervals = _eventFocusIntervals(
      instant.subtract(const Duration(seconds: 1)),
      instant.add(const Duration(seconds: 1)),
    );
    for (final interval in intervals) {
      if (!instant.isBefore(interval.start) && instant.isBefore(interval.end)) {
        return interval.selection;
      }
    }
    return null;
  }

  /// Returns the next event start or end inside an elapsed Pomodoro chunk.
  @override
  DateTime? nextEventFocusBoundaryAfter(DateTime instant, DateTime through) {
    DateTime? next;
    for (final interval in _eventFocusIntervals(instant, through)) {
      for (final boundary in [interval.start, interval.end]) {
        if (boundary.isAfter(instant) &&
            !boundary.isAfter(through) &&
            (next == null || boundary.isBefore(next))) {
          next = boundary;
        }
      }
    }
    return next;
  }

  Future<CalendarConnectionStatus> refreshProviderStatus(
    CalendarProvider provider,
  ) => _calendarSync.refreshProviderStatus(provider);

  Future<void> syncProvider(
    CalendarProvider provider, {
    bool replaceExistingImports = false,
    bool removeMissingTasks = false,
    bool removeMissingEvents = false,
  }) => _calendarSync.syncProvider(
    provider,
    replaceExistingImports: replaceExistingImports,
    removeMissingTasks: removeMissingTasks,
    removeMissingEvents: removeMissingEvents,
  );

  Future<void> connectCalendarIcsFeed(CalendarProvider provider, String url) =>
      _calendarSync.connectCalendarIcsFeed(provider, url);

  Future<void> disconnectProvider(CalendarProvider provider) =>
      _calendarSync.disconnectProvider(provider);

  Future<void> _recordAutomaticEventFocus() async {
    if (_isDisposed || _isRecordingAutomaticEventFocus) return;
    final from = _automaticEventFocusCursor;
    final through = _clock();
    if (from == null || !through.isAfter(from)) {
      _automaticEventFocusCursor = through;
      return;
    }

    _isRecordingAutomaticEventFocus = true;
    try {
      final intervals = _eventFocusIntervals(from, through);
      final buckets = aggregateAutomaticFocusBuckets(
        intervals: intervals,
        from: from,
        through: through,
      );
      if (buckets.isNotEmpty) {
        await _repository.addFocusSecondsBatch(
          buckets.map(
            (bucket) => (
              date: bucket.date,
              seconds: bucket.seconds,
              selection: bucket.selection,
            ),
          ),
        );
        _automaticEventFocusCursor = through;
        _automaticEventFocusFailureLogged = false;
        if (!_isDisposed) {
          _focusHistoryRevision++;
          notifyListeners();
        }
      } else {
        _automaticEventFocusCursor = through;
        _automaticEventFocusFailureLogged = false;
      }
    } catch (error) {
      // Keep the cursor unchanged so the next interval retries the full batch.
      if (!_automaticEventFocusFailureLogged) {
        debugPrint('Automatic focus recording failed; retrying: $error');
        _automaticEventFocusFailureLogged = true;
      }
    } finally {
      _isRecordingAutomaticEventFocus = false;
    }
  }

  @visibleForTesting
  Future<void> recordAutomaticEventFocusForTesting() =>
      _recordAutomaticEventFocus();

  List<ScheduledEventFocusInterval> _eventFocusIntervals(
    DateTime from,
    DateTime through,
  ) {
    if (!through.isAfter(from)) return const [];
    final events = _items.whereType<Event>().toList(growable: false);
    if (events.isEmpty) return const [];
    final longestDurationDays = events
        .map(
          (event) =>
              dateOnly(event.endDate).difference(dateOnly(event.date)).inDays,
        )
        .fold<int>(0, (longest, days) => days > longest ? days : longest)
        .clamp(0, 3660)
        .toInt();
    final firstDay = dateOnly(
      from,
    ).subtract(Duration(days: longestDurationDays + 1));
    final lastDay = dateOnly(through);
    final result = <ScheduledEventFocusInterval>[];

    for (final series in events) {
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: firstDay,
        through: lastDay,
      )) {
        final occurrence = occurrenceForDate(series, occurrenceDate) as Event;
        final start = occurrence.allDay
            ? dateOnly(occurrence.date)
            : eventStartDateTime(occurrence);
        var end = occurrence.allDay
            ? dateOnly(occurrence.endDate).add(const Duration(days: 1))
            : eventEndDateTime(occurrence);
        if (!end.isAfter(start)) end = start.add(const Duration(days: 1));
        if (!end.isAfter(from) || !start.isBefore(through)) continue;
        final selection =
            focusSelectionForItem(occurrence) ??
            FocusTaskSelection(
              taskId: occurrence.id ?? 0,
              taskTitle: occurrence.title,
              categoryId: -1,
              categoryTitle: 'Unassigned',
              categoryIcon: 'mi_timer',
              isEvent: true,
            );
        result.add(ScheduledEventFocusInterval(start, end, selection));
      }
    }

    result.sort((first, second) {
      final byStart = first.start.compareTo(second.start);
      if (byStart != 0) return byStart;
      return first.selection.taskId.compareTo(second.selection.taskId);
    });
    return result;
  }

  List<PlannerItem> _itemsForRange(DateTime firstDay, DateTime lastDay) {
    final from = dateOnly(firstDay);
    final through = dateOnly(lastDay);
    final result = <PlannerItem>[];
    for (final series in _items) {
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: from,
        through: through,
      )) {
        final completed =
            series is Task &&
            series.id != null &&
            _taskOccurrenceCompletionKeys.contains(
              taskOccurrenceKey(series.id!, occurrenceDate),
            );
        result.add(
          occurrenceForDate(series, occurrenceDate, isCompleted: completed),
        );
      }
    }
    result.sort(_compareItems);
    return result;
  }

  Event? _nextSelectableEventOccurrence(Event series, DateTime now) {
    for (final occurrenceDate in recurrenceDatesInRange(
      series,
      from: dateOnly(now),
      through: DateTime(9999, 12, 31),
    )) {
      final occurrence = occurrenceForDate(series, occurrenceDate) as Event;
      if (!_hasEnded(occurrence, now)) return occurrence;
    }
    return null;
  }

  bool _isImported(PlannerItem item) => switch (item) {
    Task task => task.sourcePlatform?.trim().isNotEmpty ?? false,
    Event event => event.sourcePlatform?.trim().isNotEmpty ?? false,
    _ => false,
  };

  bool _hasEnded(PlannerItem item, DateTime now) {
    if (item is Task) return !taskDateTime(item).isAfter(now);
    if (item is Event) {
      if (item.allDay) {
        final endExclusive = dateOnly(
          item.endDate,
        ).add(const Duration(days: 1));
        return !endExclusive.isAfter(now);
      }
      var end = eventEndDateTime(item);
      if (!end.isAfter(eventStartDateTime(item))) {
        end = end.add(const Duration(days: 1));
      }
      return !end.isAfter(now);
    }
    return false;
  }

  PlannerItem? _nextUpcomingFrom(Iterable<PlannerItem> source, DateTime now) {
    final today = dateOnly(now);
    PlannerItem? next;
    DateTime? nextAt;
    for (final series in source) {
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: today,
        through: DateTime(9999, 12, 31),
      )) {
        final completed =
            series is Task &&
            (isRecurring(series)
                ? series.id != null &&
                      _taskOccurrenceCompletionKeys.contains(
                        taskOccurrenceKey(series.id!, occurrenceDate),
                      )
                : series.isChecked);
        if (completed) continue;
        final occurrence = occurrenceForDate(
          series,
          occurrenceDate,
          isCompleted: completed,
        );
        final startsAt = _scheduledDate(occurrence);
        final allDayIsToday =
            occurrence is Event &&
            occurrence.allDay &&
            _sameDay(occurrence.date, today);
        if (startsAt.isBefore(now) && !allDayIsToday) continue;
        if (nextAt == null || startsAt.isBefore(nextAt)) {
          next = occurrence;
          nextAt = startsAt;
        }
        break;
      }
    }
    return next;
  }

  int _compareItems(PlannerItem first, PlannerItem second) =>
      _scheduledDate(first).compareTo(_scheduledDate(second));

  DateTime _scheduledDate(PlannerItem item) {
    if (item is Task) {
      return DateTime(
        item.date.year,
        item.date.month,
        item.date.day,
        item.time.hour,
        item.time.minute,
      );
    }
    final event = item as Event;
    return DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      event.start.hour,
      event.start.minute,
    );
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  @override
  void dispose() {
    _isDisposed = true;
    _calendarSync.removeListener(_onCalendarSyncChanged);
    _calendarSync.dispose();
    _automaticEventFocusTimer?.cancel();
    super.dispose();
  }
}

class _MutableAutomaticFocusBucket {
  _MutableAutomaticFocusBucket({
    required this.selection,
    required this.seconds,
  });

  final FocusTaskSelection selection;
  int seconds;
}
