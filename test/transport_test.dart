import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'package:tgram_analytics/src/transport.dart' as transport;

void main() {
  final timeout = const Duration(seconds: 10);

  group('send', () {
    test('sends POST with correct JSON body and Content-Type', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('{"status":"accepted"}', 202);
      });

      await transport.send(
        client,
        'https://example.com/api/v1/track',
        {'api_key': 'proj_test', 'event_name': 'signup'},
        timeout,
      );

      expect(captured.method, 'POST');
      expect(captured.headers['Content-Type'], contains('application/json'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['api_key'], 'proj_test');
      expect(body['event_name'], 'signup');
    });

    test('does not throw on HTTP 400', () async {
      final warnings = <String>[];
      Logger.root.level = Level.ALL;
      final sub = Logger('tgram_analytics').onRecord.listen((r) {
        if (r.level == Level.WARNING) warnings.add(r.message);
      });

      final client = MockClient(
        (_) async => http.Response('{"error":"bad"}', 400),
      );

      await transport.send(
        client,
        'https://example.com/api/v1/track',
        {'api_key': 'proj_test'},
        timeout,
      );

      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('400'));
      await sub.cancel();
    });

    test('does not throw on network error', () async {
      final client = MockClient((_) async => throw Exception('no connection'));

      // Should not throw.
      await transport.send(
        client,
        'https://example.com/api/v1/track',
        {'api_key': 'proj_test'},
        timeout,
      );
    });
  });
}
