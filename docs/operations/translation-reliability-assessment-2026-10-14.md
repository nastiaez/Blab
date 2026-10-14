# Blab translation reliability: production assessment

14 October 2026. Research and design, not an implemented/released guarantee.
Scope: owner-reported v16 translation failures and missing Practice word popups.
Current source: main ea88ea9; implementation worktree fix/translation-recovery-word-taps-20261014.

## Decision

Keep message delivery independent of translation. Keep context-aware AI as the primary translator. Make recovery deadline-driven, durable and failure-specific; do not add more identical nested retries. Fix the classification and tap bugs before measuring architecture changes.

No networked service can guarantee every translation is correct and arrives within ten seconds, especially offline or during correlated outages. We can guarantee local behavior: preserve the original, never block sending on AI, never display a guessed translation as successful, and never leave an endless shimmer. Translation availability and latency need measured service objectives, not an absolute promise.

## Evidence: what is actually wrong

1. **Deterministic validation failure.** A 13-character German message exhausted four server attempts for each viewer. Its stored production reason is only `translation_unavailable`. Local replay reproduced `source_evidence_conflict` and `untranslated` with successful HTTP responses. The source-language guard treats the sender's English primary-known language plus Latin script as evidence against correct German. Repeating that logic cannot recover. Production provider logs were inaccessible; this is a local reproduction supporting, not proving, every internal production attempt's cause.
2. **Conflicting deadlines.** `provider.ts` allows 20 seconds for each AI call. The screen transitions to an error after ten seconds even when server work is pending. Multiple generation, source-meaning, semantic, grammatical and metadata calls can add further waits. There is no single short end-to-end budget shared by these phases.
3. **Slow retry wakeups.** Server jobs allow four attempts, with 10/20/40-second retry delays. Production cron was read back as once per minute; insertion wakes work immediately but an updated retry does not get an equivalent scheduled wakeup. A due retry can therefore wait for the next tick or unrelated traffic.
4. **Shared capacity.** The production claim function permits four processing jobs globally. The readable sentence is published early, but its worker stays occupied until word help finishes. Metadata can delay subsequent fresh messages. Four jobs are not four provider requests: reviews can fan out inside each job. This is a capacity risk, not proof that saturation caused the reported German failure.
5. **Infrastructure interruptions.** Read-only inspection found dispatch timeouts at five seconds and one Supabase service-degraded 503. A dispatch timeout does not prove its worker stopped; jobs can still complete. Crashed jobs currently have a five-minute lease-recovery threshold, another possible long-tail delay.
6. **Word-tap bug.** Practice text with `mode=none` and unchanged authored wording renders as plain text rather than interactive words. Recent successful production messages had word metadata; an actual Android translated-word popup worked. Metadata absence is not the established cause of this particular rendering defect.
7. **Observability gap.** The worker retains the generic `error` before the more useful `reason`, obscuring model/schema/semantic failures. Existing provider metrics record token counts and duration, but job-stage correlation is needed.

There is no established HTTP429 or prompt-overflow explanation for the reproduced failure. A short input does not mean a short prompt: instructions and audits still contribute tokens. Measure that separately rather than assuming it caused this incident.

## Current and recommended flow

Current existing-chat flow:

`send original → Supabase message + durable jobs → worker → generation and independent source anchor → meaning/correction/form checks → readable result → word help → completed job → app updates`

Existing chats are not yet cut over to Stream. A Stream transport change alone cannot repair these translation failures.

Recommended ownership:

- Messaging transport owns sending, receiving, order and receipts; no AI in a synchronous before-send hook.
- One translation coordinator owns scheduling, attempt budgets, deadlines and result selection.
- Durable jobs are keyed by message revision, target and known languages, context/policy revision and applicable form settings. Share results only where visibility and semantics are identical. No cross-chat private-text cache.
- Separate sentence readiness from word-help readiness as actual queue phases, not merely an early database write. Release the sentence capacity before starting metadata. Reserve capacity for new sentences; metadata gets bounded capacity and tap priority without starving indefinitely.
- Treat Realtime as a notification, not durable storage. Reconcile authoritative state on reconnect/reopen and bounded polling. Edits/deletes must invalidate in-flight writes; late losers cannot overwrite the selected result.

## Proposed timing policy

These are initial engineering budgets to benchmark, not measured promises or fixed model SLAs.

| Time from send | Expected behavior |
|---|---|
| Immediately | Local original is readable; send proceeds independently. Normal stays dark and stable. |
| Typical first 2–3 seconds | Primary context-aware translation and required validation finish; Practice swaps to one complete sentence. No typewriter animation. |
| About 2.5 seconds without an accepted result | Start at most one approved alternate candidate path if spare capacity and retry budget exist; immediate eligible failure can trigger it sooner. |
| By an 8-second foreground budget | Publish an accepted result or enter a quiet delayed state with readable original. End shimmer; do not label pending work a terminal failure. |
| After the foreground budget | Durable bounded recovery continues, including after navigation/reconnect. Exhausted/nonretryable work becomes an honest final Retry state, not permanent “Translating”. |

Use one absolute deadline for queue wait, network, generation, validation and commit. Individual calls get the remaining budget; they do not each start a fresh 20-second clock. An eight-second UI transition is controllable; a successful translation by eight seconds is not universally controllable.

Hedging a slow request can improve tail latency but consumes extra capacity and potentially money. Permit one hedge, cancel/ignore losers, cap aggregate requests, and disable speculative duplication during overload. Do not launch three copies on every send. Preserve the existing initial-plus-three durable recovery allowance, but account for all internal candidate/review calls in an explicit total budget rather than multiplying unbounded layers.

## Fallbacks must address different failures

| Failure | Response |
|---|---|
| Wrong source label / copied output / invalid meaning | Correct classification using the actual utterance and bounded context; use independent evidence, not the profile language as a hard override. Retry with a targeted repair or a different qualified model. Never weaken meaning checks just to return something. |
| Slow endpoint / transient5xx / network interruption | Early bounded alternate route, with health-aware suppression of repeatedly failing endpoints. Maintain a tested recovery probe. |
| HTTP429 | Honor Retry-After, limit concurrency and use jitter. Use a separately qualified route only if its capacity is genuinely independent. |
| Credit/auth/configuration failure | Operator alert and a separately funded/configured route where available; repeated requests to the same exhausted account are not recovery. |
| Invalid/overlong request | Validate/simplify the request; do not blindly retry identical input. Bound context while preserving explicit replies, negation, referents and names. |
| Word-help failure | Preserve the accepted sentence; retry only metadata. Tapping still opens the word immediately, with honest loading/unavailable help rather than an absent interaction or fabricated gloss. |
| Worker death / missed delivery | Durable lease and heartbeat recovery, revision-safe writes and app reconciliation. |

OpenRouter already has latency sorting, provider fallback, required-parameter filtering and ZDR enabled in this source. Those switches are not the missing fix. Router fallback handles upstream failures, not an HTTP200 answer that Blab rejects semantically. App-level quality fallback and an absolute deadline are still required. Provider latency preferences are preferences, not guarantees. [OpenRouter routing](https://openrouter.ai/docs/guides/routing/provider-selection), [model fallback](https://openrouter.ai/docs/guides/routing/model-fallbacks).

An alternate model on OpenRouter can escape a model failure but not an OpenRouter account or gateway outage. Full outage independence requires a separately configured vendor route. Do not call an unused credential path “working fallback”; prove it under fault injection. All routes must meet the same privacy and language-quality requirements. No new vendor activation or paid provisioning is part of this assessment.

## Queue and prompt improvements

Keep the existing durable Postgres job foundation; avoid a platform migration solely to solve this incident. Use prompt due-job dispatch on a seconds-scale scheduler or continuously consuming worker, with cron retained as a safety sweep. Size renewable leases to measured work and protect final writes with claim/revision fencing. A short lease without a heartbeat could create duplicate work. Supabase Queues is an available managed Postgres alternative, but queue delivery guarantees do not imply exactly-once external AI calls or timely execution without a consumer. [Supabase Queues](https://supabase.com/docs/guides/queues).

Respond promptly to dispatch after durably accepting/claiming work; explicitly manage the continuation. `waitUntil` helps Edge background execution, but is still runtime-limited and not a replacement for durable recovery. A permanently warm consumer is the stronger option if measured load/latency needs it; choose after benchmarking, not by assumption. [Background execution](https://supabase.com/docs/guides/functions/background-tasks).

Keep two recent context messages plus explicit reply context, bounded by tokens, and keep stable instructions separate from dynamic data. The current readable phase still carries instructions for fields omitted from its response schema; produce phase-specific prompts instead of appending contradictory instructions. Generate the smallest necessary result, reuse accepted source-meaning work safely within the same revision, and repair only the failed phase. Prompt caching may help but cannot be relied on for every tiny chat input. Retain current meaning/form safeguards initially; any reduction in reviews needs a separate quality evaluation.

Use a single retry owner, jitter and a global retry budget. This avoids the amplification described in [AWS's retry guidance](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/). Do not increase concurrency blindly: measure provider request/token limits and per-stage fanout. Supabase's documented nested-call budget is30 per trace per60seconds, not a blanket30requests/minute project cap; it is not the established incident cause. [Nested calls](https://supabase.com/docs/guides/functions/recursive-functions).

## Stream native translation and specialist translation APIs

**Do not replace Blab's translator with Stream native translation now.** Stream supports automatic/on-demand message text translation and updates existing messages. Its documented interface does not establish configurable conversation-context handling, Blab correction/form choices, or word definitions. Its source-language preference is also awkward for learners who deliberately switch languages. It is a possible benchmark/fallback candidate, not an equivalent learning pipeline. [Stream Flutter translation](https://getstream.io/chat/docs/flutter-dart/translation/).

A specialist translation API is worth benchmarking as a secondary basic-sentence path, including all11languages. It is not automatically more accurate for fragments or grammatical choices. Google offers text translation and adaptive example-based translation; examples are not the same thing as a conversation memory contract. Do not concatenate history into text and then guess which output belongs to the current message. Keep any fallback qualified against the same context tests. [Google text translation](https://docs.cloud.google.com/translate/docs/translate-text), [adaptive translation](https://docs.cloud.google.com/translate/docs/advanced/adaptive-translation).

## Acceptance before calling this production-ready

Proposed objectives for eligible short messages on a connected device under the declared supported load: p95 readable within3seconds, p99 within8seconds; initial translation availability target99.9% within30seconds. These are desired objectives, not existing results. Count delays, exhausted work and incorrect translations separately; never remove failures from the latency denominator. Report word-help and tap responsiveness separately. The prior44-viewer sweep is not enough evidence for a99.9% production claim.

- All11languages, both directions; spontaneous source-language changes, same-language writing, fragments, names, negation, code-switching, emoji, corrections, form choices and long inputs.
- Actual Android two-client conversations: outgoing/incoming word popups, each word, both modes, metadata arriving late, cache/reopen, edit/delete and reconnect.
- Inject slow primary, malformed output, source misclassification, semantic rejection,429withRetry-After,5xx, zero-credit/auth failures, both providers down, worker termination, stale leases and dropped Realtime events.
- Load test fresh sends while metadata/history work is backlogged. Prove fairness, bounded provider fanout, no duplicate published outcomes and no lost jobs.
- Record queue wait, generation, validation, metadata, commit and device-visible time by request/revision/language, plus bounded error codes, attempts and token counts. Do not log private message text or credentials. Alert on queue age, failure/hedge rates and exhausted balance.
- Canary the approved slice, compare with baseline and retain rollback. Actual screens/motion need owner review before merge and signed Firebase delivery.

Implementation sequence: fix deterministic classification and taps → honest pending/terminal states and precise reasons → bounded deadline/fallback and prompt scheduler → isolate metadata capacity → fault/load tests and Android review. Runtime files remain unchanged at this assessment handoff.
