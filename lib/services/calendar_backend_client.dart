import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/calendar_models.dart';
import 'canvas_cookie_client_stub.dart'
    if (dart.library.js_interop) 'canvas_cookie_client_web.dart'
    as cookie;

class CalendarConnectionStatus {
  const CalendarConnectionStatus({
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

  factory CalendarConnectionStatus.fromJson(Map<String, dynamic> json) =>
      CalendarConnectionStatus(
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

class CalendarBackendException implements Exception {
  const CalendarBackendException({
    required this.provider,
    required this.endpoint,
    required this.message,
    this.statusCode,
    this.cause,
    this.causeStackTrace,
  });

  final CalendarProvider provider;
  final String endpoint;
  final String message;
  final int? statusCode;
  final Object? cause;
  final StackTrace? causeStackTrace;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    final causeDetails = cause == null ? '' : ' Cause: $cause';
    return 'Calendar service ${provider.key}/$endpoint failed$status: '
        '$message$causeDetails';
  }
}

abstract interface class ProviderCalendarBackend {
  Uri providerOAuthStartUri(CalendarProvider provider, {String? siteUrl});
  Future<void> connectCalendarIcsFeed(CalendarProvider provider, String url);
  Future<CalendarConnectionStatus> providerStatus(CalendarProvider provider);
  Future<CalendarSyncPayload> syncProvider(CalendarProvider provider);
  Future<void> disconnectProvider(CalendarProvider provider);
}

class CalendarBackendClient implements ProviderCalendarBackend {
  CalendarBackendClient({http.Client? client, Uri? apiRoot})
    : _client = client ?? cookie.createCanvasHttpClient(),
      _apiRootOverride = apiRoot;

  static const _configuredBaseUrl = String.fromEnvironment(
    'CANVAS_BACKEND_URL',
  );

  final http.Client _client;
  final Uri? _apiRootOverride;

  Uri get _apiRoot {
    final override = _apiRootOverride;
    if (override != null) return override;
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
  Future<CalendarConnectionStatus> providerStatus(
    CalendarProvider provider,
  ) async {
    final response = await _client.get(_providerUri(provider, 'status'));
    final json = _decodeResponse(
      response,
      provider: provider,
      endpoint: 'status',
    );
    return _parseResponse(
      provider,
      'status',
      () => CalendarConnectionStatus.fromJson(json),
    );
  }

  @override
  Future<void> connectCalendarIcsFeed(
    CalendarProvider provider,
    String url,
  ) async {
    final response = await _client.post(
      _providerUri(provider, 'connect'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );
    _decodeResponse(response, provider: provider, endpoint: 'connect');
  }

  @override
  Future<CalendarSyncPayload> syncProvider(CalendarProvider provider) async {
    final response = await _client.post(_providerUri(provider, 'sync'));
    final json = _decodeResponse(
      response,
      provider: provider,
      endpoint: 'sync',
    );
    return _parseResponse(provider, 'sync', () {
      final tasks = (json['tasks'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (task) => CalendarTaskImport(
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
            (event) => CalendarEventImport(
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

      return CalendarSyncPayload(
        accountName: json['accountName'] as String? ?? provider.title,
        accountEmail: json['accountEmail'] as String?,
        remoteUserId: json['remoteUserId']?.toString() ?? '',
        providerUrl: json['providerUrl'] as String? ?? '',
        syncedAt: DateTime.parse(json['syncedAt'] as String).toLocal(),
        tasks: tasks,
        events: events,
        providerName: provider.key,
      );
    });
  }

  @override
  Future<void> disconnectProvider(CalendarProvider provider) async {
    final response = await _client.post(_providerUri(provider, 'disconnect'));
    _decodeResponse(response, provider: provider, endpoint: 'disconnect');
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required CalendarProvider provider,
    required String endpoint,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (error, stackTrace) {
      _throwResponseError(
        provider,
        endpoint,
        statusCode: response.statusCode,
        message: 'The service returned invalid JSON.',
        cause: error,
        causeStackTrace: stackTrace,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseMessage = decoded is Map<String, dynamic>
          ? decoded['error']
          : null;
      _throwResponseError(
        provider,
        endpoint,
        statusCode: response.statusCode,
        message: responseMessage is String && responseMessage.trim().isNotEmpty
            ? responseMessage
            : 'The service request failed.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      final stackTrace = StackTrace.current;
      _throwResponseError(
        provider,
        endpoint,
        statusCode: response.statusCode,
        message: 'The service returned a JSON value instead of an object.',
        cause: const FormatException('Expected a JSON object.'),
        causeStackTrace: stackTrace,
      );
    }
    return decoded;
  }

  T _parseResponse<T>(
    CalendarProvider provider,
    String endpoint,
    T Function() parse,
  ) {
    try {
      return parse();
    } catch (error, stackTrace) {
      _throwResponseError(
        provider,
        endpoint,
        message: 'The service response has an invalid shape.',
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  Never _throwResponseError(
    CalendarProvider provider,
    String endpoint, {
    int? statusCode,
    required String message,
    Object? cause,
    StackTrace? causeStackTrace,
  }) {
    final exception = CalendarBackendException(
      provider: provider,
      endpoint: endpoint,
      statusCode: statusCode,
      message: message,
      cause: cause,
      causeStackTrace: causeStackTrace,
    );
    if (causeStackTrace != null) {
      Error.throwWithStackTrace(exception, causeStackTrace);
    }
    throw exception;
  }
}
