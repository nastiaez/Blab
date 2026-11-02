# BLA-40 · candidate review record

## Revision and authority
- Worktree: /Users/aswin/clawd/projects/blab/blab-bla40-links-20261102
- Branch: feat/bla40-links-20261102; fetched base origin/main ed2ac549d287944613341491eaf700299aaf8a38.
- UNCOMMITTED working-tree candidate. candidate-source.json fingerprints exact changed source/test files. No feature commit, push, integration, backend/cache/prompt/data change, or release/distribution.
- Nastia authorized implementation in topic8856 message17281,2 November2026 at15:32 Berlin. Actual candidate visuals/workflow still require explicit review. Design approval is not candidate/integration/release approval.
- Final approved specification and original report: ../../specs/2026-11-02-bla40-inline-links.md.

## Behavior and adaptations
URLs are native inline spans rather than per-word boxes. Incoming actual tag ink #BC6C4E and outgoing #231208 retained, all URLs underlined. Incoming3.81:1 contrast was disclosed; no unapproved darkening. Short URLs remain complete. Long URLs are measured against the actual paragraph, compact to two rendered URL lines, and keep the complete authority visible. A pathological authority can exceed two lines rather than hide its host. Full raw URL remains the Copy payload; browser target is full URL (https added only for bare domains). No AI or shortening service.

Separate Paper-V2-style anchored menu has one full destination, a four-line-height scrolling URL area and fixed Open/Copy actions. Native route keeps existing message height, keyboard and draft; outside/Back dismissal. Link hits are excluded from the parent's heart recognizer so rapid URL taps cannot become message reactions. Other message/BLA17/form-marker/mention controls retain their existing actions. Unresolved form-marker text is covered too, without changing form/translation policy.

URL-containing bubbles use their incumbent maximum width to avoid an actual LayoutBuilder/IntrinsicWidth blank-chat failure; non-URL intrinsic bubbles retain the original path. This is an explicit reviewable layout adaptation, not presumed visual approval. Original failed proof is retained separately, not delivered as successful evidence.

## Checks
- Focused final:93 passed (URL14, existing form/message/gesture/bubble checks); focused-final.log.
- Full client final:1128 passed/17 environment skips,0 failed, verified exit0; latest flutter-fresh-cache.log and check-exit-receipts.json (concurrency2,60s per-test timeout). Earlier complete1128 and pre-marker1126 pass logs retained. Repeated incremental runner stalls, including a redundant receipt-only attempt, are retained separately; recovered by renaming/preserving only this worktree’s ignored111MiB build/test_cache as build/test_cache-bla40-stalled. Fresh compiler-cache full rerun completed in129s with exit0. No shared SDK/device/backend/source mutation.
- Pure backend:224 passed/0 failed; deno-full.log. No backend deployment/service lifecycle work.
- Analysis: clean; analyze.log. Diff whitespace check clean. Formatting:12 changed Dart files,0 differences; format.log. Native harnesses received formatting-only edits after capture; exact tested pre-format copies retained as tested-harness.dart.txt in each native QA directory. Product source fingerprints are unchanged from the supplemental native replay.
- Earlier full failures and native-identity interference are retained separately, superseded only by successful current checks. They are not counted as passes.

## Native evidence
Android, existing reusable Bob AVD5584, isolated QA application ID; actual ChatScreen with provider fixtures, not reconstructed screens.
1. Matrix: eight cases Normal/Practice × incoming/outgoing × short/huge. URL-area scrolling preserves action rectangles and message geometry; actual145.36s recording. ../2026-11-02-bla40-native/matrix-native.log.
2. Keyboard: actual native Clipboard readback; retained draft/IME while menu opens/dismisses. Three actual PNGs and keyboard recording. ../2026-11-02-bla40-native/keyboard-native.log.
3. Supplemental: actual German grammatical correction Ich gehen→Ich gehe, long Berlin Science Week URL, different English comprehension revealed by BLA17 selection. Selected message rectangle unchanged on URL menu. Exact native Copy for Berlin URL, punctuation-stripped bare nastia.design, full1209-character URL. Unmocked external browser action opens Chrome; adb Back returns to same selected message. ../2026-11-02-bla40-edges-native/native.log and README.md.101.17s actual recording.

Browser evidence proves native handoff, NOT website load: existing Chrome stopped at first-run onboarding; no account/settings changed. Interface/primary-known English and learning German are explicit fixture selections, not product defaults. All native screenshots and representative recording frames were opened/inspected. OS clipboard feedback in copied screenshots is diagnostic and excluded from the clean packet.

## Clean review packet
Directory: /Users/aswin/.openclaw/media/blab-bla40-build/
- edges/correction-chat.png: genuine correction and Berlin URL, normal line spacing.
- edges/correction-selected.png: distinct English comprehension.
- normal-incoming-huge-menu.png and normal-incoming-huge-scrolled.png: URL-only scroll/fixed actions.
- practice-outgoing-short-chat.png: outgoing colour/underline.
- keyboard-link-menu.png and keyboard-menu-dismissed.png: retained keyboard/draft.
- review-scroll-9s.mp4: unaccelerated clean excerpt of actual matrix recording,17s start/9.03s measured duration. Beginning/middle/end frames inspected: compact bubble→menu→URL scroll, fixed actions. Earlier25s excerpt included harness teardown and was rejected into diagnostics/rejected-scroll-25s.mp4, not part of the review packet.
- edges/review-correction-48s.mp4: unaccelerated first48s of actual supplemental recording.
- Full recordings: matrix-motion.mp4, keyboard-motion.mp4, edges/motion.mp4.

Linear Resources receipts:5d19f03f-0a96-4642-8750-b5f3c832d319 (menu PNG),7d27894d-a4ee-4af8-bf35-719f2a65b739 (matrix MP4),a64772bb-a151-4a38-b0ef-ea3701a14f98 (correction PNG); each raw PUT returned200 and attachment finalized. Local paths are not chat delivery receipts; parent must send requested clean media in originating topic.

## Limits and preservation
- iOS and physical devices NOT tested; no booted iOS simulator, limited free disk after native Android. No iOS parity/acceptance claim.
- No live provider/backend/Alice–Bob proof; caches/translation responses are fixture inputs. Unit tests verify full external-launch target/flags and large-text/narrow/pathological-host behavior; native viewport matrix does not imply every accessibility/keyboard size passes.
- Both originally used existing AVDs preserved; no creation/reset/deletion.5586 released for another owner.5584 gracefully stopped after QA, leases released; no shared backend/Docker mutation. Temporary Android settings restored byte-for-byte; original packages retained.
- Full suite generated six unrelated wordmark parity PNGs under docs/qa/2026-10-21-early-opening/parity (test/wordmark_render_parity_test.dart:62); retain as generated check artifacts, not part of BLA-40 product scope.
- Linear is Testing, not Done/Implemented on test. Owner visual/journey review and iOS/live-client limits remain; no commit/push/merge/release approval implied.
