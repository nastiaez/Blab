# Request amplification and unresolved shimmer investigation

Owner reported 20+ OpenRouter requests for one message, then clarified bubble kept shimmering until Back/reopen (Telegram12865 and follow-ups).

## Exact live evidence

Scoped message `bb69ffd5-9024-4ecf-b3b4-2812d7c4b86b`: “Hii nastia when are you coming back”, created 10:50:24.866597 UTC. Both viewers selected German learning / English primary known, revision 1. Readable rows for both viewers persisted at 10:50:31.204711 and 10:50:31.213116 (~6.34 seconds). Both viewer preparation jobs ready, attempts=1, no last_error. Thus durable completion is proven; phone rendering is separately reported stale. No phone telemetry proves the precise triggering event.

## Actual request count

LangSmith window 10:50:26.147–10:50:31.240 UTC: **22 root OpenRouter requests** and 22 provider-attempt child spans. Child spans are not 22 additional requests.

- 3 sentence generations (two initial viewer pipelines plus one hedge using gemini-2.5-flash).
- 3 candidate-blind source-meaning calls.
- 12 semantic audits: two independent votes × two language lanes × three candidate pipelines. Every observed audit accepted meaning/language; no third-vote disagreement or semantic rejection triggered these calls.
- 2 grammatical-form audits, both requireChoice=false.
- 2 word-help requests.
- 22,684 total reported root tokens; total cost $0.0093572. Provider children report zero tokens and are not double-counted.

Source: independentConsensus always starts two calls. Each cross-language candidate can audit both learning and rewritten known-language lanes. firstAccepted starts its hedge after 2.5 seconds while the first candidate's entire generation+validation pipeline has not yet settled, even if generation itself completed. Initial generations finished around 10:50:27.5; fallback started 10:50:28.638. Work is duplicated across independent viewer jobs even when chosen languages match. Different viewer/author/form context must still not be merged blindly.

## Reproduced client gaps and bounded candidate fix

1. ensure() entered loading then awaited the first cache fetch before arming the watchdog. A hung initial cache read prevented its own recovery timer from starting. Candidate arms read-only recovery as soon as loading starts. Regression holds first fetch forever, then makes saved text available to watchdog; no AI call occurs.
2. Ready text arriving during a finger scroll was held until a later ScrollEnd notification. Missing that event held a finished sentence in the wave phase forever; reopening initializes it as settled. Candidate preserves short scroll deferral but caps it at 750ms. Regression leaves deferResolve=true after resolving and verifies ready content becomes visible.

Both regressions fail on integrated main and pass with the candidate; focused suites 57 pass; full Flutter suite 908 pass / 15 skipped; static analysis clean. Existing normal scroll-release and reduced-motion cases remain covered. These are matching reproducible failure modes, not proof which happened on the owner's phone.

No backend call-reduction policy changed in this slice. Recommendations: share immutable source analysis only where source/context match; avoid restarting generation merely because validation is still running; combine redundant target/known-language semantic checks or escalate a second review conditionally, with adversarial multilingual tests before changing acceptance safety. Keep optional word help off the readable-text critical path. Add message/job/phase trace correlation so viewer pipelines can be grouped reliably.

## Release boundary

Candidate only. Not merged, deployed or released. Actual Android screenshot/recording of fault-injected recovery and owner review remain required before UI integration/release. Missing-message-bubble recovery is a separate earlier candidate; this report concerns a visible stale shimmer.
