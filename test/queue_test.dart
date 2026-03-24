import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:tgram_analytics/src/queue.dart';
import 'package:tgram_analytics/src/types.dart';

void main() {
  const server = 'https://example.com';
  const timeout = Duration(seconds: 10);

  group('EventQueue', () {
    test('buffers events until maxSize is reached', () {
      fakeAsync((async) {
        final requests = <http.Request>[];
        final client = MockClient((req) async {
          requests.add(req);
          return http.Response('{"status":"accepted"}', 202);
        });
        final queue = EventQueue(
          server,
          client,
          const BatchOptions(maxSize: 3, maxWait: Duration(seconds: 30)),
          timeout,
        );

        queue.push('/api/v1/track', {'event_name': 'e1'});
        queue.push('/api/v1/track', {'event_name': 'e2'});
        async.flushMicrotasks();
        expect(requests, isEmpty);

        queue.push('/api/v1/track', {'event_name': 'e3'});
        async.flushMicrotasks();
        expect(requests, hasLength(3));
      });
    });

    test('timer triggers flush after maxWait', () {
      fakeAsync((async) {
        final requests = <http.Request>[];
        final client = MockClient((req) async {
          requests.add(req);
          return http.Response('{"status":"accepted"}', 202);
        });
        final queue = EventQueue(
          server,
          client,
          const BatchOptions(maxSize: 100, maxWait: Duration(seconds: 5)),
          timeout,
        );

        queue.push('/api/v1/track', {'event_name': 'e1'});
        async.flushMicrotasks();
        expect(requests, isEmpty);

        async.elapse(const Duration(seconds: 5));
        expect(requests, hasLength(1));
      });
    });

    test('manual flush drains buffer', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      final queue = EventQueue(
        server,
        client,
        const BatchOptions(maxSize: 100),
        timeout,
      );

      queue.push('/api/v1/track', {'event_name': 'e1'});
      queue.push('/api/v1/track', {'event_name': 'e2'});
      await queue.flush();
      expect(requests, hasLength(2));
    });

    test('flush on empty buffer is no-op', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      final queue = EventQueue(
        server,
        client,
        const BatchOptions(),
        timeout,
      );

      await queue.flush();
      expect(requests, isEmpty);
    });

    test('sends to correct endpoint URL', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      final queue = EventQueue(
        server,
        client,
        const BatchOptions(maxSize: 100),
        timeout,
      );

      queue.push('/api/v1/track', {'event_name': 'e1'});
      queue.push('/api/v1/pageview', {'url': '/home'});
      await queue.flush();

      expect(requests[0].url.toString(), '$server/api/v1/track');
      expect(requests[1].url.toString(), '$server/api/v1/pageview');
    });

    test('sends correct JSON payload', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      final queue = EventQueue(
        server,
        client,
        const BatchOptions(maxSize: 100),
        timeout,
      );

      queue.push('/api/v1/track', {
        'api_key': 'proj_test',
        'event_name': 'click',
      });
      await queue.flush();

      final body =
          jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(body['api_key'], 'proj_test');
      expect(body['event_name'], 'click');
    });
  });
}
