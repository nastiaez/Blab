# Invite error action layout

**Status:** Approved by owner on 2026-09-20  
**Scope:** The four in-app invite failure states shown in the latest-main Android review.  
**Principle:** Error actions hug their labels and stay visually attached to the message they resolve.

## Problem

The terminal invite states stretch **Go to chats** across almost the full screen even though the label is short. The temporary failure gives that escape action more visual weight than **Retry**. On **Invite a friend**, the failed-link **Retry** is pushed to the far edge of the row and looks detached from its error.

## Approved layout

### Invalid and already-claimed invites

- Keep the existing centered title, explanation, behavior, and localized copy.
- Replace the full-width **Go to chats** bar with a centered, content-width brand pill.
- Keep a minimum 48 dp tap target and horizontal label padding.
- The pill may grow only as far as its localized label requires, bounded by the available screen width.

### Temporary invite-opening failure

- Keep the existing centered title, explanation, behavior, and localized copy.
- Make **Retry** the content-width filled primary action directly below the explanation.
- Make **Go to chats** a content-width text action below **Retry**.
- Keep the actions in one compact recovery group so the next step reads before the escape route.

### Invite-link creation failure

- Keep the invite card, helper text, disabled **Send invite** button, behavior, and localized copy unchanged.
- Keep the error below the card.
- Place **Retry** immediately below the error, left-aligned with the card and error copy; remove the row that pushes it to the far edge.
- Preserve a 48 dp tap target while keeping the visible label close to the message.

## Shared rules

- Do not change localization resources or introduce new copy.
- Preserve the warm Blab canvas, typography, colors, and existing navigation.
- Use the same compact action styling across all terminal and recoverable invite states.
- Verify English, German, Spanish, and Ukrainian at the supported phone width with no clipping or overflow.
- Preserve offline behavior: one top **No connection** banner and automatic retry on reconnection.

## Acceptance

- No invite error action is forced to full width.
- Every Retry action is the closest action to its error message.
- Recoverable failures emphasize Retry; terminal failures offer one compact route back to Chats.
- All visible controls retain at least a 48 dp touch target.
- Existing invite behavior and localized strings remain unchanged.
