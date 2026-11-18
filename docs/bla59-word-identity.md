# BLA-59: corrected-word identity

Base: freshly fetched origin/main 93dc409ed6c2449d7a87532bf9edbb927c8cb92d.
Branch: fix/bla59-word-identity; isolated worktree ../blab-bla59.

## Root cause
The legacy correctionSegments builder inserts a visual space between struck original text and its replacement. DeepDiveScreen counted every non-struck segment, including that synthetic space, toward offsets in the accepted translation. Those spaces do not exist in displayText. Every replacement before a selected word shifts its lookup start/end right by one UTF-16 code unit. One prior replacement selects hrzeit plus following whitespace; two select rzeit f. The popup title comes directly from the visible token, while both the provider request and the details title use the shifted substring. Thus changing the heading alone would leave the wrong explanation and pronunciation identity.

Fix: mark synthetic separators presentationOnly and exclude them from accepted-text offset accumulation. Keep their rendered text and spacing unchanged. Actual authored/replacement whitespace still counts. No language, translation, provider, server, quota or cache policy changes.

## Preference mapping recorded before implementation
DeepDiveLiveScreen already resolves viewer-private accepted output through current viewer ID, per-chat mode, learning language/revision, Primary Known Language and aid eligibility. Learning Language owns word/audio target; Primary Known Language owns explanations; Interface Language owns chrome only. Normal/known/unknown, aids off, unsupported-source and immutable correction eligibility remain in existing presentation/snapshot logic. This fix changes only the accepted-text coordinate mapping. Existing service isolation, off-aid, language/revision, stale response, and explicit-provenance tests remain required.

## Evidence
Offline regression injects a clearly synthetic analysis at DeepDiveService.invoke, never an external provider. It taps the real DeepDiveScreen word, asserts the exact request substring/offset/source/accepted text and language fields, then opens the real WordDetailsScreen and asserts the complete title. Cases cover one/two prior corrections, emoji surrogate pairs and decomposed combining characters. The initial unmodified implementation failed both initial cases (expected Uhrzeit, actual rzeit f). The fix passed those and the expanded matrix.

Screenshot files in qa-artifacts/bla59 are Flutter widget-renderer fixtures, NOT native screenshots or live-provider explanations. Any Ahem-font initial capture is rejected and overwritten only after loading the bundled production Roboto font. These initial captures did not establish native acceptance; the later Android continuation below supersedes that limitation only for the synthetic native popup→details slice. iOS and ordinary authenticated conversation remain unverified.

Initial gates: full Flutter suite1469 passed /36 skipped in146s; final continuation suite1470 passed /36 skipped in155s,14 focused checks PASS and analysis clean; final screenshot/regression4 passed; final analysis no issues in3.1s; format/whitespace checks clean. Canonical logs, source/image hashes and two inspected final PNGs: qa-artifacts/bla59/. Delivery copies: /Users/aswin/.openclaw/media/blab-bla59/.

Native continuation18November: live guard cleared (11734716KiB at preflight; 11554664KiB immediately before compilation). Actual reused Bob Android5586 native popup→details passed with complete Uhrzeit request span48..55 and heading; three actual ADB PNGs and34.99s native H264 plus2fps contact sheet inspected. Review movie is the first17seconds, temporally trimmed only. Analysis/meaning is explicitly synthetic at invoke; no provider/hosted calls or authenticated-chat claim. The harness performs no preference saves; original-package state preservation failed as disclosed below. iOS owner pause remains.

SAFETY INCIDENT: automatic Flutter test deployment unexpectedly removed existing blab.nastia.ez while installing the isolated blab.nastia.ez.bla59qa. Existing Blab Test retained its original install/update timestamps. Original-package local data may be lost and was not verified/recovered; see qa-artifacts/bla59/native/SAFETY-INCIDENT.md and before/after inventories. Do not claim all emulator data preserved. No arbitrary older APK restore attempted; parent decision required. Native configuration restored byte-identically; production Dart hashes unchanged. No reset/new emulator/paid/hosted/push/merge/distribution.

No provider calls, hosted mutations, push, merge, distribution, device reset, emulator creation or unrelated worktree edits. One isolated native QA install and its unexpected original-package removal are disclosed above. Main remains93dc409 with its original2 untracked paths. Full tests generated an untracked parity directory inside this worktree; preserved/excluded from intended source scope.


## Visual review · 18 November 2026
Nastia approved the delivered Android Word details screenshot with “Good” (topic7420/message20781, reply20780). This records visual acceptance of the corrected complete-word display, not live-provider/audio acceptance or authorization to restore emulator data. iOS remains paused. Merge and release are not yet completed. <!-- project: github.com/aswinckr/clawdbot -->
