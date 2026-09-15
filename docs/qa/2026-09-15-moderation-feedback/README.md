# Moderation feedback Android QA

## Verified behavior

- Incoming-message long press still exposes `Report`.
- Message and person reports persist the expected reason and show the shared passive-success pill.
- Block requires the approved localized confirmation and does not show redundant transient feedback.
- The confirmation uses Blab's warm card, brown text hierarchy, neutral Cancel action, and soft-red Block action.
- A blocked chat remains visible in Chats and reopens with readable history.
- The composer is replaced with `You blocked Alice Local · Unblock`.
- Unblock removes the database row, restores the composer, and shows the shared success pill.
- Chat success pills sit 12 px above the active composer or blocked-state bar instead of covering it.
- Ukrainian `Hate speech` is labeled `Ненависницькі висловлювання`.
- Claiming another invite for a blocked pair reuses the existing chat and preserves the block.
- Database policy prevents both participants from sending while either direction is blocked.

## Locale evidence

The Block confirmation was checked at the default Android viewport in English, German, Spanish, and Ukrainian. All copy and actions remain readable without clipping or overflow. The final warm-card visual was captured in Ukrainian.

## Verification

- `flutter analyze`: no issues.
- `flutter test`: 545 passed, 15 environment-gated skips.
- `supabase test db`: 14 files, 155 tests passed.
- `git diff --check`: clean.
- Android log inspection after chat/profile navigation: no Flutter, Riverpod, or fatal exceptions.

## Cleanup

Bob's interface language was restored to Ukrainian. QA-created reports and Alice/Bob block rows were removed.

## UI review

The dialog hierarchy, destructive emphasis, persistent recovery affordance, localization fit, and transient feedback consistency all score at least 8/10. No blocking visual issue was found in this cycle.
