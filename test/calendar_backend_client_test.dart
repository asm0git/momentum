import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/services/calendar_backend_client.dart';

void main() {
  group('CalendarBackendClient requests and successful responses', () {
    test('Canvas OAuth URL includes the requested site URL', () {
      final client = _clientWith(body: '{}');

      final uri = client.providerOAuthStartUri(
        CalendarProvider.canvas,
        siteUrl: 'https://school.example.test/courses',
      );

      expect(uri.path, '/api/canvas/oauth/start');
      expect(
        uri.queryParameters,
        {'siteUrl': 'https://school.example.test/courses'},
      );
    });

    test('Canvas OAuth URL requires a non-empty site URL', () {
      final client = _clientWith(body: '{}');

      expect(
        () => client.providerOAuthStartUri(CalendarProvider.canvas),
        throwsArgumentError,
      );
      expect(
        () => client.providerOAuthStartUri(
          CalendarProvider.canvas,
          siteUrl: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('provider status parses account details and the last sync time', () async {
      final client = _clientWith(
        body:
            '{"connected":true,"providerUrl":"https://feed.example.test",'
            '"accountName":"Study account","accountEmail":"user@example.test",'
            '"remoteUserId":42,"lastSyncTime":"2026-10-14T02:30:00Z"}',
      );

      final status = await client.providerStatus(CalendarProvider.outlook);

      expect(status.connected, isTrue);
      expect(status.providerUrl, 'https://feed.example.test');
      expect(status.accountName, 'Study account');
      expect(status.accountEmail, 'user@example.test');
      expect(status.remoteUserId, '42');
      expect(status.lastSyncTime, DateTime.parse('2026-10-14T02:30:00Z').toLocal());
    });

    test('sync parses task and event imports with provider defaults', () async {
      final client = _clientWith(
        body: '''
          {
            "remoteUserId": 42,
            "syncedAt": "2026-10-14T02:30:00Z",
            "tasks": [
              {"externalId":"task-1","title":"Read chapter","due":"2026-10-15T00:00:00Z"}
            ],
            "events": [
              {"externalId":"event-1","title":"Review","start":"2026-10-15T09:00:00Z","end":"2026-10-15T10:00:00Z","allDay":true,"description":"Bring notes","location":"Room 4"}
            ]
          }
        ''',
      );

      final payload = await client.syncProvider(CalendarProvider.googleCalendar);

      expect(payload.accountName, 'Google Calendar');
      expect(payload.accountEmail, isNull);
      expect(payload.remoteUserId, '42');
      expect(payload.providerUrl, '');
      expect(payload.providerName, 'google');
      expect(payload.syncedAt, DateTime.parse('2026-10-14T02:30:00Z').toLocal());
      expect(payload.tasks, hasLength(1));
      expect(payload.tasks.single.externalId, 'task-1');
      expect(payload.tasks.single.description, isEmpty);
      expect(payload.tasks.single.due, DateTime.parse('2026-10-15T00:00:00Z').toLocal());
      expect(payload.events, hasLength(1));
      expect(payload.events.single.externalId, 'event-1');
      expect(payload.events.single.allDay, isTrue);
      expect(payload.events.single.description, 'Bring notes');
      expect(payload.events.single.location, 'Room 4');
      expect(payload.events.single.start, DateTime.parse('2026-10-15T09:00:00Z').toLocal());
      expect(payload.events.single.end, DateTime.parse('2026-10-15T10:00:00Z').toLocal());
    });

    test('connect and disconnect send their expected requests', () async {
      final requests = <http.Request>[];
      final client = _clientFor((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      });

      await client.connectCalendarIcsFeed(
        CalendarProvider.googleCalendar,
        'https://calendar.example.test/feed.ics',
      );
      await client.disconnectProvider(CalendarProvider.googleCalendar);

      expect(requests, hasLength(2));
      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, '/api/google/connect');
      expect(requests[0].headers['content-type'], 'application/json');
      expect(jsonDecode(requests[0].body), {
        'url': 'https://calendar.example.test/feed.ics',
      });
      expect(requests[1].method, 'POST');
      expect(requests[1].url.path, '/api/google/disconnect');
    });

    test('non-object JSON receives an endpoint-specific backend error', () async {
      final client = _clientWith(body: '[]');

      final error = await _captureError(
        () => client.providerStatus(CalendarProvider.canvas),
      );

      expect(error, isA<CalendarBackendException>());
      final backendError = error as CalendarBackendException;
      expect(backendError.message, 'The service returned a JSON value instead of an object.');
      expect(backendError.cause, isA<FormatException>());
      expect(backendError.causeStackTrace, isNotNull);
    });
  });

  group('CalendarBackendClient response errors', () {
    test('invalid JSON keeps its cause and endpoint context', () async {
      final client = _clientWith(body: '{');

      final error = await _captureError(
        () => client.providerStatus(CalendarProvider.googleCalendar),
      );

      expect(error, isA<CalendarBackendException>());
      final backendError = error as CalendarBackendException;
      expect(backendError.provider, CalendarProvider.googleCalendar);
      expect(backendError.endpoint, 'status');
      expect(backendError.statusCode, 200);
      expect(backendError.cause, isA<FormatException>());
      expect(backendError.causeStackTrace, isNotNull);
      expect(backendError.toString(), contains('google/status'));
    });

    test(
      'invalid status fields are translated at the client boundary',
      () async {
        final client = _clientWith(body: '{"connected":true,"providerUrl":42}');

        final error = await _captureError(
          () => client.providerStatus(CalendarProvider.canvas),
        );

        expect(error, isA<CalendarBackendException>());
        final backendError = error as CalendarBackendException;
        expect(backendError.provider, CalendarProvider.canvas);
        expect(backendError.endpoint, 'status');
        expect(backendError.cause, isA<FormatException>());
        expect(backendError.causeStackTrace, isNotNull);
      },
    );

    test(
      'invalid sync dates are translated with sync endpoint context',
      () async {
        final client = _clientWith(
          body: '{"syncedAt":"not-a-date","tasks":[],"events":[]}',
        );

        final error = await _captureError(
          () => client.syncProvider(CalendarProvider.outlook),
        );

        expect(error, isA<CalendarBackendException>());
        final backendError = error as CalendarBackendException;
        expect(backendError.provider, CalendarProvider.outlook);
        expect(backendError.endpoint, 'sync');
        expect(backendError.cause, isA<FormatException>());
        expect(backendError.causeStackTrace, isNotNull);
      },
    );

    test('HTTP errors retain their status and service message', () async {
      final client = _clientWith(
        body: '{"error":"Calendar is offline."}',
        statusCode: 503,
      );

      final error = await _captureError(
        () => client.providerStatus(CalendarProvider.googleCalendar),
      );

      expect(error, isA<CalendarBackendException>());
      final backendError = error as CalendarBackendException;
      expect(backendError.statusCode, 503);
      expect(backendError.message, 'Calendar is offline.');
      expect(backendError.cause, isNull);
    });
  });
}

CalendarBackendClient _clientWith({
  required String body,
  int statusCode = 200,
}) => CalendarBackendClient(
  client: MockClient((_) async => http.Response(body, statusCode)),
  apiRoot: Uri.parse('https://calendar.example.test/api/'),
);

CalendarBackendClient _clientFor(
  Future<http.Response> Function(http.Request request) handler,
) => CalendarBackendClient(
  client: MockClient(handler),
  apiRoot: Uri.parse('https://calendar.example.test/api/'),
);

Future<Object> _captureError(Future<Object?> Function() action) async {
  try {
    await action();
  } catch (error) {
    return error;
  }
  fail('Expected a CalendarBackendException.');
}
