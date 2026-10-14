# Seamless translation — 14 October 2026

Status: **in progress / not released / not accepted**. Worktree `fix/seamless-translation-20261014`, based on current main cf2cfa214e966bc0eec8f25278a969ff3ad017af. Exact patch and debug APK hashes: candidate.json. No production settings/functions changed. Existing-chat Stream cutover remains off.

## Root causes and implemented corrections

1. Hosted server text-first setting was absent, although v15 client enabled it. Server and client now default to readable-first; explicit false remains a rollback.
2. Four globally leased jobs ran serially. They now run concurrently within the existing database-wide four-job bound; independent failures cannot block siblings.
3. Chat-list initial loads and every refresh started uncoordinated batches of up to 50 recent messages per chat (three concurrent calls per batch), including when a translation completion itself refreshed the list. Removed client-side batch generation. Durable server jobs own preparation; chat lists consume updates, and visible historical cache misses retain their bounded recovery path. Regression reproduced six provider calls for six list loads; corrected path makes zero.
4. Normal mode inherited muted pending color and the translation lifecycle. It now displays full-contrast originals immediately, retaining the existing unknown-language translation exception.
5. Practice cleared, resized invisibly, and revealed glyphs. It now swaps the entire verified sentence without an empty intermediate frame. Shimmer remains Practice-only; settled cached text does not replay it. Scroll deferral/reduced motion remain.
6. A pending server job renewed the visible timeout indefinitely. After the existing ten-second deadline, preserve readable original/error recovery instead of endless shimmer; read-only cache recovery and Realtime accept late text without duplicate AI. The regression includes late-result recovery.
7. Literal-character protection misclassified the J in French J’apporterai / J'apporterai as an opaque initial. Corrected elision boundary; quoted initials and the O→ears protection still pass.
8. Short requests reserved 12,000 completion tokens. Output-specific adaptive allowances retain long-message capacity but reduce short-message reservations. Context and semantic/grammar checks are unchanged.
9. Chat routes no longer inherit the delayed fade; they use immediate replacement. Other routes are unchanged.

## Architecture decision

Keep Stream for canonical messaging where activated, and the existing Supabase transport for unmigrated chats. Supabase owns private per-viewer preparation state and private media. Send originals independently of AI; generate context-aware readable text first, publish the verified sentence, then enrich word help. UI subscribes rather than generating duplicate batches. Stream automatic translation is not a drop-in replacement for Blab's context, corrections, form alternatives and word-help contract. Official reference: https://getstream.io/chat/docs/unity/translation/ .

Local evaluation uses google/gemini-3.1-flash-lite for generation and semantic review under the unchanged required-parameters/no-training/ZDR routing policy. Four isolated generation probes were valid at 1.05–2.07 seconds, versus 2.18–2.68 seconds for gpt-4o-mini. This is NOT end-to-end timing or a complete quality benchmark. Model defaults are NOT changed/promoted; broader validation remains required. Gemini3.5 Flash Lite lacked eligible endpoints under the required policy; do not weaken privacy to use it.

## Live evidence and honest limits

- Alice browser (`localhost:7357`) and Bob Android (`emulator-5558`) signed into synthetic local accounts against owned backend54441. Actual Stream-backed shared chat71000000-0000-4000-8000-000000000001.
- Actual Alice send: “Can you bring the blue book tomorrow?” → German “Kannst du morgen das blaue Buch mitbringen?” readable row4.176s after canonical insert.
- Actual Bob reply: “Yes, I will bring it tomorrow.” → Alice German “Ja, ich bringe es morgen mit.” (context retains book reference), Bob Ukrainian “Так, я принесу її завтра.” Readable rows8.610s/8.860s. Normal original remains clear while preparation runs.
- Actual Bob send: “See you at six.” → Alice German “Wir sehen uns um sechs.” readable row5.236s. Bob Ukrainian did not complete in the observed run. Do not call this all-viewer success.
- Planned legacy matrix:22 directional sends /44 viewer outcomes across nl,en,fr,de,hi,it,pt,es,ta,tr,uk. Latest interrupted run recorded7 sends /14 viewer outcomes;13 complete, one absent by65s, one otherwise-complete viewer took40.424s. Only5/7 recorded cases completed for both viewers within10s. Remaining15 cases untested on this candidate. Earlier trials are not substitutes.
- Test provider balance was about USD0.0615. Actual402 response reason:in_flight_budget_exhausted with Retry-After120s. This is a test-account limitation; the local key did not match the hosted secret digest, so it is NOT proof that production has the same balance issue. No top-up/payment made. Owner asked to replenish the test account; live matrix paused.
- Captured retry states are genuine failures, not mocked results. No result was replaced with a hand-authored translation. No quotas were raised or reset. Only interrupted local synthetic preparation leases were released after owned function-runtime restarts; production jobs untouched.
- Model/language sweep ran before final removal of chat-list duplicate work. Repeat with the final Android/browser revision and funded provider. No claim of universal1–2s translation.

## Verification

- 183 backend checks passed; literal-elision, output-budget, readable-default and parallel-worker regressions included.
- 43 translation-state checks passed, including bounded pending wait and late-result recovery.
- 9 chat-list checks passed, including zero provider calls on repeated list refreshes.
- 33 full-chat UI checks passed, including incoming/outgoing Normal full contrast. Earlier lifecycle/full-chat combined43 checks passed.
- Full Flutter run before final list-loop removal:893 passed,15 explicitly skipped environment integration tests. Final full run retained separately when complete.
- Analysis passed before final list-loop removal; final analysis retained separately.
- No SQL migration changes. No clean-database reset or production cutover needed for this slice. Database integration suites were not rerun for these Dart/Edge changes; previous v15 evidence is not re-labelled current.

## Remaining acceptance work

Funded repeat of all11 languages, context/negation/names/abbreviations/form cases, bursts and slow/recovery paths through both clients; accurate send-to-visible timing; final no-duplicate-loop live observation; motion/screenshot review by owner. Only after owner visual/workflow approval: integrate main, verify that integrated Android revision, release its signed artifact to existing Firebase testers. Physical phone remains unverified.

## Final candidate evidence packet

- Final full Flutter run: **894 passed,15 skipped**, no failures. Final analysis: no issues. All183 backend checks pass. Android final candidate installed in place on emulator5558; no production release or physical-phone claim.
- 01-normal-android.png: latest Android candidate, exact authored incoming/outgoing text, full contrast and no translation shimmer.
- 02-practice-german-browser.png: actual live German translations for both send directions. Captured before removal of list fan-out; same rendering changes, not proof of final no-loop timing.
- 03-practice-failures-android.png: latest candidate preserves original and exposes genuine untranslated cases instead of endless shimmer. Not a happy-path pass.
- 04-chat-entry-android.mp4: actual latest Android cold/warm entry and return without the previous-screen fade. First entry still loads data; no fabricated instant-data claim. Settled translated text paints as a complete sentence.
- normal-send-final.mp4: actual Normal send remains readable while translation is pending, captured before final background ownership/deadline refinements (identical Normal rendering).

Do not treat this packet as permission to merge. Funded final all-language/timing validation and owner acceptance remain outstanding.

Delivery receipts: Telegram topic7420 messages12558 (three screenshots),12559 (latest Android entry recording),12560 (actual Normal send recording). Test clients stopped after captures to avoid background requests; local queue has92ready/4failed and no queued/processing jobs. Final format351files unchanged and whitespace checks pass. Funding request remains unanswered; no payment or production mutation.


## Funded final acceptance — 14 October, 21:05 Berlin (supersedes funding blocks above)

Owner restored funding and deferred cost work. Exact candidate defaults: Gemini 3.1 Flash Lite generation plus independent Gemini 2.5 Flash source-anchor/semantic/form review. Local runtime has no model override. Privacy, structured-output, candidate-blind anchoring and consensus checks remain enabled. Production unchanged.

Final exact-source live matrix: 22 API-driven sends across all 11 languages, 44/44 readable viewer results and 44/44 complete word-help packages, no missing/error results. Some known-language viewer results are intentionally unchanged originals, not translations. Median readable 2.874s, p95 order statistic 4.250s, maximum 6.256s; maximum complete package 7.282s. Message acknowledgement maximum 33ms on local backend, not a production-network promise. See matrix-acceptance.json. These are backend publication measurements, not 44 individually filmed screen observations.

Separate real Stream-backed browser/Android conversation: Pallavi + blue-not-red notebook appeared at 3.007s German / 6.756s Ukrainian; follow-up “She needs it for tomorrow’s meeting.” at 2.955s / 2.918s; native reply “I will ask her tomorrow.” at 5.563s / 5.158s. The 25-second unaccelerated native recording shows incoming shimmer, complete-sentence replacement, composition/send, then complete outgoing translation. Previously failed 20:53 “The red one?” remains visible in history; its corrected 20:57 repeat is successful. No history or screenshot was doctored to remove this failure. Context repeat “Bring the small book.” / “The red one?” resolves feminine Ukrainian book agreement correctly. Earlier cold-runtime restart caused a 29–30s dispatch recovery; that run is not relabelled steady-state acceptance. Universal 1–2s is NOT established.

New regressions: intact Tamil word boundaries (letter-bearing false punctuation rejected); fragments and clock-hour/noun agreement must not become speaker gender; malformed optional gender alternatives are discarded and independently audited instead of rejecting the entire readable sentence. The actual malformed provider response was reproduced before the parser fix. Final backend 185 passed; unchanged Dart revision retains 894 Flutter passed / 15 environment skips and clean analysis. Final Deno formatting and git whitespace checks pass. No SQL changed; database suites not rerun.

Local fixture correction: the synthetic A/B profiles had null primary known language despite the UI defaulting to English. Set only those local fixtures to English, matching onboarding, so pending-job reads do not incorrectly fall through to generation. Existing daily count 200 and limits were NOT reset or increased. This is not a production profile migration or a claim that all legacy accounts are verified.

Review walkthrough:
1. 05-normal-immediate.png: authored original is dark/readable even while the pending-send clock is visible.
2. 06-practice-android.png and 07-practice-german.png: two actual viewers, context/names/negation retained. Android includes the historical pre-fix failure and successful repeat; newest messages all complete.
3. 08-practice-live.mp4: real-time incoming and outgoing Practice replacement, no erase/retype effect. Keyboard motion is Android’s own keyboard.
4. 09-reopen.mp4: brief data skeleton, then settled text appears whole; no delayed previous-screen fade. This does not claim zero data-load time.

No owner visual approval, hosted deployment, integration, signed Firebase release or physical-phone verification yet. Candidate source hash is in candidate.json. Await review before merge under the owner’s Blab workflow.

Final packet delivery receipts: Telegram topic7420 messages12586 (screens),12587 (live Practice recording),12588 (reopen recording). Browser test tab closed and Android test app stop requested after capture.

- Owner approval: Telegram topic7420 message12599, 2026-10-14 21:41 Berlin: “Yes release to firebase”, replying to the actual reviewed packet. Authorized integration and Firebase distribution; physical-phone manual acceptance remains unverified.

- Release completed 2026-10-14: approved source3361abb synchronized to main; production translate-message/prepare-message-jobs deployed and seven runtime source files read back identical. Backend environment verification and unauthenticated401 gates passed. Signed v16 APK SHA256 e795d7fdd1db3fbf82e148754eff8e7f6e6d7d465baced45e4a0dd301d17e0b5 replaces signed v15 on emulator5560, retains German, cold-launches successfully. Main CI38625954861 all three jobs passed. Firebase release3lm50l43b9k0o received exact download-back checksum and distributed to the existing two testers (both Accepted). Physical phone/authenticated-history retention remains unverified. Owner-facing checkbox remains unchecked pending actual phone acceptance. No chat-history cutover enabled.
