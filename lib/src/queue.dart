import 'dart:async';

import 'package:http/http.dart' as http;

import 'transport.dart' as transport;
import 'types.dart';

class QueuedEvent {
  final String endpoint;
  final Map<String, Object?> payload;

  const QueuedEvent({required this.endpoint, required this.payload});
}

/// Async batching queue with [Timer]-based auto-flush.
///
/// [push] is synchronous (no await points), so it is atomic under Dart's
/// single-threaded event loop. [flush] is async and sends buffered events.
class EventQueue {
  final String _serverUrl;
  final http.Client _client;
  final BatchOptions _options;
  final Duration _timeout;
  final List<QueuedEvent> _buffer = [];
  Timer? _timer;

  EventQueue(this._serverUrl, this._client, this._options, this._timeout);

  /// Buffer an event for later sending. Triggers auto-flush when [maxSize] is
  /// reached, or starts a timer for [maxWait] auto-flush.
  void push(String endpoint, Map<String, Object?> payload) {
    _buffer.add(QueuedEvent(endpoint: endpoint, payload: payload));
    if (_buffer.length >= _options.maxSize) {
      _timer?.cancel();
      _timer = null;
      // Fire-and-forget: intentionally not awaited.
      unawaited(flush());
    } else {
      _timer ??= Timer(_options.maxWait, () => flush());
    }
  }

  /// Send all buffered events immediately.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final events = List<QueuedEvent>.of(_buffer);
    _buffer.clear();
    for (final ev in events) {
      await transport.send(
        _client,
        '$_serverUrl${ev.endpoint}',
        ev.payload,
        _timeout,
      );
    }
  }
}
