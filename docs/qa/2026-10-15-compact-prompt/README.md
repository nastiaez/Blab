# Compact dynamic translation request — released v21

Authorization: Ash, current development topic7420 message12931, asks to implement the reviewed optimisations, build and launch to existing testers. Dedicated current-main worktree perf/compact-translation-prompt-20261015, base0d34bf4. No client UI redesign. Preserve independent unrelated worktrees and existing tester/signing identity.

## Preference-to-output map and traced existing contracts

Reviewed PRD US-015/022/046, FR-13/23/33/40, tech-spec and current progress. `profile_service.dart` independently persists interfaceLanguage, knownLanguages and primaryKnownLanguage. `message_presentation.dart` chooses Normal original versus unknown-source known-language result; Practice uses applicable historical learning result. `chat_service.dart`/`message_translator.dart` map legacy interfaceLang to primary known language, not interface language. `leased_translation_action` → `prepare_leased_message_translation` resolves each viewer's historical era, learning target, known target, tone and authorized context. `single_call_worker.ts` prepares independent viewers before the provider request; atomic completion fences source/revision races. Existing shared-language persistence regression retained.

- Practice sentence/audio: viewer's applicable learning language/revision.
- Normal unknown incoming and Practice secondary: viewer's primary known language.
- Word meanings/correction metadata: viewer's primary known language.
- Interface language: UI only; omitted from model input.
- Authored Normal, known incoming, aids off, unsupported-source and historical completed data behavior remains unchanged.
- Tone, distinct eligible historical context and explanation language remain part of generation deduplication. Saved grammatical forms stay private client state. Participant alternatives identify sender/recipient once; adapter maps ownership for each viewer deterministically.

## Request

Canonical concise runtime rules, dynamic named-language output list, stable structured schema, changing message/participant/context data last. One sentence per distinct language/tone/context; one word-help set per learning sentence/explanation-language pair. Identical contexts normalize viewer-relative speakers and share one input. Explicit reply text has priority within the existing 3-entry/1800-byte budget. No message text in cache keys; no full-response/global text cache. No source-detection call, independent reviewer, speculative hedge or token padding. Existing deterministic validations, durable failure-only retry and atomic save remain.

Provider cache: Gemini implicit prefix caching is automatic. Keep stable rules/schema and settings order; measure actual cached token usage through existing usage-only provider telemetry. Do not claim cache hits from layout alone or force explicit content storage/relax ZDR. OpenRouter documentation checked 2026-10-15: https://openrouter.ai/docs/guides/best-practices/prompt-caching . Savings and final device/release evidence pending.

Older latency playbook's independent-review requirement conflicts with approved one-call policy. Current canonical SINGLE_CALL_POLICY and explicit owner request win; no second reviewer is reintroduced. No product behavior is dropped to shorten the prompt.

## Candidate verification

188 backend tests,941 Flutter tests (15 existing opt-in skips), static analysis, translator type check, format, shell syntax and whitespace pass. SQL single_call_batches.sql passes atomic grouping/lease fencing and identical-language-pair persistence in a rollback-only test on the disposable clean database. No database schema change.

Live provider: initial12-message/24-viewer sweep passed; final expanded13-case sweep found one omitted duplicate base-token array while complete matching form metadata was already returned. Deterministic reuse now passes regression and the exact live form case; no repair call. Initial Spanish authored-gender and word-language failures were fixed before final checks. Mixed draft/spacing fixture exposed mode=none token clearing; red-green regression preserves original spacing and reuses aligned provider words. Final synthetic actual-provider outputs retained in live-results.json, live-final-with-metadata-repair-case.json, mixed-spacing-result.json and form-result.json. Recorded failures are intentionally retained, not counted as successes. Provider automatic prefix cache reported0 cached tokens; no discount claimed. Representative four-language serialized request10033→5429 bytes before final mixed-language sentence (about46% smaller); actual model input is roughly1.6–1.8k tokens. Not a guarantee of every11-language utterance's semantic quality.

Android: AliceLocal emulator5556, knownEnglish/learningDutch; BobLocal5558 knownUkrainian/learningSpanish, shared synthetic chat5dfa08f9-eeb3-4e53-8587-17374b2ac722. Changed learning preferences through actual UI; Bob's primary-known fixture changed locally and app relaunched before messaging. Both open chats exchanged Dutch/Spanish book messages;4 fresh messages yielded8 ready jobs at attempt1. Practice Dutch/Spanish and Normal incoming English/Ukrainian verified; authors retain their own original in Normal. Older Ukrainian/German historical learning rows stayed unchanged. Normal/Practice switching after recovery produced0 additional provider metrics (count remained1 in final QA-server log).

An existing synthetic draft accidentally prefixed the first send, creating the mixed-spacing regression. Preserved the authored fixture; after the fix, only that local message's generated cache was cleared and its2 failed jobs reset for a controlled re-evaluation. Both returned ready in one call, not an authored-message deletion or production data repair. Runtime is task-owned temporary /tmp/blab-stream-backend-20261014; original translator/worker snapshot preserved /tmp/blab-pre-compact-runtime. No reset/migration of shared runtime database.

Actual four final screenshots inspected and delivered to current topic in12940–12943. No UI layout/motion code changed. Owner12931 explicitly requests build/launch after this reviewed optimisation proposal; proceed with that release authorization. Physical-phone manual acceptance remains pending and no launch-tracker checkbox is marked complete. Integrated signed21/backend readback/Firebase receipts pending.

## Integrated release completed

Source bedd4f8c79eb2b3255e2913a50d4bd5c7d5bfadf integrated and pushed to main. All three source CI jobs passed: Quality, Android release compile and Local Supabase integration (run38748145556). Production translate-message31/prepare-message-jobs10 deployed,12 readback files match source; backend verifier and both anonymous401 checks pass. Exact signed20→21 replacement installation retained German preference without uninstall; installed and Firebase-downloaded APK hashes match. This is a signed-out baseline, not physical-phone or authenticated-history proof. Earlier two-account Android QA completed; a redundant later replay could not run after those emulators were closed, and is not counted as passing.

Firebase1.0.0(21), release4354ve9mkupn8, distributed to both existing testers. Reopened exact release confirms two memberships, invited2/accepted2/downloaded0 at verification. Receipt and retained-German screenshot attached. Physical-phone acceptance remains pending. Prompt layout enables provider caching but observed cached tokens remain0; no cache discount claimed.
