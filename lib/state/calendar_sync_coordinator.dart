// Public constructor names keep the coordinator's dependency fields private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/planner_repository.dart';
import '../data_models.dart';
import '../services/calendar_backend_client.dart';

/// Owns remote provider status, sync operations, and periodic refreshes.
/// PlannerState remains responsible for the local planner snapshot.
class CalendarSyncCoordinator extends ChangeNotifier {
  CalendarSyncCoordinator({
    required PlannerRepository repository,
    required ProviderCalendarBackend calendarBackend,
    required Future<void> Function() reloadSnapshot,
    required LinkedAccount? Function(CalendarProvider) accountForProvider,
    required bool Function() isParentDisposed,
  }) : _repository = repository,
       _calendarBackend = calendarBackend,
       _reloadSnapshot = reloadSnapshot,
       _accountForProvider = accountForProvider,
       _isParentDisposed = isParentDisposed;

  final PlannerRepository _repository;
  final ProviderCalendarBackend _calendarBackend;
  final Future<void> Function() _reloadSnapshot;
  final LinkedAccount? Function(CalendarProvider) _accountForProvider;
  final bool Function() _isParentDisposed;

  final Map<CalendarProvider, CalendarConnectionStatus> _providerStatuses = {};
  final Set<CalendarProvider> _syncingProviders = {};
  final Map<CalendarProvider, Object> _providerErrors = {};
  final Map<CalendarProvider, Future<CalendarConnectionStatus>>
  _statusRequests = {};
  Timer? _calendarRefreshTimer;
  bool _isDisposed = false;

  CalendarConnectionStatus? statusForProvider(CalendarProvider provider) =>
      _providerStatuses[provider];

  bool isProviderSyncing(CalendarProvider provider) =>
      _syncingProviders.contains(provider);

  Object? errorForProvider(CalendarProvider provider) =>
      _providerErrors[provider];

  Uri providerOAuthStartUri(CalendarProvider provider, {String? siteUrl}) =>
      _calendarBackend.providerOAuthStartUri(provider, siteUrl: siteUrl);

  Future<CalendarConnectionStatus> refreshProviderStatus(
    CalendarProvider provider,
  ) {
    final inFlight = _statusRequests[provider];
    if (inFlight != null) return inFlight;

    late final Future<CalendarConnectionStatus> tracked;
    tracked = _calendarBackend
        .providerStatus(provider)
        .then((status) {
          _providerStatuses[provider] = status;
          _notifyChanged();
          return status;
        })
        .whenComplete(() {
          if (identical(_statusRequests[provider], tracked)) {
            _statusRequests.remove(provider);
          }
        });
    _statusRequests[provider] = tracked;
    return tracked;
  }

  Future<void> syncProvider(
    CalendarProvider provider, {
    bool replaceExistingImports = false,
    bool removeMissingTasks = false,
    bool removeMissingEvents = false,
  }) async {
    if (!_syncingProviders.add(provider)) return;
    _providerErrors.remove(provider);
    _notifyChanged();
    try {
      final payload = await _calendarBackend.syncProvider(provider);
      await _repository.applyCalendarSync(
        payload,
        replaceExistingImports: replaceExistingImports,
        removeMissingTasks: removeMissingTasks,
        removeMissingEvents: removeMissingEvents,
      );
      await _reloadSnapshot();
      _providerStatuses[provider] = CalendarConnectionStatus(
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
    _providerErrors.remove(provider);
    _notifyChanged();
  }

  Future<void> disconnectProvider(CalendarProvider provider) async {
    await _calendarBackend.disconnectProvider(provider);
    try {
      final account = _accountForProvider(provider);
      if (account != null && account.id != null) {
        // Keep the local account identity as a marker for the next sync.
        account.lastSyncTime = null;
        await _repository.updateLinkedAccount(account);
      }
      await _reloadSnapshot();
    } finally {
      _providerStatuses[provider] = const CalendarConnectionStatus(
        connected: false,
      );
      _providerErrors.remove(provider);
      _notifyChanged();
    }
  }

  void startBackgroundRefresh() {
    _startCalendarRefreshTimer();
    unawaited(_refreshCalendarsIfConnected());
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
