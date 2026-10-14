// Public constructor names keep the coordinator's dependency fields private.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/calendar_sync_repository.dart';
import '../data_models.dart';
import '../services/calendar_backend_client.dart';

/// Owns remote provider status and sync request state.
class CalendarSyncCoordinator extends ChangeNotifier {
  CalendarSyncCoordinator({
    required CalendarSyncRepository repository,
    required ProviderCalendarBackend calendarBackend,
  }) : _repository = repository,
       _calendarBackend = calendarBackend;

  final CalendarSyncRepository _repository;
  final ProviderCalendarBackend _calendarBackend;

  final Map<CalendarProvider, CalendarConnectionStatus> _providerStatuses = {};
  final Set<CalendarProvider> _syncingProviders = {};
  final Map<CalendarProvider, Object> _providerErrors = {};
  final Map<CalendarProvider, Future<CalendarConnectionStatus>>
  _statusRequests = {};
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
    tracked =
        () async {
          try {
            final status = await _calendarBackend.providerStatus(provider);
            _providerStatuses[provider] = status;
            _providerErrors.remove(provider);
            _notifyChanged();
            return status;
          } catch (error) {
            _providerErrors[provider] = error;
            _notifyChanged();
            rethrow;
          }
        }().whenComplete(() {
          if (identical(_statusRequests[provider], tracked)) {
            _statusRequests.remove(provider);
          }
        });
    _statusRequests[provider] = tracked;
    return tracked;
  }

  Future<bool> syncProvider(
    CalendarProvider provider, {
    bool replaceExistingImports = false,
    bool removeMissingTasks = false,
    bool removeMissingEvents = false,
  }) async {
    if (!_syncingProviders.add(provider)) return false;
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
      _providerStatuses[provider] = CalendarConnectionStatus(
        connected: true,
        providerUrl: payload.providerUrl,
        accountName: payload.accountName,
        accountEmail: payload.accountEmail,
        remoteUserId: payload.remoteUserId,
        lastSyncTime: payload.syncedAt,
      );
      return true;
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

  Future<void> disconnectProvider(
    CalendarProvider provider, {
    LinkedAccount? account,
  }) async {
    await _calendarBackend.disconnectProvider(provider);
    try {
      if (account != null && account.id != null) {
        // Keep the local account identity as a marker for the next sync.
        final updatedAccount = LinkedAccount(
          id: account.id,
          platformName: account.platformName,
          accountName: account.accountName,
          accountEmail: account.accountEmail,
          providerUrl: account.providerUrl,
          remoteUserId: account.remoteUserId,
          categoryId: account.categoryId,
        );
        final updated = await _repository.updateLinkedAccount(updatedAccount);
        if (!updated) {
          throw StateError(
            'The linked calendar account was not updated in local storage.',
          );
        }
      }
    } catch (error) {
      _providerErrors[provider] = error;
      _notifyChanged();
      rethrow;
    }

    _providerStatuses[provider] = const CalendarConnectionStatus(
      connected: false,
    );
    _providerErrors.remove(provider);
    _notifyChanged();
  }

  void _notifyChanged() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
