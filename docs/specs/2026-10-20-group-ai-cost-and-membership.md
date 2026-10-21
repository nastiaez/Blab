# Group AI cost and membership epochs — topic7420 /14560

Status: implementation candidate prepared under14578; final live/database/Android validation is blocked. Not benchmarked against a funded live provider, merged or released. See `../qa/2026-10-20-group-recovery/completion-14578.md` for precise proof boundaries. Supersedes earlier proposed group prejoin-history isolation for original message text. No change to direct-chat history policy.

## Owner instruction

Use ordinary Stream original-message history. Group translations and author-only corrections are eligible only for messages sent during the viewer's current membership epoch, from server-confirmed join onward. After departure the group is absent from Chats and unreadable; a rejoin starts a fresh epoch. Earlier text is original only, including messages previously translated for this viewer. Do not backfill AI work at join or language setup. Original-history visibility and AI eligibility are independent.

Consequence: if ordinary history is retained, a returning person can read original messages sent during their absence. This supersedes the earlier birthday-secret preference for original text; disabling translation does not hide the original secret. Never present these two policies as equivalent.

## Verified Stream defaults and integration boundary

- Official Flutter membership docs: new members can see history by default; hideHistory/hideHistoryBefore are explicit restrictions. Adding/removing membership may include an optional system message; an invitation notice is not automatic.
- Source: https://getstream.io/chat/docs/flutter-dart/channel-members/
- Source: https://getstream.io/chat/docs/javascript/channel-members/
- `StreamBackedChatService` is gated by BLAB_STREAM_REVIEW and per-chat active transport. `stream-channel/index.ts` currently requires exactly two members. The local group candidate cannot be described as using Stream group defaults already.
- At the audit checkpoint, group SQL restricted originals by joined_at. Migration004 separates original-history visibility from AI eligibility; media/storage inherit that original-history change. Final validation remains explicit in the QA record.

## Original audit findings (implementation now addresses these; see QA status)

1. Initial set_learning_language in 20260907000002_invite_first_language_setup.sql enqueues the whole conversation without a membership-time predicate. Client 50-message pagination does not prevent this server workload.
2. 20261015000001_single_call_message_batches.sql claims all queued viewer jobs for a message together, but global capacity is four jobs; a group with more than four jobs can be skipped indefinitely.
3. single_call.ts explicitly rejects more than four viewers. compact_request.ts assumes a consistent sender and single recipient, rejecting differing group recipients. Raising the numeric limit alone is not a solution.
4. Existing compactPlan already deduplicates sentence variants by language/tone/context and word help by sentence/meaning language inside a request. Preserve that optimization; do not revert to one provider call per viewer.
5. Current commitViewers fans results into private viewer transactions, preserving independent completion. Keep that isolation.

## Recommended cost-minimizing plan

For each canonical message/source version:

1. Resolve active authorized membership epochs first. Historical or departed-viewer requests return original-only without jobs, provider calls or old-cache hydration. Apply this to list previews, timeline, search, quotes, notifications and both translation lanes.
2. Apply current no-aid/understood-language/protected-literal rules. AI work is zero when no output is required or valid cached output exists.
3. Build distinct output variants, not a viewer-sized prompt: sentence target language + tone + authorized context + relevant grammatical form/contract revision; word help additionally uses Primary Known Language. Interface Language only owns UI copy. Never deduplicate differing meanings, context access or personalized forms merely because target language matches.
4. Treat original-source interpretation once per message and preserve the required meaning/correction validation contract. Author corrections remain author-only. Group recipient wording must not pretend every message addresses a single partner.
5. Combine missing distinct variants in one bounded structured provider request where token/output limits permit. Split by measured token budget when necessary, not by member count. Share validated sentence artifacts across eligible viewers; bind results privately by epoch/preferences/revision. Never expose corrections or reuse inaccessible context.
6. Exactly one durable generation owner per artifact, with lease fencing across workers, previews and visible recovery. Cache hits and reconnects never create a second successful generation. Limit retries; failures for one variant do not regenerate successful variants.
7. Retain authorized shared artifacts when someone leaves; invalidate that person's bindings and device caches. Deleting shared artifacts would force other members to pay for regeneration. Rejoining cannot revive the prior epoch's translations, even from offline storage or stale worker completion.

Example: 100 eligible members with identical relevant preferences can share one generation of the needed variants, not 100 viewer generations. Three genuinely different language/output profiles require three output sets, potentially in one request. A 500-message backlog on joining requires zero new AI work. Request count alone is not cost: output tokens grow with genuinely distinct variants, so an arbitrarily multilingual group cannot be promised the same expense as two people.

## Implementation and proof sequence

1. Add immutable server membership epoch/AI-start boundary; atomic join/rejoin/leave, cancellation and stale completion rejection. Timestamp comparisons alone need a defined transaction ordering. Preserve direct-chat exceptions.
2. Remove initial group history enqueue; enforce eligibility in preparation, direct recovery, package reads and account-scoped local hydration. Align original-message/media access with the chosen Stream membership contract.
3. Replace all-viewer/four-job leasing with bounded artifact planning and group-safe context; retain existing two-person behavior.
4. Test provider-call counts with a deterministic recording provider: 2/5/30/100 members; identical/different/asymmetric preferences; author corrections; no-aid; missing optional help; reconnect; duplicate events; partial failure; edits; join/departure race; rejoin/cache replay; 500 originals at join. Assert zero backlog calls and no old translated text, not merely lack of new calls.
5. Benchmark actual input/output token costs and visible latency after the existing provider payment-required blocker is resolved; no synthetic provider response is live-cost evidence. Deliver actual browser/Android join → originals → new translation → leave → rejoin walkthrough for visual approval before merge/release.

The design is now implemented as a local candidate, with shared service-only artifacts, private viewer bindings, bounded continuation and bulk worker roundtrips.211 deterministic backend tests pass, including100-viewer sharing and zero-generation cache restart. That is not a funded-provider benchmark or whole-feature acceptance. No paid sweep or hosted migration was performed.
