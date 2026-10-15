# One-call preparation and reliable open chat — candidate

Owner authorization: Telegram12887/12895, 15 October 2026. Base origin/main8df0e84; dedicated branch fix/single-call-reliable-chat-20261015. Incorporates earlier missing-message and shimmer safeguards. Not merged, hosted/deployed, or released. Owner review pending.

## Implementation

- One normal AI request per message/source for all prepared viewers, compact canonical rulebook, message once, bounded context (3 entries/1800 UTF-8 bytes per viewer), separate learning/known-language settings and participant ownership.
- One structured output includes sentence, secondary text, correction, forms and word metadata. No independent meaning/source/form audit calls, no separate word-help generation, no speculative hedge in the active path. Local literal messages need zero AI calls.
- Atomic group claiming prevents workers splitting the two viewer jobs; leases fence stale workers. Both ready results commit in one transaction. Existing prepare/complete RPCs still own authorization, source/revision/history and preference checks.
- Durable retry only for actual failed attempts, maximum4; honor Retry-After. Invalid provider output may therefore exceed one call across failed attempts. Normal successful messages use one, not one per viewer. Legacy/direct manual translation requests remain single-viewer one-call requests.
- Independent active-chat safety catch-up every10 seconds, preview-trigger catch-up, stream reconnect,6-second bounded reads. Existing timeline is merged without discarding older pages. Start shimmer watchdog before first cache fetch and bound scroll deferral750ms. No extra generation is performed by read-only catch-up.
- Form token fragments are expanded from returned metadata only; masculine canonical output is normalized using its complete feminine alternative; common token prefix/suffix shrinks over-expanded choice fragments. These are deterministic, not extra AI calls.

## Verification

- Full Flutter:913 passed,15 skipped; static analysis clean. Backend165 passed. SQL lease-group regression passed against isolated clean local DB (limit1 claims both viewers, concurrent second claim gets0, expired lease rejects old completion).
- Isolated database/actual-provider worker check: one request,2 ready viewer jobs at attempt1, independent German/Ukrainian outputs. Readable publication omits top-level tokens as required by its existing RPC contract.
-9 live synthetic message cases /18 viewer outputs (live-cases.json), one request each,1.5–5.6 seconds. Includes okay, reported sentence, broken German, ambiguity/context, false friend/negation/time, Ukrainian/Hindi forms, asymmetric known languages, and both viewers assigning Bob as recipient of a question. Not a comprehensive11-language accuracy certification.
- Earlier iterations exposed wrong secondary language, incomplete form tokens and sender/recipient ownership. Fixed before final acceptance; no claim that initial8-case completion proved semantic correctness. Final ownership assertion is tested explicitly. The final deterministic common-fragment trimming was added after live capture and regression-tested against the captured structured output; no prompt change or client change followed Android capture.

## Android walkthrough

Local backend only, Supabase transport (Stream disabled); emulator5556 AliceLocal learningUkrainian and5558 BobLocal learningGerman; knownEnglish. Both installed from the same debug APK without uninstalling. Local auth/onboarding restored before the journey.

1. Keep both conversations open. Alice sends the reported sentence; Bob receives the German result and Alice sees Ukrainian. Bob replies about six; Alice receives it without navigation. alice-two-way.mp4 / bob-two-way.mp4.
2. Disable LOCAL realtime publication of messages, message_translations and message_readable_variants. Bob sends blue-book sentence; both resolve through recovery. missed-update-5556/5558.png.
3. With those same3 feeds disabled again, Alice sends red-book sentence, Bob sends Sounds good. Both conversations display both messages and finished text without Back/restart. final-5556.png / final-5558.png and forced-recovery.mp4. Publication restored in finally in both fault-injection runs.
4. Final runtime logs show exactly2 provider requests for the2 step3 messages; both groups complete with2 viewers, provider timings2208ms/1725ms, totals3803/3509 tokens. See android-provider.log. The10-second polling recovery can add delay when live events are missing; it does not make outage delivery instantaneous.

All delivered screenshots and sample video frames inspected. Exact phone-side trigger in the original incident was not logged and remains unproven; matching missing-stream/hung-cache/scroll-deferral failures are reproduced and covered.

## Review and release gate

No production writes or Firebase distribution. Main remains unchanged. Owner reviews the screenshots/recording before merge; then verify integrated Android revision and release exact signed artifact through existing Firebase tester channel. The debug APK is evidence only, not a tester release.

Debug APK SHA256: 6c75d8b29cb8456f384687b25203e121165837bbf8039149519187415d22c7c1

Review evidence delivered in the same development topic: Telegram12900,12901,12902. Owner approval pending.

## Release authorization
Ash approved merge and release in Telegram12904 (15 October2026). Integrate this reviewed candidate, verify signed Android update, deploy matching worker/migration and distribute to existing testers.
