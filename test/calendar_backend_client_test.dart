import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:momentum/data_models.dart';
import 'package:momentum/services/calendar_backend_client.dart';

void main() {
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
        expect(backendError.cause, isA<TypeError>());
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

Future<Object> _captureError(Future<Object?> Function() action) async {
  try {
    await action();
  } catch (error) {
    return error;
  }
  fail('Expected a CalendarBackendException.');
}
