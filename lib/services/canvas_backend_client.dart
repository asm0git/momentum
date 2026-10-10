import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data_models.dart';
import 'canvas_cookie_client_stub.dart'
    if (dart.library.js_interop) 'canvas_cookie_client_web.dart'
    as cookie;

class CanvasConnectionStatus {
  const CanvasConnectionStatus({
    required this.connected,
    this.providerUrl,
    this.accountName,
    this.accountEmail,
    this.remoteUserId,
    this.lastSyncTime,
  });

  final bool connected;
  final String? providerUrl;
  final String? accountName;
  final String? accountEmail;
  final String? remoteUserId;
  final DateTime? lastSyncTime;

  factory CanvasConnectionStatus.fromJson(Map<String, dynamic> json) =>
      CanvasConnectionStatus(
        connected: json['connected'] == true,
        providerUrl: json['providerUrl'] as String?,
        accountName: json['accountName'] as String?,
        accountEmail: json['accountEmail'] as String?,
        remoteUserId: json['remoteUserId']?.toString(),
        lastSyncTime: json['lastSyncTime'] == null
            ? null
            : DateTime.parse(json['lastSyncTime'] as String).toLocal(),
      );
}

abstract interface class CanvasBackend {
  Uri oauthStartUri(String siteUrl);
  Future<CanvasConnectionStatus> status();
  Future<CanvasSyncPayload> sync();
  Future<void> disconnect();
}

abstract interface class ProviderCalendarBackend {
  Uri providerOAuthStartUri(CalendarProvider provider, {String? siteUrl});
  Future<CanvasConnectionStatus> providerStatus(CalendarProvider provider);
  Future<CanvasSyncPayload> syncProvider(CalendarProvider provider);
  Future<void> disconnectProvider(CalendarProvider provider);
}

class CanvasBackendClient implements CanvasBackend, ProviderCalendarBackend {
  CanvasBackendClient({http.Client? client})
    : _client = client ?? cookie.createCanvasHttpClient();

  static const _configuredBaseUrl = String.fromEnvironment(
    'CANVAS_BACKEND_URL',
  );

  final http.Client _client;

  Uri get _apiRoot {
    if (_configuredBaseUrl.isNotEmpty) {
      return Uri.parse(_configuredBaseUrl).replace(path: '/api/');
    }
    if (kIsWeb) return Uri.base.resolve('/api/');
    throw StateError(
      'Calendar linking requires CANVAS_BACKEND_URL or the deployed web app.',
    );
  }

  Uri _providerUri(CalendarProvider provider, String endpoint) =>
      _apiRoot.resolve('${provider.key}/$endpoint');

  @override
  Uri oauthStartUri(String siteUrl) =>
      providerOAuthStartUri(CalendarProvider.canvas, siteUrl: siteUrl);

  @override
  Uri providerOAuthStartUri(CalendarProvider provider, {String? siteUrl}) {
    final uri = _providerUri(provider, 'oauth/start');
    if (provider == CalendarProvider.canvas) {
      if (siteUrl == null || siteUrl.trim().isEmpty) {
        throw ArgumentError.value(siteUrl, 'siteUrl', 'Enter a Canvas URL.');
      }
      return uri.replace(queryParameters: {'siteUrl': siteUrl});
    }
    return uri;
  }

  @override
  Future<CanvasConnectionStatus> status() =>
      providerStatus(CalendarProvider.canvas);

  @override
  Future<CanvasConnectionStatus> providerStatus(
    CalendarProvider provider,
  ) async {
    final response = await _client.get(_providerUri(provider, 'status'));
    return CanvasConnectionStatus.fromJson(_decodeResponse(response));
  }

  @override
  Future<CanvasSyncPayload> sync() => syncProvider(CalendarProvider.canvas);

  @override
  Future<CanvasSyncPayload> syncProvider(CalendarProvider provider) async {
    final response = await _client.post(_providerUri(provider, 'sync'));
    final json = _decodeResponse(response);
    final tasks = (json['tasks'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (task) => CanvasTaskImport(
            externalId: task['externalId'] as String,
            title: task['title'] as String,
            due: DateTime.parse(task['due'] as String).toLocal(),
            description: task['description'] as String? ?? '',
          ),
        )
        .toList(growable: false);
    final events = (json['events'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (event) => CanvasEventImport(
            externalId: event['externalId'] as String,
            title: event['title'] as String,
            start: DateTime.parse(event['start'] as String).toLocal(),
            end: DateTime.parse(event['end'] as String).toLocal(),
            allDay: event['allDay'] == true,
            description: event['description'] as String? ?? '',
            location: event['location'] as String?,
          ),
        )
        .toList(growable: false);

    return CanvasSyncPayload(
      accountName: json['accountName'] as String? ?? provider.title,
      accountEmail: json['accountEmail'] as String?,
      remoteUserId: json['remoteUserId']?.toString() ?? '',
      providerUrl: json['providerUrl'] as String? ?? '',
      syncedAt: DateTime.parse(json['syncedAt'] as String).toLocal(),
      tasks: tasks,
      events: events,
      providerName: provider.key,
    );
  }

  @override
  Future<void> disconnect() => disconnectProvider(CalendarProvider.canvas);

  @override
  Future<void> disconnectProvider(CalendarProvider provider) async {
    final response = await _client.post(_providerUri(provider, 'disconnect'));
    _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw StateError('Calendar service returned an unreadable response.');
    }
    final json = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          json['error'] as String? ??
          'Calendar service request failed (${response.statusCode}).';
      throw StateError(message);
    }
    return json;
  }
}
