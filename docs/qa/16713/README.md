# BLA-13 · five learning languages + Marathi reading script

Request: Nastia, Telegram topic7420 message16713 (29 October2026).
Branch: feat/bla13-languages-16713; base main877fe8c. Approved16774; commit/merge/deploy authorized16781. Integrated source f0806bf; language backend deployed to staging and production. Four signed version45 app artifacts prepared, NOT uploaded/distributed. See current gates below.

## Scope and preference mapping
- Add da, fi, ko, mr, pl to learning/known-language selectors, four existing UI
  translations of names/timeline markers, translator registry, SQL admission,
  and explicit system speech locales. Interface locales remain en/de/es/uk.
- Practice uses each viewer's learning language; explanations use that viewer's
  primary known language. Normal-mode source/known-language semantics unchanged.
- Polish and Marathi join existing participant-form audits. Shared generic
  feminine/masculine policy is unchanged; no mandatory language-level question.
- Marathi joins hi/ta in the same account-wide Reading script setting. Native
  default; English letters use complete existing Romanization. Incomplete
  metadata keeps the whole native sentence. Authored/Original text and native
  audio are unchanged. Korean receives no new script setting.
- Existing saved-form correction policy is not modified or silently reconciled.

## Evidence
- Focused initial Flutter21 pass; complete Flutter1098 pass/17 environment skips.
  Added one further speech fail-closed regression: six focused audio/registry
  checks pass. Final static analysis and native status tracked below.
- Translator190 tests pass, including replay of actual Polish provider output.
- SQL PGlite migration fixture passes: five new codes admitted by both allowlist
  orders including a renamed compatibility helper; UI locales stay fixed,
  function grants and preexisting rows retained; unknown code rejected.
- Android: existing emulator5584, isolated bla13preview app ID. Five selector
  choices confirmed with Done; Marathi settings/save flow passes; eight captured
  screenshots inspected. Synthetic account data; not live persistence/restart
  or full chat acceptance. Both signed installed Blab apps remain untouched.
- Android system TTS reports da-DK, fi-FI, ko-KR, mr-IN, pl-PL available. This is
  engine capability evidence, not human pronunciation review. Playback now stops
  if selecting the requested locale fails, preventing previous-language audio.
- Eight live application-provider requests: translation + contextual word help
  in all five languages; Marathi grammatical alternatives; Korean respectful
  tone. `live-language-results.json` retains original results, including the
  initially failed Polish form-choice acceptance (not hidden).
- Polish probe reproduced valid provider alternatives discarded by strict
  three-word gloss validation. Existing nonempty acceptance now permits longer
  explanatory glosses while retaining exact token/variant text checks. Strict
  acceptance is unchanged. Regression190 and fresh `polish-review-repeat.json`
  show both Byłam…zmęczona / Byłem…zmęczony retained after repair.
- No prompt wording changes. Language additions use existing generic policies.
  Translation cache keys already include languages; no accepted history erased
  or retranslated. Provider caching is automatic, no explicit cache objects.

## Review-time gates (historical; superseded below)
- iOS simulator selector/settings + five live-generated sentence renderings and Marathi native/English-letters renderings pass. Inspected all six text screenshots and representative selector/settings screenshots. Four voices available; Marathi unavailable on this simulator. Actual-phone Marathi audio remains a release gate.
- Extra Android text-rendering replay could not run: emulator5584 had stopped before the attempt. Earlier Android selector/settings success remains valid; no new AVD created or existing user data reset.
- Complete clean-database migration + live two-account persistence/history,
  fresh/cache-hit acceptance in authorized hosted test environment not yet run.
  Local Docker CLI did not respond; no shared Docker restart/reset performed.
- Human/native-speaker review of linguistic quality and actual audio desirable;
  successful requests alone are not proof of universal correctness.
- Owner visual/workflow acceptance, integrated revision verification and explicit
  production/distribution approval required. Existing overlay release remains
  held for an approved combined release; no notice or tester-channel change.

## Final handoff
- Full1098 client tests/17skip pass; subsequent audio guard6 focused checks pass. Translator190 pass plus final three BLA-13 regressions pass; SQL fixture additionally validates the actual normalization function for all new source codes. Static analysis/diff clean.
- UI review packets16744 and16765 sent. Both native preview applications use isolated IDs; Android/iOS build-only configuration overrides restored. Existing installed test/public apps preserved.
- Original-only/cached historical behavior not mutated. No hosted backend execution, main merge, release or update notice activation.

## Approval and release continuation16781
- Nastia approved screenshots/workflow16774; explicit commit, deploy and merge16781. Scope: five languages and Marathi reading script, combined with already-integrated held overlay; existing audiences only.
- Preparing commit and clean-schema CI. Local Docker ping still times out; no shared restart/reset. Physical-iPhone Marathi voice remains unverified.

## Release continuation16781 · final checkpoint
- Feature commits56582ca/e7af21d, CI repair8b3ad23, current-main reconciliation72e135a, built-in workflow-token fixf0806bf. Main/local/remote synchronized at f0806bf before artifact preparation. BLA-17 dc4939c arrived during CI and is included in the integrated app, but remains explicitly held from upload/distribution by its own approval16778.
- Quality and Android compile passed on e7af21d. Isolated clean-schema/backend integration40925113532 passed, including BLA-13 persistence/history, existing atomic batches/authority and full backend integration. Registry throttling caused two earlier environment-start failures, not test failures; authenticated GHCR pull support/backend-only retry added. No hosted credentials in CI.
- Combined local app suite:1113 passed/17 skipped; only CI-contract test initially failed on the spelling of the built-in token context. Replaced secrets.GITHUB_TOKEN with github.token (same ephemeral read-only token, no custom deployment credential); all3 CI-contract checks pass. Final integrated main Quality40926297623 passes. Its backend repeat again hit registry throttling before tests; remaining Android CI job was cancelled, not passed. Local signed Android builds below do pass.
- Both environments: migration20261029000003 applied with ledger/source SHA256 verification; translate-message and prepare-message-jobs deployed, downloaded rulebook/contract/single_call bytes match integrated source. Five source codes verified. Staging rollback probes verify persisted learning/known/source languages, retained older cache, authenticated preference saves and cross-user write rejection. No lasting QA users/data. Production manifest verification passes after ignoring an empty CLI migration-list placeholder.
- Staging's broader manifest check reports pre-existing missing STREAM_API_KEY/STREAM_API_SECRET. Language persistence and translation deployment pass, but this is not a full staging configuration pass. Do not copy production credentials or silently connect the separate review Stream app. Existing review credentials identified, no authoritative staging mapping established; left unchanged.
- Post-integration Android isolated preview: five selectors, Marathi settings and all-five live-generated text samples/both Marathi scripts pass. Fourteen captures retained; Marathi settings/Latin rendering and Korean rendering inspected. Existing Bob5584 crashed with host GPU; restarted the SAME AVD with software rendering, no wipe/new device. Both production/test installed apps retained.
- Both signed Android45 APKs verified correct package/version and same certificate as44. Exact44→45 replacements retain firstInstallTime, all settled preference-file hashes and sentinel before first launch. Public baseline reconstructed from archived44 with German chosen through actual UI; German retained after45 launch. Existing test44 signed-out baseline retained and launches45. Not proof of physical-device/account/chat-history retention.
- Both signed iOS45 archives exported; parent+two extension versions and deep signatures verified. No Apple upload. Original build-only signing configuration restored.
- Artifacts and full logs: ../releases/20261029-languages-16781 (shared project root). Android/iOS manifests contain source/hash/package mapping. Only idle task-owned ignored compilation caches removed to recover space; source/signing/data/QA/release artifacts preserved.

## Current gates
- All four version45 artifacts prepared, zero uploads/distributions, no tester communications, no notice activation. Relevant notices remain43; unrelated disabled rows remain0.
- BLA-17 message-panel update is on current main but explicitly distribution-held. Obtain combined-scope approval before uploading/releasing it with languages and the approved mention overlay. Exact outgoing tester copy still needs approval.
- Resolve staging Stream configuration with an authoritative staging target before claiming full coordinated delivery readiness. No unrelated service credentials were changed.
- Physical-iPhone Marathi voice/pronunciation remains unverified; simulator lacks that voice. No different-language fallback. Owner manual launch-tracker checkboxes remain untouched.
