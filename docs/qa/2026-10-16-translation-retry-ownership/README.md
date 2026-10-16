# Failed translation retry ownership — 16 October 2026

## Scope and state

Dedicated worktree/branch: `blab-nonempty-validator-20261016` / `fix/nonempty-validator-20261016`, building on `5a85121` (two-rule validator already deployed to test).

Backend guard deployed to **test only** (`tpfksdljkfnenjfdbane`): migration `20261016000001`, translate-message v8. Downloaded edge source and all four RPC definitions match the candidate (`deployment.json`). Main/production and mobile releases are unchanged. Production backend protection remains explicitly tracked in `progress.html`; do not imply existing production users are protected yet.

## Cause

The client checked pending work and the translation cache. A terminal failed job is neither pending nor cached. Reopening/recreating state therefore called the direct translation endpoint again. The endpoint reserved allowance and generated without checking exhausted queue work. Its generic transient error also triggered quiet retry. This is repeated translation generation, not duplicate delivery of chat messages.

Original SQL replay: three red assertions demonstrate both legacy and explicit-target requests admitted exhausted work (`ready`) and consumed allowance. Candidate: all pass. The incident trace count by itself cannot attribute every run to a specific phone-open event.

## Fix

- Durable private request ownership keyed by message, viewer, target, primary known language, source hash and historical learning-language revision.
- Admission is serialized before quota reservation. Active work returns pending, terminal failure returns failed; ordinary cache misses cannot reset them.
- Direct provider failures persist failed status. Crashed/incomplete requests become terminal after 45 seconds, never automatically restarted by opening the chat.
- Successful cached results remain readable even when a failure marker exists.
- Explicit Retry can admit one new request; simultaneous taps cannot duplicate active work. Existing account limits remain enforced; this is not a claim of complete abuse prevention against deliberate authenticated requests.
- Legacy RPC callers use the same backend guard, so enforcement does not depend on a client update.
- Client Retry sends explicit refresh with the visible target lane. Terminal responses do not quietly retry or retry on reconnect. One manual tap performs at most one direct invocation.
- Keep the existing failure footer (`Couldn't translate · Retry`); no UI redesign. A temporarily added duplicate inline button was rejected during screenshot review and removed.

## Preserved preferences and boundaries

Interface Language still owns UI copy. Primary Known Language owns explanations/Normal output; Learning Language owns Practice output. Authorization, historical era resolution, known-source Normal behavior, source edits and viewer isolation remain in the SQL admission path. Existing worker bounded retries and rate caps are unchanged. No real message, preference, usage counter or production cache was reset.

## Evidence

- `before-fix-sql.log`: 3 failing assertions on original local database function.
- `blab-retry-db.log`: 18 passing ownership cases: exhausted queue jobs; legacy callers; allowance; explicit retry; double tap; pending; persisted direct failure; expiration; viewer isolation; membership; table privileges; late cache; source edit; allowed languages; anonymous access.
- `blab-retry-pending-db.log`: 9 passing existing queue/readiness cases.
- `blab-retry-deno.log`: 192 backend tests passing; `deno check` of translate-message entry point passes.
- `flutter-final.log`: 128 Flutter tests passing across translator, state, message content and full chat widgets.
- `native-journey.log`: Android emulator real ChatScreen widgets, terminal failure -> dispose/reopen -> reconnect reconciliation -> explicit footer Retry -> translated text. Synthetic service responses, not live-provider quality or physical-phone evidence.
- Screenshots 01 failure, 02 reopened without retry, 03 explicit Retry success. The fixture's no-connection banner is from synthetic transport; it is not a hosted-service outage.

No existing failed job is present in the test backend for a hosted incident replay. Therefore failure admission is proven with actual local Postgres functions and deployment source verification, not a claimed live failed-user repair. No synthetic messages inserted into hosted chats.

## Remaining acceptance

Owner review of native journey before main merge and client release, per standing delivery instructions. Android/iOS binary updates not published. iOS native and physical-device verification not performed. Production backend rollout is separate and remains pending.

## Review delivery

Inspected final native PNGs; sent reopened failure and explicit-retry success to the active Blab topic (Telegram receipts 13327 and 13328). Existing footer only; no new UI. Screenshot approval is pending. Candidate changes remain in the dedicated worktree; no main merge/client release.

Owner13332 approved screenshot journey. Owner13370 subsequently authorized fixing
local test services and launching the combined Google sign-in changes. Source
integration is proceeding with the backend storage/partial-viewer fixes.
