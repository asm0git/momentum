import 'package:flutter/foundation.dart';

import '../data/debug_demo_data.dart';
import '../data/planner_repository.dart';
import '../data/recurrence.dart';
import '../data_models.dart';
import '../services/calendar_backend_client.dart';
import 'automatic_event_focus_coordinator.dart';
import 'calendar_sync_coordinator.dart';
import 'focus_history_source.dart';
import 'planner_snapshot_queries.dart';
export 'automatic_event_focus_coordinator.dart'
    show
        AutomaticFocusBucket,
        ScheduledEventFocusInterval,
        aggregateAutomaticFocusBuckets;

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
    _automaticEventFocus = AutomaticEventFocusCoordinator(
      events: () => _items.whereType<Event>(),
      selectionForItem: focusSelectionForItem,
      recordBatch: _repository.addFocusSecondsBatch,
      onRecorded: _onAutomaticFocusRecorded,
      clock: _clock,
      enabled: _automaticFocusTimerEnabled,
    );
    _snapshotQueries = _createSnapshotQueries();
  }

  final PlannerRepository _repository;
  final ProviderCalendarBackend _calendarBackend;
  late final CalendarSyncCoordinator _calendarSync;
  late final AutomaticEventFocusCoordinator _automaticEventFocus;
  late PlannerSnapshotQueries _snapshotQueries;
  final bool _autoSyncCalendarsOnStartup;
  final DateTime Function() _clock;
  final bool _automaticFocusTimerEnabled;
  final bool includeDebugDemoData;
  List<TaskCategory> _categories = [];
  List<PlannerItem> _items = [];
  Set<String> _taskOccurrenceCompletionKeys = {};
  List<LinkedAccount> _linkedAccounts = [];
  bool _isLoading = true;
  Object? _error;
  bool _isDisposed = false;
  int _focusHistoryRevision = 0;

  PlannerSnapshotQueries _createSnapshotQueries() => PlannerSnapshotQueries(
    categories: _categories,
    items: _items,
    taskOccurrenceCompletionKeys: _taskOccurrenceCompletionKeys,
    categoryDisplayIconName: categoryDisplayIconName,
  );

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

  PlannerItem? get nextUpcomingItem =>
      _snapshotQueries.nextUpcomingItem(DateTime.now());

  FocusTaskSelection? get defaultFocusSelection {
    final activeEvent = eventFocusSelectionAt(DateTime.now());
    return activeEvent ?? focusSelectionForItem(nextUpcomingItem);
  }

  PlannerItem? nextUpcomingItemForCategory(int categoryId, DateTime now) =>
      _snapshotQueries.nextUpcomingItemForCategory(categoryId, now);

  List<PlannerItem> itemsForDate(DateTime date) =>
      _snapshotQueries.itemsForDate(date);

  List<PlannerItem> itemsForRange(DateTime firstDay, DateTime lastDay) =>
      _snapshotQueries.itemsForRange(firstDay, lastDay);

  /// Returns one visible row per category item. Recurring items are represented
  /// by their next date, with task completion scoped to that occurrence.
  List<PlannerItem> itemsForCategory(int categoryId) =>
      _snapshotQueries.itemsForCategory(categoryId, now: DateTime.now());

  /// The To-Do screen hides imported items after their scheduled time passes.
  /// The underlying planner snapshot and database remain unchanged.
  List<PlannerItem> todoItemsForCategory(int categoryId, {DateTime? now}) =>
      _snapshotQueries.todoItemsForCategory(
        categoryId,
        now: now ?? DateTime.now(),
      );

  /// Incomplete tasks and not-yet-ended events available to the Pomodoro
  /// selector. Each recurring series appears once at its next occurrence.
  List<FocusTaskSelection> get selectableFocusItems =>
      _snapshotQueries.selectableFocusItems(DateTime.now());

  /// Incomplete categorized tasks, with recurring series represented once.
  List<FocusTaskSelection> get selectableFocusTasks =>
      _snapshotQueries.selectableFocusTasks(DateTime.now());

  FocusTaskSelection? focusSelectionForItem(PlannerItem? item) =>
      _snapshotQueries.focusSelectionForItem(item);

  /// Resolves a generated calendar occurrence to the saved series record.
  PlannerItem seriesFor(PlannerItem occurrence) =>
      _snapshotQueries.seriesFor(occurrence);

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
    _automaticEventFocus.start();
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
    _snapshotQueries = _createSnapshotQueries();
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
    return _automaticEventFocus.eventFocusSelectionAt(instant);
  }

  /// Returns the next event start or end inside an elapsed Pomodoro chunk.
  @override
  DateTime? nextEventFocusBoundaryAfter(DateTime instant, DateTime through) {
    return _automaticEventFocus.nextEventFocusBoundaryAfter(instant, through);
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

  @visibleForTesting
  Future<void> recordAutomaticEventFocusForTesting() =>
      _automaticEventFocus.recordCurrentInterval();

  void _onAutomaticFocusRecorded() {
    if (_isDisposed) return;
    _focusHistoryRevision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _calendarSync.removeListener(_onCalendarSyncChanged);
    _calendarSync.dispose();
    _automaticEventFocus.dispose();
    super.dispose();
  }
}
