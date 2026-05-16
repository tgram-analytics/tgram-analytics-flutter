## 0.2.0

- **Multi-value event properties.** `EventProperties` now officially supports `List` values containing scalars (`String`, `int`, `double`, `bool`, `null`) — useful for multi-select onboarding answers, A/B variant memberships, and any set-style attribute that previously needed lossy workarounds:

  ```dart
  TGA.track('onboarding_completed', 'session-123', properties: {
    'role': 'creator',
    'interest_set': ['vertical_to_horizontal', 'unsure'],
  });
  ```

  Lists whose key ends in `_set` are sorted alphabetically by the server at write time so `GROUP BY properties->'interest_set'` collapses equivalent combinations into one bucket. Other list properties keep insertion order.

- **Runtime validation** on `TGA.track()`, `TGA.pageview()`, and `TGA.identify()`. Nested `Map`s / `List`s, `double.nan`, `double.infinity`, and other non-scalar values throw `ArgumentError` synchronously with a message that names the bad key. Validation also runs for pre-init buffered calls.
- The `EventProperties` typedef body is unchanged (`Map<String, Object?>`), so the release is **non-breaking** for existing callers.

## 0.1.2

- Docs: simplified install instructions to use `flutter pub add tgram_analytics` / `dart pub add tgram_analytics`.

## 0.1.1

- Docs: README mentions the managed hosted service (tgram-analytics.com) and the Telegram bot (@MyTelegramAnalyticsBot) alongside the self-hosted option.

## 0.1.0

- Initial release.
- `TGA` client with `track()`, `pageview()`, `identify()`, `forget()`, `flush()`, `close()`.
- Optional event batching via `BatchOptions`.
- Fire-and-forget error handling (errors logged, never thrown).
