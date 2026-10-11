import 'dart:async';

import 'package:flutter/foundation.dart';

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
  List<TaskCategory> _categories = [];
  List<PlannerItem> _items = [];
  Set<String> _taskOccurrenceCompletionKeys = {};
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

  List<TaskCategory> get categories => List.unmodifiable(_categories);
  List<PlannerItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  Object? get error => _error;
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
        CalendarProvider.googleCalendar || CalendarProvider.outlook =>
          'mi_calendar_month',
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
      CalendarProvider.googleCalendar || CalendarProvider.outlook =>
        'mi_calendar_month',
    };
    if (category.iconName == legacyDefaultIcon ||
        category.iconName == provider.categoryIcon) {
      return provider.categoryIcon;
    }
    return category.iconName;
  }

  CanvasConnectionStatus? statusForProvider(CalendarProvider provider) =>
      provider == CalendarProvider.canvas
      ? _canvasConnectionStatus
      : _providerStatuses[provider];
  bool isProviderSyncing(CalendarProvider provider) =>
      provider == CalendarProvider.canvas
      ? _isCanvasSyncing
      : _syncingProviders.contains(provider);
  Object? errorForProvider(CalendarProvider provider) =>
      provider == CalendarProvider.canvas
      ? _canvasError
      : _providerErrors[provider];
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
    if (_autoSyncCanvasOnStartup) unawaited(_autoSyncCalendarsIfDue());
  }

  Future<void> retry() => initialize();

  Future<void> _reloadSnapshot() async {
    final categories = await _repository.getCategoriesWithItems();
    final items = await _repository.getAllItems();
    final occurrenceCompletions = await _repository
        .getTaskOccurrenceCompletionKeys();
    final accounts = await _repository.getLinkedAccounts();
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

  Future<int> getFocusSecondsForDate(DateTime date) =>
      _repository.getFocusSecondsForDate(date);

  Future<void> addFocusSeconds(DateTime date, int seconds) =>
      _repository.addFocusSeconds(date, seconds);

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
    if (provider == CalendarProvider.canvas) return refreshCanvasStatus();
    final status = await _calendarBackend.providerStatus(provider);
    _providerStatuses[provider] = status;
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
    if (provider == CalendarProvider.canvas) {
      return syncCanvas(replaceExistingImports: replaceExistingImports);
    }
    if (_syncingProviders.contains(provider)) return;
    _syncingProviders.add(provider);
    _providerErrors.remove(provider);
    if (!_isDisposed) notifyListeners();
    try {
      final payload = await _calendarBackend.syncProvider(provider);
      await _repository.applyCalendarSync(
        payload,
        replaceExistingImports: replaceExistingImports,
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
    } catch (error) {
      _providerErrors[provider] = error;
      rethrow;
    } finally {
      _syncingProviders.remove(provider);
      if (!_isDisposed) notifyListeners();
    }
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
    if (provider == CalendarProvider.canvas) return disconnectCanvas();
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
      _providerErrors.remove(provider);
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> _autoSyncCalendarsIfDue() async {
    for (final provider in CalendarProvider.values) {
      try {
        final status = await refreshProviderStatus(provider);
        if (!status.connected) continue;
        final lastSync = status.lastSyncTime;
        final account = accountForProvider(provider);
        final identityChanged =
            account == null ||
            (status.remoteUserId != null &&
                account.remoteUserId != status.remoteUserId) ||
            (status.providerUrl != null &&
                account.providerUrl != status.providerUrl);
        if (identityChanged ||
            account.lastSyncTime == null ||
            lastSync == null ||
            DateTime.now().difference(lastSync) >=
                const Duration(minutes: 15)) {
          await syncProvider(provider);
        }
      } catch (error) {
        if (provider == CalendarProvider.canvas) {
          _canvasError = error;
        } else {
          _providerErrors[provider] = error;
        }
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
    super.dispose();
  }
}
