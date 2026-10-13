import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/planner_repository.dart';
import '../data_models.dart';
import '../services/canvas_backend_client.dart';

/// Owns remote calendar status, sync state, and periodic refresh scheduling.
/// PlannerState remains responsible for the local planner snapshot.
class CalendarSyncCoordinator extends ChangeNotifier {
  CalendarSyncCoordinator({
    required PlannerRepository repository,
    required CanvasBackend canvasBackend,
    required ProviderCalendarBackend calendarBackend,
    required Future<void> Function() reloadSnapshot,
    required LinkedAccount? Function(CalendarProvider) accountForProvider,
    required bool Function() isParentDisposed,
  }) : _repository = repository,
       _canvasBackend = canvasBackend,
       _calendarBackend = calendarBackend,
       _reloadSnapshot = reloadSnapshot,
       _accountForProvider = accountForProvider,
       _isParentDisposed = isParentDisposed;

  final PlannerRepository _repository;
  final CanvasBackend _canvasBackend;
  final ProviderCalendarBackend _calendarBackend;
  final Future<void> Function() _reloadSnapshot;
  final LinkedAccount? Function(CalendarProvider) _accountForProvider;
  final bool Function() _isParentDisposed;

  final Map<CalendarProvider, CanvasConnectionStatus> _providerStatuses = {};
  final Set<CalendarProvider> _syncingProviders = {};
  final Map<CalendarProvider, Object> _providerErrors = {};
  CanvasConnectionStatus? _canvasConnectionStatus;
  bool _isCanvasSyncing = false;
  double _canvasSyncProgress = 0;
  Object? _canvasError;
  Future<CanvasConnectionStatus>? _canvasStatusFuture;
  Timer? _calendarRefreshTimer;
  bool _isDisposed = false;

  CanvasConnectionStatus? statusForProvider(CalendarProvider provider) =>
      _providerStatuses[provider] ??
      (provider == CalendarProvider.canvas ? _canvasConnectionStatus : null);

  bool isProviderSyncing(CalendarProvider provider) =>
      _syncingProviders.contains(provider) ||
      (provider == CalendarProvider.canvas && _isCanvasSyncing);

  Object? errorForProvider(CalendarProvider provider) =>
      _providerErrors[provider] ??
      (provider == CalendarProvider.canvas ? _canvasError : null);

  CanvasConnectionStatus? get canvasConnectionStatus =>
      _canvasConnectionStatus;
  bool get isCanvasConnected => _canvasConnectionStatus?.connected ?? false;
  bool get isCanvasSyncing => _isCanvasSyncing;
  double get canvasSyncProgress => _canvasSyncProgress;
  Object? get canvasError => _canvasError;

  Uri canvasOAuthStartUri(String siteUrl) =>
      _canvasBackend.oauthStartUri(siteUrl);

  Uri providerOAuthStartUri(CalendarProvider provider, {String? siteUrl}) =>
      _calendarBackend.providerOAuthStartUri(provider, siteUrl: siteUrl);

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
    _notifyChanged();
    return status;
  }

  Future<CanvasConnectionStatus> refreshProviderStatus(
    CalendarProvider provider,
  ) async {
    final status = await _calendarBackend.providerStatus(provider);
    _providerStatuses[provider] = status;
    if (provider == CalendarProvider.canvas) {
      _canvasConnectionStatus = status;
    }
    _notifyChanged();
    return status;
  }

  Future<void> syncCanvas({bool replaceExistingImports = false}) async {
    if (_isCanvasSyncing) return;
    _isCanvasSyncing = true;
    _canvasSyncProgress = 0.05;
    _canvasError = null;
    _notifyChanged();
    try {
      final payload = await _canvasBackend.sync();
      _canvasSyncProgress = 0.8;
      _notifyChanged();
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
      _notifyChanged();
    }
  }

  Future<void> syncProvider(
    CalendarProvider provider, {
    bool replaceExistingImports = false,
  }) async {
    if (_syncingProviders.contains(provider)) return;
    _syncingProviders.add(provider);
    _providerErrors.remove(provider);
    _notifyChanged();
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
      _notifyChanged();
    }
  }

  Future<void> connectCalendarIcsFeed(
    CalendarProvider provider,
    String url,
  ) async {
    await _calendarBackend.connectCalendarIcsFeed(provider, url);
    final status = await _calendarBackend.providerStatus(provider);
    _providerStatuses[provider] = status;
    if (provider == CalendarProvider.canvas) {
      _canvasConnectionStatus = status;
    }
    _providerErrors.remove(provider);
    _notifyChanged();
  }

  Future<void> disconnectCanvas() async {
    await _canvasBackend.disconnect();
    try {
      final account = _accountForProvider(CalendarProvider.canvas);
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
      _notifyChanged();
    }
  }

  Future<void> disconnectProvider(CalendarProvider provider) async {
    await _calendarBackend.disconnectProvider(provider);
    try {
      final account = _accountForProvider(provider);
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
      _notifyChanged();
    }
  }

  void startBackgroundRefresh() {
    _startCalendarRefreshTimer();
    unawaited(_autoSyncCalendarsIfDue());
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
        _notifyChanged();
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

  Future<void> _refreshCalendarsIfConnected() async {
    if (_isDisposed || _isParentDisposed()) return;
    for (final provider in CalendarProvider.values) {
      try {
        final status = await refreshProviderStatus(provider);
        if (status.connected) await syncProvider(provider);
      } catch (error) {
        _providerErrors[provider] = error;
        if (provider == CalendarProvider.canvas) _canvasError = error;
        _notifyChanged();
      }
    }
  }

  void _notifyChanged() {
    if (!_isDisposed && !_isParentDisposed()) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _calendarRefreshTimer?.cancel();
    super.dispose();
  }
}
