# Mention overlay16617

Base388c71c; uncommitted review candidate.

- User reference: Telegram names overlay the conversation above the composer.
- Production ChatComposer now hosts MentionPickerOverlay; portal does not consume timeline layout space. Existing picker styling and mention semantics retained.
- Earlier56 focused checks passed. Resumed50 targeted overlay/chat regressions passed; analysis clean; diff check clean.
- Android API36 existing material3 device5584,1080x2400. Separate blab.nastia.ez.test.overlaypreview synthetic-data fixture: signed public/test installations untouched. No backend calls or real messages sent. Build-only applicationIdSuffix and Firebase package adjustment restored byte-for-byte.
-01-before.png: real keyboard and draft; message visible.02-overlay.png: names cover message while Yesterday/composer stay fixed.03-selected.png: Ash inserted, picker gone, message restored at same position, keyboard retained. Each opened/inspected.
- Recording includes opening and selecting; no web or iOS verification claimed.
- No merge/release/notice/backend change. Actual screenshot approval pending.

## Approval and release16633
Nastia16630 accepted screenshots/recording;16633 authorized commit, merge main, deploy. Full1095 tests pass/17 environment skips. No backend/runtime configuration changes in this slice.
