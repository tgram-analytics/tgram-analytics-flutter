# tgram-analytics Flutter SDK

Lightweight Dart/Flutter SDK for [tgram-analytics](https://github.com/tgram-analytics). Track events and pageviews from your Flutter app or Dart backend.

- **Pre-init buffering** — call `TGA.track()` anywhere, even before `init()`. Events are queued and flushed automatically.
- **Never throws at runtime** — double `init()` logs a warning, pre-init calls are buffered, network errors are swallowed.
- **Fire-and-forget** — tracking methods are synchronous and return immediately.
- **Tiny** — only depends on `http` and `logging`.

---

## Prerequisites

1. A running tgram-analytics server. See the [server repo](https://github.com/tgram-analytics/server) for setup instructions.
2. A project API key. Create one by sending `/add myapp.com` to the Telegram bot. The bot replies with a key that starts with `proj_`.

Get a free `proj_` API key from [@MyTelegramAnalyticsBot](https://t.me/MyTelegramAnalyticsBot) on Telegram (1 project free), or [self-host the server](https://github.com/tgram-analytics/server) and create keys via your own bot.

---

## Install

```yaml
# pubspec.yaml
dependencies:
  tgram_analytics: ^0.1.0
```

```bash
dart pub get
```

---

## Quick start

```dart
import 'package:tgram_analytics/tgram_analytics.dart';

// Track events anywhere — even before init:
TGA.track('signup', 'session-123', properties: {'plan': 'pro'});

// Initialize once (e.g. in main):
TGA.init('proj_xxx', 'https://analytics.example.com');
// ^ buffered events are flushed automatically with the real API key

// Track more events:
TGA.track('purchase', 'session-123', properties: {'amount': 49});
TGA.pageview('session-123', '/dashboard');
```

---

## Batching

Buffer events and send them in batches to reduce HTTP requests:

```dart
TGA.init('proj_xxx', 'https://analytics.example.com',
  batch: BatchOptions(maxSize: 20, maxWait: Duration(seconds: 3)),
);

TGA.track('click', 'session-1');
TGA.track('scroll', 'session-1');
await TGA.flush(); // manual flush
```

The queue flushes automatically when `maxSize` is reached or `maxWait` elapses.

---

## Identifying users

Attach persistent properties to a session. All subsequent `track()` and `pageview()` calls for that session include them:

```dart
TGA.identify('session-123', {'plan': 'pro', 'locale': 'en-US'});
TGA.track('purchase', 'session-123', properties: {'amount': 49});
// sent properties: {plan: pro, locale: en-US, amount: 49}
```

Per-event properties override identified properties when keys conflict.

Call `TGA.forget('session-123')` to clear stored properties.

---

## API reference

### `TGA.init(apiKey, serverUrl, {batch, timeout, client})`

Initialize the singleton. `apiKey` must start with `"proj_"`.

- `batch` — `false` (default), `true` (default thresholds), or a `BatchOptions` instance.
- `timeout` — HTTP timeout (default 10 seconds).
- `client` — optional `http.Client` for testing or custom configuration.

If already initialized, logs a warning and returns the existing instance.

### `TGA.track(eventName, sessionId, {properties})`

Track a custom event. Safe to call before `init()` — events are buffered.

### `TGA.pageview(sessionId, url, {referrer, properties})`

Track a pageview event. Safe to call before `init()`.

### `TGA.identify(sessionId, properties)`

Store properties merged into all subsequent events for this session. Safe to call before `init()`.

### `TGA.forget(sessionId)`

Remove stored `identify()` properties for a session.

### `TGA.flush()`

Send all buffered events immediately. Returns `Future<void>`. No-op if not initialized or batching is disabled.

### `TGA.close()`

Flush pending events, wait for in-flight sends, close the HTTP client, and clear the singleton so `init()` can be called again. Returns `Future<void>`.

### `TGA.instance` / `TGA.I`

Access the singleton instance directly. Returns `null` before `init()`.

### `TGA.isInitialized`

Whether `init()` has been called.

### `TGA.reset()`

Clear the singleton and discard any buffered events. Intended for testing.

---

## Pre-init buffering

Unlike most analytics SDKs that throw or silently drop events before initialization, this SDK buffers them:

```dart
// App startup — tracking happens before init is called:
TGA.track('app_open', sessionId);
TGA.identify(sessionId, {'device': 'iPhone 15'});

// Later, when config is available:
TGA.init('proj_xxx', 'https://analytics.example.com');
// All buffered events are flushed with the correct API key.
// Timestamps reflect when the events actually occurred, not when they were flushed.
```

This is modeled after [Segment's analytics-flutter SDK](https://github.com/segmentio/analytics_flutter), which is the only major analytics SDK that implements Dart-level event buffering.

---

## Error handling

Analytics should never break your app. All HTTP and network errors are caught and logged via Dart's `logging` package under the `tgram_analytics` logger:

```dart
import 'package:logging/logging.dart';

Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((record) {
  print('${record.level.name}: ${record.loggerName}: ${record.message}');
});
```

Only the constructor raises exceptions (on invalid `apiKey` or missing `serverUrl`).

---

## License

MIT — see [LICENSE](./LICENSE).

---

## Links

- Website: <https://tgram-analytics.com>
- Server (API): <https://github.com/tgram-analytics/server>
- JS SDK: <https://github.com/tgram-analytics/tgram-analytics-js>
- Python SDK: <https://github.com/tgram-analytics/tgram-analytics-py>
- Flutter SDK: <https://github.com/tgram-analytics/tgram-analytics-flutter>
