# Moderation feedback Android QA

## Verified behavior

- Incoming-message long press still exposes `Report`.
- Message and person reports persist the expected reason and show the shared passive-success pill.
- The shared six-reason picker scrolls when vertical space is limited, so every reason remains reachable on shorter screens.
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

The Block confirmation and complete six-reason person-report sheet were checked at the default Android viewport in English, German, Spanish, and Ukrainian. All copy, reasons, and actions remain readable without clipping or overflow. The final warm-card visual and a successful person-report acknowledgement were captured in Ukrainian.

## Verification

- `flutter analyze`: no issues.
- `flutter test`: 590 passed, 15 environment-gated skips.
- `supabase test db`: 14 files, 155 tests passed.
- `git diff --check`: clean.
- Android log inspection after chat/profile navigation: no Flutter, Riverpod, or fatal exceptions.

## Cleanup

Bob's interface language was restored to Ukrainian. The QA-created person report was verified in Supabase and removed; Alice/Bob block rows remain absent.

## UI review

The dialog hierarchy, destructive emphasis, persistent recovery affordance, localization fit, and transient feedback consistency all score at least 8/10. No blocking visual issue was found in this cycle.

## 2026-09-22 current-main replay

Alice in the browser and Bob on an isolated Android emulator completed the English end-to-end moderation flow on `093d803`:

- Message report and person report both showed acknowledgement and persisted distinct `spam` rows with the expected message-level versus person-level evidence.
- Blocking kept the existing conversation and history visible, replaced Bob's composer with `You blocked Alice Local · Unblock`, and preserved the block row.
- Alice's send attempt failed visibly and did not persist; Bob's direct policy probe was rejected by row-level security with HTTP 403 and did not persist.
- A fresh Alice invite opened from a cold Android app launch reused the one existing chat, consumed the invite, and left the block intact.
- Unblock removed the block row, restored Bob's composer, and allowed new messages from both Alice and Bob to persist and arrive.

Baseline verification passed 694 Flutter checks with 15 intentional environment-gated skips. The two QA report rows, two recovery messages, consumed invite, and block row were removed afterward; the original chat remains. No product failure or screenshot-worthy mismatch was found. Combined with the existing English, German, Spanish, and Ukrainian Android UI evidence above, the owner approved the flow and closed Step 3.6a on 2026-09-22.
