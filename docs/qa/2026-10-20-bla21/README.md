# BLA-21 · double-tap heart · 20 October 2026

- Base/current origin/main22157a3; branch feat/bla21-double-tap-heart-20261019. Uncommitted candidate; no main, server or release changes.
- Request: original task in topic8856; repeated double-tap removes own heart per Nastia14313. The other participant's reaction is never removed.
- Flow: incoming/outgoing in Normal/Practice; replace own other emoji with heart using existing notifier; failed/pending and blocked/left chats do not quick-react. Long-press still opens actions, badge tap still opens details, word tap remains lookup, swipe remains Reply.
- Preference-to-output mapping unchanged: Interface=en; Primary Known=uk; Learning=de in these fixtures. Mode resolves rendering through existing code. No translation, language ownership, server, auth or audio changes.
- Gesture/notifier focused packet6 passed, /tmp/bla21-focused2.log. Real ChatScreen four-case toggle journey passed, /tmp/bla21-journey2.log. These are code/fixture checks, not live cross-account transport proof.
- Android four-case replay passed /tmp/bla21-native4.log. Review rejected incidental Practice translation-failure presentation caused by incomplete cached fixture; added explicit de/uk cached payload (Hallo / Привіт, source de, mode translation, no paid model call). Clean final replay passed in /tmp/bla21-native5.log; all eight final screenshots inspected. Practice error-state captures from the first replay are superseded.
- Each seeded message has Bob's heart. After first double-tap the real notifier shows count2/reactedByMe=true; after repeat count1/reactedByMe=false. The fake service row belongs only to Bob. Existing notifier tests separately cover removal of the last own reaction and replacement by another emoji.
- Final native screenshots in android/ inspected; Practice outgoing add/remove pair delivered14350/14351. Retained diagnostics/first-replay-heart-toggle.mp4 is diagnostic from the superseded first replay, NOT final acceptance proof and not delivered. Simulated service rows and cached translation are test-only; not live Alice/Bob backend synchronization or live AI evidence.
- Full regression packet:974 passed /16 skipped / one missing baseline because this worktree sparsely excluded docs/qa. Restored exact tracked baselines from HEAD; the failed golden file then passed unchanged (/tmp/bla21-golden-recovered.log), resolving the environmental failure. This is a full packet plus targeted resolved check, not a single green full-suite invocation. Analysis clean (/tmp/bla21-analyze.log). Screenshot review, source integration, integrated Android and batch release approval remain separate gates.


## Reaction-pill revision · owner14372

- User reference: adjacent emoji types and right-hand participant total in one white oval. Current captures: `pill-14372/android-final/`; earlier circular captures14350/14351 superseded, not approved.
- Changed only pill layout/anchor; double-tap and service commands unchanged. White #FFFCF8, border #DCD2C8,32px visible/44px touch height,14px muted inline total (including1).
- Rejected `pill-14372/android/`: wider pill clipped on real native short incoming/outgoing bubbles. New outer-corner/inward-growth anchoring avoids clipping without resizing bubble, matching supplied reference. Native on-screen bounds assertions added; desktop Ahem-font fixture alone did not reveal clipping.
- Focused44 passed before anchoring. Final native `/tmp/bla21-pill-native2.log` passes all modes/directions with heart2, heart1 and mixed emoji2 states. Full `/tmp/bla21-pill-full-final.log` exposed3 obsolete circle/inner-corner assertions; updated to shared-pill decoration and explicit6px inset outer geometry. Targeted shared-pill/bubble suite31 passed (/tmp/bla21-pill-targeted-final.log); final analysis clean (/tmp/bla21-pill-analyze-final.log). Final single/mixed Practice-outgoing and mixed Normal-incoming/one-person Practice-incoming captures inspected; pair delivered14381/14382. Clean final full suite975 passed/16 environment-gated skips (/tmp/bla21-pill-full-verified.log). No automated failures remain.
- Controlled service/cached translation fixtures, not live cross-account proof. No commit/main/release changes.

## Actual screenshot approval ·14386

- Nastia approved screenshot14382 and requested build. Android debug APK built successfully (`/tmp/bla21-approved-apk.log`), SHA256 `0a3948ae3f84ed3c1da0ce4d1ba34df8779dbca4508e8b9d90dc52a3c976903f`. This is an isolated local/test candidate, not a release or integrated-main artifact. Live cross-account verification still outstanding; no distribution.
