import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:tgram_analytics/tgram_analytics.dart';

const _server = 'https://analytics.example.com';
const _apiKey = 'proj_testkey123';

void main() {
  // Ensure singleton is cleared between tests.
  tearDown(() async {
    TGA.reset();
  });

  group('init', () {
    test('rejects API key not starting with proj_', () {
      expect(
        () => TGA.init('bad_key', _server),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty API key', () {
      expect(() => TGA.init('', _server), throwsA(isA<ArgumentError>()));
    });

    test('rejects empty server URL', () {
      expect(
        () => TGA.init(_apiKey, ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('double init logs warning and returns existing instance', () {
      final client = MockClient((_) async => http.Response('', 202));
      final first = TGA.init(_apiKey, _server, client: client);
      final second = TGA.init(_apiKey, _server, client: client);
      expect(identical(first, second), isTrue);
    });

    test('instance is null before init', () {
      expect(TGA.instance, isNull);
      expect(TGA.I, isNull);
    });

    test('isInitialized returns correct state', () {
      expect(TGA.isInitialized, isFalse);
      final client = MockClient((_) async => http.Response('', 202));
      TGA.init(_apiKey, _server, client: client);
      expect(TGA.isInitialized, isTrue);
    });

    test('strips trailing slash from server URL', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('', 202);
      });
      TGA.init(_apiKey, '$_server/', client: client);
      TGA.track('test', 's1');
      await TGA.close();
      expect(requests.first.url.toString(), '$_server/api/v1/track');
    });
  });

  group('track', () {
    test('sends correct payload', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      TGA.track('signup', 'sess-1', properties: {'plan': 'pro'});
      await TGA.close();

      expect(requests, hasLength(1));
      expect(requests.first.url.toString(), '$_server/api/v1/track');
      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(body['api_key'], _apiKey);
      expect(body['event_name'], 'signup');
      expect(body['session_id'], 'sess-1');
      expect((body['properties'] as Map)['plan'], 'pro');
      expect(body, containsPair('timestamp', isA<String>()));
    });

    test('merges identify properties', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      TGA.identify('sess-1', {'locale': 'en'});
      TGA.track('click', 'sess-1');
      await TGA.close();

      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect((body['properties'] as Map)['locale'], 'en');
    });

    test('per-event properties override identify', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      TGA.identify('sess-1', {'plan': 'free'});
      TGA.track('upgrade', 'sess-1', properties: {'plan': 'pro'});
      await TGA.close();

      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect((body['properties'] as Map)['plan'], 'pro');
    });

    test('identify scoped to session', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      TGA.identify('sess-1', {'plan': 'pro'});
      TGA.track('click', 'sess-2');
      await TGA.close();

      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect((body['properties'] as Map).containsKey('plan'), isFalse);
    });
  });

  group('pageview', () {
    test('sends correct payload', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      TGA.pageview(
        'sess-1',
        '/dashboard',
        referrer: 'https://google.com',
      );
      await TGA.close();

      expect(requests, hasLength(1));
      expect(requests.first.url.toString(), '$_server/api/v1/pageview');
      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(body['api_key'], _apiKey);
      expect(body['session_id'], 'sess-1');
      expect(body['url'], '/dashboard');
      expect(body['referrer'], 'https://google.com');
      expect(body, containsPair('timestamp', isA<String>()));
    });

    test('referrer defaults to null', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      TGA.pageview('sess-1', '/home');
      await TGA.close();

      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(body['referrer'], isNull);
    });
  });

  group('identify and forget', () {
    test('identify merges incrementally', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      TGA.identify('s1', {'a': 1});
      TGA.identify('s1', {'b': 2});
      TGA.track('test', 's1');
      await TGA.close();

      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      final props = body['properties'] as Map;
      expect(props['a'], 1);
      expect(props['b'], 2);
    });

    test('forget removes properties', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      TGA.identify('s1', {'a': 1});
      TGA.forget('s1');
      TGA.track('test', 's1');
      await TGA.close();

      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect((body['properties'] as Map).containsKey('a'), isFalse);
    });

    test('forget is no-op for unknown session', () async {
      final client = MockClient((_) async => http.Response('', 202));
      TGA.init(_apiKey, _server, client: client);
      TGA.forget('nonexistent'); // should not throw
    });
  });

  group('batching', () {
    test('flush sends batched events', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      TGA.init(
        _apiKey,
        _server,
        batch: const BatchOptions(maxSize: 100),
        client: client,
      );
      TGA.track('e1', 's1');
      TGA.track('e2', 's1');
      expect(requests, isEmpty);
      await TGA.flush();
      expect(requests, hasLength(2));
    });

    test('flush is no-op without batching', () async {
      final client = MockClient((_) async => http.Response('', 202));
      TGA.init(_apiKey, _server, client: client);
      await TGA.flush(); // should not throw
    });

    test('close flushes batched events', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });
      TGA.init(_apiKey, _server, batch: true, client: client);
      TGA.track('e1', 's1');
      await TGA.close();
      expect(requests, hasLength(1));
    });
  });

  group('error handling', () {
    test('HTTP error does not throw', () async {
      final client = MockClient(
        (_) async => http.Response('{"error":"bad"}', 400),
      );
      TGA.init(_apiKey, _server, client: client);
      TGA.track('test', 's1');
      await TGA.close(); // should not throw
    });

    test('network error does not throw', () async {
      final client = MockClient((_) async => throw Exception('no connection'));
      TGA.init(
        _apiKey,
        _server,
        client: client,
        timeout: const Duration(milliseconds: 500),
      );
      TGA.track('test', 's1');
      await TGA.close(); // should not throw
    });
  });

  group('singleton lifecycle', () {
    test('close clears singleton for re-init', () async {
      final client = MockClient((_) async => http.Response('', 202));
      TGA.init(_apiKey, _server, client: client);
      expect(TGA.isInitialized, isTrue);
      await TGA.close();
      expect(TGA.isInitialized, isFalse);

      // Can re-initialize after close.
      final client2 = MockClient((_) async => http.Response('', 202));
      TGA.init(_apiKey, _server, client: client2);
      expect(TGA.isInitialized, isTrue);
    });

    test('init returns the instance', () {
      final client = MockClient((_) async => http.Response('', 202));
      final tga = TGA.init(_apiKey, _server, client: client);
      expect(identical(tga, TGA.instance), isTrue);
    });
  });

  group('pre-init buffering', () {
    test('track before init buffers and flushes on init', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });

      // Track before init.
      TGA.track('early_event', 'sess-1', properties: {'key': 'val'});
      TGA.track('another_event', 'sess-1');
      expect(requests, isEmpty);

      // Init flushes buffered events.
      TGA.init(_apiKey, _server, client: client);
      await TGA.close();

      expect(requests, hasLength(2));
      final body1 = jsonDecode(requests[0].body) as Map<String, dynamic>;
      expect(body1['event_name'], 'early_event');
      expect(body1['api_key'], _apiKey);
      expect((body1['properties'] as Map)['key'], 'val');

      final body2 = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(body2['event_name'], 'another_event');
      expect(body2['api_key'], _apiKey);
    });

    test('pageview before init buffers and flushes on init', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('{"status":"accepted"}', 202);
      });

      TGA.pageview('sess-1', '/onboarding', referrer: 'https://google.com');
      expect(requests, isEmpty);

      TGA.init(_apiKey, _server, client: client);
      await TGA.close();

      expect(requests, hasLength(1));
      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(body['url'], '/onboarding');
      expect(body['referrer'], 'https://google.com');
      expect(body['api_key'], _apiKey);
    });

    test('identify before init is preserved', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('', 202);
      });

      TGA.identify('sess-1', {'plan': 'enterprise'});
      TGA.init(_apiKey, _server, client: client);
      TGA.track('test', 'sess-1');
      await TGA.close();

      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect((body['properties'] as Map)['plan'], 'enterprise');
    });

    test('forget before init removes buffered identify', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('', 202);
      });

      TGA.identify('sess-1', {'plan': 'pro'});
      TGA.forget('sess-1');
      TGA.init(_apiKey, _server, client: client);
      TGA.track('test', 'sess-1');
      await TGA.close();

      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect((body['properties'] as Map).containsKey('plan'), isFalse);
    });

    test('flush before init is no-op', () async {
      await TGA.flush(); // should not throw
    });

    test('close before init is no-op', () async {
      await TGA.close(); // should not throw
    });

    test('track before init does not throw', () {
      TGA.track('event', 'sess-1'); // should not throw
    });

    test('buffered events preserve original timestamp', () async {
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('', 202);
      });

      TGA.track('early', 'sess-1');
      // Slight delay to ensure timestamps differ.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      TGA.init(_apiKey, _server, client: client);
      TGA.track('late', 'sess-1');
      await TGA.close();

      final early = jsonDecode(requests[0].body) as Map<String, dynamic>;
      final late_ = jsonDecode(requests[1].body) as Map<String, dynamic>;
      final earlyTs = DateTime.parse(early['timestamp'] as String);
      final lateTs = DateTime.parse(late_['timestamp'] as String);
      expect(earlyTs.isBefore(lateTs), isTrue);
    });

    test('reset clears buffered events', () async {
      TGA.track('buffered', 'sess-1');
      TGA.identify('sess-1', {'key': 'val'});
      TGA.reset();

      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        return http.Response('', 202);
      });
      TGA.init(_apiKey, _server, client: client);
      await TGA.close();

      // No buffered events should have been flushed.
      expect(requests, isEmpty);
    });
  });
}
