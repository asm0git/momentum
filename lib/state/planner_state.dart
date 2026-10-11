import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/debug_demo_data.dart';
import '../data/model_serialization.dart';
import '../data/planner_repository.dart';
import '../data/recurrence.dart';
import '../data_models.dart';
import '../services/canvas_backend_client.dart';

class PlannerState extends ChangeNotifier {
  PlannerState({
    PlannerRepository? repository,
    CanvasBackend? canvasBackend,
    ProviderCalendarBackend? calendarBackend,
    bool? autoSyncCanvasOnStartup,
    this.includeDebugDemoData = false,
  }) : _repository = repository ?? PlannerRepository(),
       _canvasBackend = canvasBackend ?? CanvasBackendClient(),
       _calendarBackend =
           calendarBackend ??
           (canvasBackend is ProviderCalendarBackend
               ? canvasBackend as ProviderCalendarBackend
               : CanvasBackendClient()),
       _autoSyncCanvasOnStartup = autoSyncCanvasOnStartup ?? kIsWeb;

  final PlannerRepository _repository;
  final CanvasBackend _canvasBackend;
  final ProviderCalendarBackend _calendarBackend;
  final bool _autoSyncCanvasOnStartup;
  final bool includeDebugDemoData;
  List<TaskCategory> _categories = [];
  List<PlannerItem> _items = [];
  Set<String> _taskOccurrenceCompletionKeys = {};
  Timer? _calendarRefreshTimer;
  Timer? _automaticEventFocusTimer;
  DateTime? _automaticEventFocusCursor;
  bool _isRecordingAutomaticEventFocus = false;
  LinkedAccount? _canvasAccount;
  List<LinkedAccount> _linkedAccounts = [];
  CanvasConnectionStatus? _canvasConnectionStatus;
  final Map<CalendarProvider, CanvasConnectionStatus> _providerStatuses = {};
  final Set<CalendarProvider> _syncingProviders = {};
  final Map<CalendarProvider, Object> _providerErrors = {};
  bool _isCanvasSyncing = false;
  double _canvasSyncProgress = 0;
  Object? _canvasError;
  Future<CanvasConnectionStatus>? _canvasStatusFuture;
  bool _isLoading = true;
  Object? _error;
  bool _isDisposed = false;
  int _focusHistoryRevision = 0;

  List<TaskCategory> get categories => List.unmodifiable(_categories);
  List<PlannerItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  Object? get error => _error;
  int get focusHistoryRevision => _focusHistoryRevision;
  LinkedAccount? get canvasAccount => _canvasAccount;
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
                    item.srcPlatform?.toLowerCase() == provider.key) ||
                (item is Event &&
                    item.srcPlatform?.toLowerCase() == provider.key),
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

  CanvasConnectionStatus? statusForProvider(CalendarProvider provider) =>
      _providerStatuses[provider] ??
      (provider == CalendarProvider.canvas ? _canvasConnectionStatus : null);
  bool isProviderSyncing(CalendarProvider provider) =>
      _syncingProviders.contains(provider) ||
      (provider == CalendarProvider.canvas && _isCanvasSyncing);
  Object? errorForProvider(CalendarProvider provider) =>
      _providerErrors[provider] ??
      (provider == CalendarProvider.canvas ? _canvasError : null);
  CanvasConnectionStatus? get canvasConnectionStatus => _canvasConnectionStatus;
  bool get isCanvasConnected => _canvasConnectionStatus?.connected ?? false;
  bool get isCanvasSyncing => _isCanvasSyncing;
  double get canvasSyncProgress => _canvasSyncProgress;
  Object? get canvasError => _canvasError;

  Uri canvasOAuthStartUri(String siteUrl) =>
      _canvasBackend.oauthStartUri(siteUrl);

  Uri providerOAuthStartUri(CalendarProvider provider, {String? siteUrl}) =>
      _calendarBackend.providerOAuthStartUri(provider, siteUrl: siteUrl);

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
      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: today,
        through: DateTime(9999, 12, 31),
      )) {
        final completed =
            series is Task &&
            series.id != null &&
            _taskOccurrenceCompletionKeys.contains(
              taskOccurrenceKey(series.id!, occurrenceDate),
            );
        if (completed) continue;
        result.add(
          occurrenceForDate(series, occurrenceDate, isCompleted: completed),
        );
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

      for (final occurrenceDate in recurrenceDatesInRange(
        series,
        from: dateOnly(currentTime),
        through: DateTime(9999, 12, 31),
      )) {
        final completed =
            series is Task &&
            series.id != null &&
            _taskOccurrenceCompletionKeys.contains(
              taskOccurrenceKey(series.id!, occurrenceDate),
            );
        if (completed) continue;
        final occurrence = occurrenceForDate(
          series,
          occurrenceDate,
          isCompleted: completed,
        );
        if (_hasEnded(occurrence, currentTime)) continue;
        result.add(occurrence);
        break;
      }
    }
    result.sort(_compareItems);
    return List.unmodifiable(result);
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
    _automaticEventFocusCursor ??= DateTime.now();
    _automaticEventFocusTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_recordAutomaticEventFocus()),
    );
    if (_autoSyncCanvasOnStartup) {
      _startCalendarRefreshTimer();
      unawaited(_autoSyncCalendarsIfDue());
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
    _canvasAccount = accounts
        .where((account) => account.platformName.toLowerCase() == 'canvas')
        .firstOrNull;
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

  Future<CanvasConnectionStatus> refreshCanvasStatus() {
    final inFlight = _canvasStatusFuture;
    if (inFlight != null) return inFlight;
    late final Future<CanvasConnectionStatus> tracked;
    tracked = _refreshCanvasStatus().whenComplete(() {
      if (identical(_canvasStatusFuture, tracked)) {
        _canvasStatusFuture = null;
      }
    });
    _canvasStatusFuture = tracked;
    return tracked;
  }

  Future<CanvasConnectionStatus> _refreshCanvasStatus() async {
    final status = await _canvasBackend.status();
    _canvasConnectionStatus = status;
    if (!_isDisposed) notifyListeners();
    return status;
  }

  Future<CanvasConnectionStatus> refreshProviderStatus(
    CalendarProvider provider,
  ) async {
    final status = await _calendarBackend.providerStatus(provider);
    _providerStatuses[provider] = status;
    if (provider == CalendarProvider.canvas) _canvasConnectionStatus = status;
    if (!_isDisposed) notifyListeners();
    return status;
  }

  Future<void> syncCanvas({bool replaceExistingImports = false}) async {
    if (_isCanvasSyncing) return;
    _isCanvasSyncing = true;
    _canvasSyncProgress = 0.05;
    _canvasError = null;
    if (!_isDisposed) notifyListeners();
    try {
      final payload = await _canvasBackend.sync();
      _canvasSyncProgress = 0.8;
      if (!_isDisposed) notifyListeners();
      await _repository.applyCanvasSync(
        payload,
        replaceExistingImports: replaceExistingImports,
      );
      await _reloadSnapshot();
      _canvasConnectionStatus = CanvasConnectionStatus(
        connected: true,
        providerUrl: payload.providerUrl,
        accountName: payload.accountName,
        accountEmail: payload.accountEmail,
        remoteUserId: payload.remoteUserId,
        lastSyncTime: payload.syncedAt,
      );
      _canvasSyncProgress = 1;
    } catch (error) {
      _canvasError = error;
      rethrow;
    } finally {
      _isCanvasSyncing = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> syncProvider(
    CalendarProvider provider, {
    bool replaceExistingImports = false,
  }) async {
    if (_syncingProviders.contains(provider)) return;
    _syncingProviders.add(provider);
    _providerErrors.remove(provider);
    if (!_isDisposed) notifyListeners();
    try {
      final payload = await _calendarBackend.syncProvider(provider);
      await _repository.applyCalendarSync(
        payload,
        replaceExistingImports: replaceExistingImports,
        removeMissingTasks: true,
        removeMissingEvents: true,
      );
      await _reloadSnapshot();
      _providerStatuses[provider] = CanvasConnectionStatus(
        connected: true,
        providerUrl: payload.providerUrl,
        accountName: payload.accountName,
        accountEmail: payload.accountEmail,
        remoteUserId: payload.remoteUserId,
        lastSyncTime: payload.syncedAt,
      );
      if (provider == CalendarProvider.canvas) {
        _canvasConnectionStatus = _providerStatuses[provider];
      }
    } catch (error) {
      _providerErrors[provider] = error;
      rethrow;
    } finally {
      _syncingProviders.remove(provider);
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> connectCalendarIcsFeed(
    CalendarProvider provider,
    String url,
  ) async {
    await _calendarBackend.connectCalendarIcsFeed(provider, url);
    final status = await _calendarBackend.providerStatus(provider);
    _providerStatuses[provider] = status;
    if (provider == CalendarProvider.canvas) _canvasConnectionStatus = status;
    _providerErrors.remove(provider);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> disconnectCanvas() async {
    await _canvasBackend.disconnect();
    try {
      final account = _canvasAccount;
      if (account != null && account.id != null) {
        // Keep the last account identity so a later connection to a different
        // account can replace only the old Canvas imports after sync succeeds.
        account.lastSyncTime = null;
        await _repository.updateLinkedAccount(account);
      }
      await _reloadSnapshot();
    } finally {
      // Publish the disconnected state only after persistence and the shared
      // snapshot have finished refreshing. This keeps listeners from seeing a
      // completed disconnect while the screen still has stale account data.
      _canvasConnectionStatus = const CanvasConnectionStatus(connected: false);
      _canvasError = null;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> disconnectProvider(CalendarProvider provider) async {
    await _calendarBackend.disconnectProvider(provider);
    try {
      final account = accountForProvider(provider);
      if (account != null && account.id != null) {
        // Retain the account identity as a local sync marker. Imported records
        // stay visible while disconnected, and account changes can be detected
        // after the next successful sync.
        account.lastSyncTime = null;
        await _repository.updateLinkedAccount(account);
      }
      await _reloadSnapshot();
    } finally {
      _providerStatuses[provider] = const CanvasConnectionStatus(
        connected: false,
      );
      if (provider == CalendarProvider.canvas) {
        _canvasConnectionStatus = const CanvasConnectionStatus(
          connected: false,
        );
        _canvasError = null;
      }
      _providerErrors.remove(provider);
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> _autoSyncCalendarsIfDue() async {
    for (final provider in CalendarProvider.values) {
      try {
        final status = await refreshProviderStatus(provider);
        if (!status.connected) continue;
        await syncProvider(provider);
      } catch (error) {
        _providerErrors[provider] = error;
        if (provider == CalendarProvider.canvas) _canvasError = error;
        if (!_isDisposed) notifyListeners();
      }
    }
  }

  void _startCalendarRefreshTimer() {
    if (_calendarRefreshTimer != null) return;
    _calendarRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_refreshCalendarsIfConnected()),
    );
  }

  Future<void> _recordAutomaticEventFocus() async {
    if (_isDisposed || _isRecordingAutomaticEventFocus) return;
    final from = _automaticEventFocusCursor;
    final through = DateTime.now();
    if (from == null || !through.isAfter(from)) {
      _automaticEventFocusCursor = through;
      return;
    }

    _isRecordingAutomaticEventFocus = true;
    try {
      final intervals = _eventFocusIntervals(from, through);
      final boundaries = <DateTime>{from, through};
      for (final interval in intervals) {
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
      final totals = <DateTime, Map<int, _AutomaticFocusBucket>>{};
      for (var index = 0; index + 1 < orderedBoundaries.length; index++) {
        final start = orderedBoundaries[index];
        final end = orderedBoundaries[index + 1];
        if (!end.isAfter(start)) continue;
        _ScheduledEventFocus? active;
        for (final interval in intervals) {
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
          () => <int, _AutomaticFocusBucket>{},
        );
        final categoryId = active.selection.categoryId;
        final bucket = byCategory[categoryId];
        if (bucket == null) {
          byCategory[categoryId] = _AutomaticFocusBucket(
            selection: active.selection,
            seconds: seconds,
          );
        } else {
          bucket.seconds += seconds;
        }
      }

      for (final dayEntry in totals.entries) {
        for (final bucket in dayEntry.value.values) {
          await addFocusSeconds(dayEntry.key, bucket.seconds, bucket.selection);
        }
      }
    } catch (_) {
      // Keep the app usable if local storage is temporarily unavailable.
    } finally {
      _automaticEventFocusCursor = through;
      _isRecordingAutomaticEventFocus = false;
    }
  }

  List<_ScheduledEventFocus> _eventFocusIntervals(
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
    final result = <_ScheduledEventFocus>[];

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
        result.add(_ScheduledEventFocus(start, end, selection));
      }
    }

    result.sort((first, second) {
      final byStart = first.start.compareTo(second.start);
      if (byStart != 0) return byStart;
      return first.selection.taskId.compareTo(second.selection.taskId);
    });
    return result;
  }

  Future<void> _refreshCalendarsIfConnected() async {
    if (_isDisposed) return;
    for (final provider in CalendarProvider.values) {
      try {
        final status = await refreshProviderStatus(provider);
        if (status.connected) await syncProvider(provider);
      } catch (error) {
        _providerErrors[provider] = error;
        if (provider == CalendarProvider.canvas) _canvasError = error;
        if (!_isDisposed) notifyListeners();
      }
    }
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
    Task task => task.srcPlatform?.trim().isNotEmpty ?? false,
    Event event => event.srcPlatform?.trim().isNotEmpty ?? false,
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
    _calendarRefreshTimer?.cancel();
    _automaticEventFocusTimer?.cancel();
    super.dispose();
  }
}

class _ScheduledEventFocus {
  const _ScheduledEventFocus(this.start, this.end, this.selection);

  final DateTime start;
  final DateTime end;
  final FocusTaskSelection selection;
}

class _AutomaticFocusBucket {
  _AutomaticFocusBucket({required this.selection, required this.seconds});

  final FocusTaskSelection selection;
  int seconds;
}
