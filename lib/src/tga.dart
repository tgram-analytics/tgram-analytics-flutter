import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'queue.dart';
import 'transport.dart' as transport;
import 'types.dart';
import 'validate.dart';

final _log = Logger('tgram_analytics');

/// A buffered event captured before [TGA.init] was called.
class _PendingEvent {
  final String endpoint;
  final Map<String, Object?> payload;

  const _PendingEvent(this.endpoint, this.payload);
}

/// Lightweight tgram-analytics singleton client for Dart and Flutter.
///
/// All public methods are safe to call **before** [init]. Events tracked
/// before initialization are buffered in memory and flushed automatically
/// once [init] is called — no events are lost, no errors are thrown.
///
/// Call [TGA.init] once at app startup, then use the static convenience
/// methods (or [TGA.I]) anywhere.
///
/// Example:
/// ```dart
/// // Anywhere — even before init:
/// TGA.track('signup', 'session-123');
///
/// // In main():
/// TGA.init('proj_xxx', 'https://analytics.example.com');
/// // ^ buffered events are flushed automatically
/// ```
class TGA {
  // ---- singleton plumbing ----

  static TGA? _instance;

  /// Pre-init event buffer. Filled when methods are called before [init].
  static final List<_PendingEvent> _pending = [];

  /// Pre-init identify calls. Merged into the instance on [init].
  static final Map<String, EventProperties> _pendingIdentify = {};

  /// The singleton instance, or `null` if [init] has not been called yet.
  ///
  /// Prefer the static convenience methods ([TGA.track], [TGA.pageview], etc.)
  /// which are always safe to call. Use [I] only when you need the instance
  /// directly (e.g. to call [flush] or [close]).
  static TGA? get instance => _instance;

  /// Shorthand for [instance]. Returns `null` before [init].
  static TGA? get I => _instance;

  /// Whether the singleton has been initialized.
  static bool get isInitialized => _instance != null;

  // ---- static convenience API (always safe to call) ----

  /// Initialize the singleton [TGA] client.
  ///
  /// [apiKey] must start with `"proj_"`.
  /// [serverUrl] is the base URL of the analytics server (no trailing slash).
  /// [batch] can be `false` (default, send immediately), `true` (use default
  /// [BatchOptions]), or a [BatchOptions] instance.
  /// [timeout] is the HTTP request timeout (default 10 seconds).
  ///
  /// If already initialized, logs a warning and returns the existing instance.
  /// Any events tracked before this call are flushed automatically.
  static TGA init(
    String apiKey,
    String serverUrl, {
    Object? batch = false,
    Duration timeout = const Duration(seconds: 10),
    http.Client? client,
  }) {
    if (_instance != null) {
      _log.warning(
        'tgram-analytics: TGA.init() called but SDK is already initialized. '
        'Ignoring. Call TGA.close() first to re-initialize with new config.',
      );
      return _instance!;
    }
    _instance = TGA._(
      apiKey,
      serverUrl,
      batch: batch,
      timeout: timeout,
      client: client,
    );

    // Replay any identify calls that happened before init.
    for (final entry in _pendingIdentify.entries) {
      _instance!._identify(entry.key, entry.value);
    }
    _pendingIdentify.clear();

    // Flush pending events.
    if (_pending.isNotEmpty) {
      _log.info(
        'tgram-analytics: flushing ${_pending.length} event(s) '
        'buffered before init.',
      );
      for (final ev in _pending) {
        _instance!._dispatch(ev.endpoint, ev.payload);
      }
      _pending.clear();
    }

    return _instance!;
  }

  /// Track a custom event. Safe to call before [init] — events are buffered.
  ///
  /// This is a static convenience that delegates to the singleton instance if
  /// available, or buffers the event for later.
  ///
  /// Throws [ArgumentError] when [properties] contains an unsupported value
  /// shape (e.g. a nested [Map] or [List]). Validation runs even for
  /// pre-init buffered calls, so bad shapes surface immediately.
  static void track(
    String eventName,
    String sessionId, {
    EventProperties? properties,
  }) {
    if (properties != null) validateProperties(properties, 'track');
    if (_instance != null) {
      _instance!._track(eventName, sessionId, properties: properties);
    } else {
      _log.fine(
        'tgram-analytics: buffering track("$eventName") — init() not called yet.',
      );
      final merged = {
        ...?_pendingIdentify[sessionId],
        ...?properties,
      };
      final payload = TrackPayload(
        apiKey: '', // placeholder — replaced on flush
        eventName: eventName,
        sessionId: sessionId,
        properties: merged,
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );
      _pending.add(_PendingEvent('/api/v1/track', payload.toJson()));
    }
  }

  /// Track a pageview event. Safe to call before [init] — events are buffered.
  ///
  /// Throws [ArgumentError] when [properties] contains an unsupported value
  /// shape (e.g. a nested [Map] or [List]).
  static void pageview(
    String sessionId,
    String url, {
    String? referrer,
    EventProperties? properties,
  }) {
    if (properties != null) validateProperties(properties, 'pageview');
    if (_instance != null) {
      _instance!._pageview(sessionId, url,
          referrer: referrer, properties: properties);
    } else {
      _log.fine(
        'tgram-analytics: buffering pageview("$url") — init() not called yet.',
      );
      final merged = {
        ...?_pendingIdentify[sessionId],
        ...?properties,
      };
      final payload = PageviewPayload(
        apiKey: '', // placeholder — replaced on flush
        sessionId: sessionId,
        url: url,
        referrer: referrer,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        properties: merged,
      );
      _pending.add(_PendingEvent('/api/v1/pageview', payload.toJson()));
    }
  }

  /// Attach persistent properties to a session. Safe to call before [init].
  ///
  /// Throws [ArgumentError] when [properties] contains an unsupported value
  /// shape (e.g. a nested [Map] or [List]).
  static void identify(String sessionId, EventProperties properties) {
    validateProperties(properties, 'identify');
    if (_instance != null) {
      _instance!._identify(sessionId, properties);
    } else {
      final existing = _pendingIdentify[sessionId] ?? {};
      _pendingIdentify[sessionId] = {...existing, ...properties};
    }
  }

  /// Remove stored [identify] properties for [sessionId].
  static void forget(String sessionId) {
    if (_instance != null) {
      _instance!._forget(sessionId);
    } else {
      _pendingIdentify.remove(sessionId);
    }
  }

  /// Flush batched events. No-op if not initialized or batching is disabled.
  static Future<void> flush() async {
    if (_instance != null) {
      await _instance!._flush();
    }
  }

  /// Flush pending events, wait for in-flight sends, close the HTTP client,
  /// and clear the singleton so [init] can be called again.
  ///
  /// No-op if not initialized.
  static Future<void> close() async {
    if (_instance != null) {
      await _instance!._close();
    }
  }

  /// Reset the singleton and discard any buffered events.
  /// Intended for testing only.
  static void reset() {
    _instance = null;
    _pending.clear();
    _pendingIdentify.clear();
  }

  // ---- instance fields ----

  final String _apiKey;
  final String _serverUrl;
  final http.Client _client;
  final Duration _timeout;
  final Map<String, EventProperties> _sessionProperties = {};
  final Set<Future<void>> _inflight = {};
  EventQueue? _queue;

  TGA._(
    String apiKey,
    String serverUrl, {
    Object? batch = false,
    Duration timeout = const Duration(seconds: 10),
    http.Client? client,
  })  : _apiKey = apiKey,
        _serverUrl = serverUrl.replaceAll(RegExp(r'/+$'), ''),
        _timeout = timeout,
        _client = client ?? http.Client() {
    if (apiKey.isEmpty || !apiKey.startsWith('proj_')) {
      throw ArgumentError(
        "Invalid API key. Keys must start with 'proj_'. "
        'Get yours from the Telegram bot with /projects.',
      );
    }
    if (serverUrl.isEmpty) {
      throw ArgumentError('serverUrl is required.');
    }
    if (serverUrl.startsWith('http://')) {
      _log.warning(
        'tgram-analytics: serverUrl uses http:// — all data including '
        'your API key will be sent in cleartext. Use https:// in production.',
      );
    }

    if (batch == true) {
      _queue = EventQueue(_serverUrl, _client, const BatchOptions(), _timeout);
    } else if (batch is BatchOptions) {
      _queue = EventQueue(_serverUrl, _client, batch, _timeout);
    }
  }

  // ---- instance methods (called by static API) ----

  void _track(
    String eventName,
    String sessionId, {
    EventProperties? properties,
  }) {
    final merged = {
      ...?_sessionProperties[sessionId],
      ...?properties,
    };
    final payload = TrackPayload(
      apiKey: _apiKey,
      eventName: eventName,
      sessionId: sessionId,
      properties: merged,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
    _dispatch('/api/v1/track', payload.toJson());
  }

  void _pageview(
    String sessionId,
    String url, {
    String? referrer,
    EventProperties? properties,
  }) {
    final merged = {
      ...?_sessionProperties[sessionId],
      ...?properties,
    };
    final payload = PageviewPayload(
      apiKey: _apiKey,
      sessionId: sessionId,
      url: url,
      referrer: referrer,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      properties: merged,
    );
    _dispatch('/api/v1/pageview', payload.toJson());
  }

  void _identify(String sessionId, EventProperties properties) {
    final existing = _sessionProperties[sessionId] ?? {};
    _sessionProperties[sessionId] = {...existing, ...properties};
  }

  void _forget(String sessionId) {
    _sessionProperties.remove(sessionId);
  }

  Future<void> _flush() async {
    if (_queue != null) {
      await _queue!.flush();
    }
  }

  Future<void> _close() async {
    await _flush();
    if (_inflight.isNotEmpty) {
      await Future.wait(_inflight);
      _inflight.clear();
    }
    _client.close();
    _instance = null;
  }

  void _dispatch(String endpoint, Map<String, Object?> payload) {
    // Stamp the real API key on buffered events that had a placeholder.
    payload['api_key'] = _apiKey;

    if (_queue != null) {
      _queue!.push(endpoint, payload);
    } else {
      final future = transport.send(
        _client,
        '$_serverUrl$endpoint',
        payload,
        _timeout,
      );
      _inflight.add(future);
      future.whenComplete(() => _inflight.remove(future));
    }
  }
}
