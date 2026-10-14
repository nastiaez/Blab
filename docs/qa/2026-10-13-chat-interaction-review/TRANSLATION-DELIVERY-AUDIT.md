# Translation and notification-delivery audit — 14 October 2026

Investigation only. No translation/backend/notification architecture changes implemented or deployed. Main/tester v14 unchanged. Examined repository source; production environment overrides, worker configuration, provider timings and actual cache-hit rates not verified.

## Existing pipeline

1. Flutter saves an authored message through the existing authenticated message service. Original text and delivery are separate from translation readiness.
2. Postgres enqueues per-viewer preparation jobs for members with a selected Practice language. Keys include message, viewer, learning and primary-known language, language revision and source hash. Empty image captions skip preparation.
3. An insertion trigger dispatches the preparation worker; a once-per-minute recovery cron catches outstanding jobs. This recovery interval is not the normal dispatch delay. Worker dispatch requires configured server secrets/URL; presence in migrations does not prove production health.
4. `prepare-message-jobs` calls server Edge Function `translate-message`. Authenticated frontend cache misses can request the same translator with a message ID. Server derives content/languages and validates membership, quota, locks and version. Provider credentials never belong on the client.
5. Protected literals can bypass the model. Other messages get a candidate-blind source-meaning anchor, structured translation/correction output, independent meaning reviews and conditional repairs. Learning and known-language reviews can overlap. Two reviewers run in parallel, with a third only if consensus is missing. Retries and provider fallback extend the path.
6. Accepted outputs persist in message translations/prepared packages, including learning text, known-language text, word glosses/romanization and grammatical-form alternatives. Cache/version checks prevent reuse after relevant source/language changes.
7. Client loads cached originals first, refreshes the latest 50-message page and pages older history. The pending review candidate warms both display lanes and shows original text under shared shimmer on misses; cached mode switching does not require a new history request.

## Notification bottleneck

`send-push/contract.ts` sends FCM notification plus data `{type, chatId}`. Preview uses original text where enabled, not translation. Push and preparation are independent; neither waits for the other.

`main.dart` registers a best-effort background handler. `push_chat_prefetch.dart` fetches 50 originals, then prepared packages and saves authenticated account-scoped caches. However Android background notification+data delivery normally places the notification in the tray and supplies data to the app on tap; this does not guarantee the background caching handler executes before tap.

On tap, `PushTapRouter` awaits list refresh and `prepareChat`, with an eight-second timeout, before navigation. `prepareChat` awaits the messages provider and then a recent-message refresh. It does not explicitly await translation generation. Cold startup also initializes services/session before rendering. Cached content therefore does not eliminate all navigation delays.

## Conditions and prompts

- SQL: membership, known/learning languages, history eras, selected-language eligibility, source/version hashes, quota, jobs and cache reuse.
- Server `translate-message/contract.ts`: model prompt, JSON schema, source classification, literal safety, meaning protection, correction rules, forms, per-word glossary and script requirements.
- Server `translate-message/index.ts`: source anchor, validation/review/repair/retry orchestration. `provider.ts`: provider HTTP calls and 20-second per-call timeout, not an overall job latency bound.
- Client `message_presentation.dart`, lifecycle/state and preferences: which valid lane is displayed, Normal versus Practice, pending shimmer, reading scripts and private form choices. Interface locale must not silently become Normal's translation target.

Measured via executing prompt builders locally: auto-source → German / English explanation prompt without participant/context additions is **10,475 characters / 1,445 whitespace-delimited words**. Source-meaning anchor is **937 characters / 128 words**. Main strict JSON schema serializes to **2,044 characters**. These are not token counts. Names, language choices, up to eight prior context messages and retry guidance vary request size. There are additional review/repair prompts, not one small translator instruction.

Source defaults: gpt-4o-mini main generation via OpenRouter when configured, direct OpenAI fallback if configured; gpt-4.1-mini semantic reviews. Environment variables can override these; deployed models not verified. Main generation cap is 12,000 output tokens, a ceiling rather than proof of actual output length. Word metadata and alternative sentences can materially enlarge output.

## Recommendation for approval

1. Retain server-authoritative translation and eager preparation; measure production queue age, dispatch failures and preparation completion before redesigning it.
2. Navigate to an authorized cached chat immediately. Refresh chat list/originals/packages in the background; do not make a network refresh a prerequisite for seeing cached data. Uncached or unknown destinations retain authorization/not-found handling.
3. Persist original messages and both translation lanes in one account-scoped transactional local store. For growth beyond the current SharedPreferences JSON snapshots, use a paginated local database and explicit synchronization cursors. UI reads local data; network updates it.
4. Evaluate data-driven Android push plus supported background work to fetch originals and available translations before displaying the notification. Delivery is best effort under Android restrictions. Never delay notification indefinitely waiting for AI. Retain a bounded fallback notification and fetch on tap/resume; preserve preview/privacy settings and authenticated access.
5. Precompute on server receipt and push a readiness hint when appropriate. Fetch original plus prepared variants in fewer authenticated requests; avoid translating complete history or refetching it on every toggle.
6. Separate critical verified message-text readiness from optional word-help metadata readiness. Do not display unvalidated candidate text or remove semantic safeguards merely for latency. Benchmark any slimmer prompt/model against existing literal, language, form and correction regressions.
7. Measure notification tap → first cached message, original receipt → local persistence, queue time, provider stages, validated text ready and metadata ready, using p50/p95/p99, cache hits and errors. Do not claim instant AI or specify an unmeasured production SLA.

## Prompt caching

Yes: eligible OpenAI models support exact-prefix caching; OpenRouter documents automatic OpenAI caching from 1,024 prompt tokens and provider sticky routing. This reuses prompt computation, not generated translations, and cannot remove queue/network/output generation/validation work. Existing completed-result caches are the first priority because they avoid model calls entirely.

Current system prompt puts changing language/participant information before most reusable rules, then appends changing chat context. This reduces cross-request prefix reuse. No code was found recording `cached_tokens` or using explicit cache routing hints. Automatic provider caching may still occur; absence of client flags does not mean caching is off.

Propose immutable versioned rules/schema first, dynamic language/participant/context/source data afterwards, with an appropriate stable model/provider/cache grouping key. Preserve meaning with contract regressions. Log actual cached input tokens and realized latency/cost; do not assume a cache hit from prompt length. Short review prompts may not meet model thresholds. Provider retention/privacy constraints must remain intact.

## Primary references

- https://developer.android.com/topic/architecture/data-layer/offline-first
- https://firebase.google.com/docs/cloud-messaging/android/receive-messages
- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- https://openrouter.ai/docs/guides/best-practices/prompt-caching
- https://developers.openai.com/api/docs/guides/latency-optimization
- https://developers.openai.com/api/docs/guides/prompt-caching

Approval requested for the optimization direction before any backend/prompt/delivery-policy implementation; this audit is not that approval.
