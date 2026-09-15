# Moderation Feedback Design

**Status:** Approved by the owner on 2026-09-15.

## Goal

Keep Blab's required report and block controls calm, reversible, and easy to recover from without adding a separate blocked-people settings flow in V1.

## Approved behavior

### Report

- A successful message or person report shows the shared compact passive-success pill.
- The pill contains the leading check-circle, localized acknowledgement copy, no close icon, and a 2.5-second timeout.
- A completed person report closes the partner profile sheet before presenting the pill so feedback is visible on the chat surface.
- A failed report keeps the existing failure feedback and does not close the relevant surface.

### Block

- Tapping Block first opens a confirmation dialog.
- The localized English pattern is: title `Block Name?`; body `Do you want to block Name from messaging you on Blab?`; actions `Cancel` and `Block`.
- The confirmation does not add secondary information about later unblocking.
- Confirming Block closes the dialog and partner profile sheet but keeps the conversation visible.
- The changed composer state is the confirmation; no additional Block Snackbar appears.
- A failed Block keeps the partner profile sheet open and shows the existing localized failure feedback.
- Blocked conversations remain in Chats and their history remains readable.

### Visible recovery

- While the current user has blocked the partner, the normal message composer is replaced by a compact persistent row: `You blocked Name · Unblock`.
- Tapping Unblock removes the block, restores the composer in place, and shows the shared 2.5-second success pill.
- Neither participant can send messages while either direction of the relationship is blocked.
- The partner profile sheet also continues to expose Unblock.
- V1 does not add `Privacy → Blocked people`; the visible chat is the recovery surface.

### Invites

- An invite between an existing blocked pair reuses the canonical conversation; it never creates a second chat.
- Opening or claiming that invite does not remove the block.
- The reused chat opens in its blocked state with the visible Unblock action.

## Visual direction

- Reuse the approved passive-success pill for report and unblock acknowledgements.
- Style the Block confirmation as a Blab card: `#FFFCF8` surface, `#E1DAD2` outline, `#46281C` primary text, and `#917869` supporting text.
- Keep Cancel neutral. Render Block as a soft destructive action with `#FFF6F4` background and `#D95245` text.
- Position passive-success pills 12 px above the active bottom surface instead of at one fixed screen coordinate.
- The blocked-composer replacement uses the existing chat surface and divider colors, one concise status line, and a clearly tappable brand-colored text action.
- Long localized names may wrap; the action remains reachable at enlarged text sizes.

## Ukrainian terminology

- Use `Ненависницькі висловлювання` for the `Hate speech` report reason; avoid the more formal but ambiguous `Мова ворожнечі` label.

## Accessibility

- The blocked state is announced as status plus action, not as disabled input chrome.
- Unblock has a minimum 44 px tap target.
- Color is not the only indication of the blocked state.
- Feedback follows the existing route-dismissal and accessible-timeout behavior.

## Acceptance checks

- Message and person reports show the same passive-success pill.
- Blocking requires the localized confirmation dialog and keeps the chat in Chats.
- Confirming immediately replaces the composer with an obvious Unblock action.
- Unblocking from either visible entry point restores sending and shows the passive-success pill.
- A blocked pair cannot send in either direction at the database boundary.
- Re-inviting a blocked pair opens the same blocked chat without removing the block.
- English, German, Spanish, and Ukrainian layouts remain readable on Android.
- Report and Unblock pills clear the composer or blocked-state bar by 12 px.
