/// Arbitrary key-value properties attached to events.
///
/// Values must be JSON-serializable scalars — [String], [int], [double],
/// [bool], or `null` — **or** a [List] of those scalars (e.g. for
/// multi-select onboarding answers or A/B variant memberships). Nested
/// objects, nested lists, and other types are rejected server-side with
/// `422`.
///
/// Every array property is sorted alphabetically/numerically by the
/// server at write time so `GROUP BY properties->'foo'` collapses
/// equivalent combinations into a single bucket — no naming convention
/// required. If insertion order matters for some property, serialize the
/// list to a string instead.
typedef EventProperties = Map<String, Object?>;

/// Configuration for the event batching queue.
class BatchOptions {
  /// Maximum number of events to buffer before auto-flushing.
  final int maxSize;

  /// Maximum time to wait before auto-flushing buffered events.
  final Duration maxWait;

  const BatchOptions({
    this.maxSize = 10,
    this.maxWait = const Duration(seconds: 5),
  });
}

/// Request body for `POST /api/v1/track`.
class TrackPayload {
  final String apiKey;
  final String eventName;
  final String sessionId;
  final Map<String, Object?> properties;
  final String timestamp;

  const TrackPayload({
    required this.apiKey,
    required this.eventName,
    required this.sessionId,
    required this.properties,
    required this.timestamp,
  });

  Map<String, Object?> toJson() => {
        'api_key': apiKey,
        'event_name': eventName,
        'session_id': sessionId,
        'properties': properties,
        'timestamp': timestamp,
      };
}

/// Request body for `POST /api/v1/pageview`.
class PageviewPayload {
  final String apiKey;
  final String sessionId;
  final String url;
  final String? referrer;
  final String timestamp;
  final Map<String, Object?> properties;

  const PageviewPayload({
    required this.apiKey,
    required this.sessionId,
    required this.url,
    required this.referrer,
    required this.timestamp,
    this.properties = const {},
  });

  Map<String, Object?> toJson() => {
        'api_key': apiKey,
        'session_id': sessionId,
        'url': url,
        'referrer': referrer,
        'timestamp': timestamp,
        'properties': properties,
      };
}
