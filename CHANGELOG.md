## 0.1.1

- Docs: README mentions the managed hosted service (tgram-analytics.com) and the Telegram bot (@MyTelegramAnalyticsBot) alongside the self-hosted option.

## 0.1.0

- Initial release.
- `TGA` client with `track()`, `pageview()`, `identify()`, `forget()`, `flush()`, `close()`.
- Optional event batching via `BatchOptions`.
- Fire-and-forget error handling (errors logged, never thrown).
