# Invite error action layout

**Status:** Approved by owner on 2026-09-20  
**Scope:** The four in-app invite failure states shown in the latest-main Android review.  
**Principle:** Every error has one nearby recovery action, while leaving the screen is handled separately.

## Problem

The resolver states mix recovery and escape actions in the same vertical stack. The temporary failure repeats the same idea across explanatory copy and a separate **Retry** button. On **Invite a friend**, the failed-link **Retry** is visually detached from the error, while unrelated helper copy and a disabled bottom action remain prominent.

## Approved layout

### Resolver states: invalid, temporary failure, and already claimed

- Keep the existing centered title, explanation, behavior, and localized copy.
- Remove **Go to chats** from the content area.
- Add a top-right close icon with a 48 dp tap target. It always routes to Chats so it remains reliable when the screen was opened from an external link.
- Invalid and already-claimed states contain only their centered message and the close action.

### Temporary invite-opening failure

- Keep the existing centered failure title.
- Remove the separate explanatory sentence and both stacked buttons.
- Show one centered text action using the existing localized **Retry** label directly below the title.
- Preserve a 48 dp invisible tap target without giving the action a filled container.

### Invite-link creation failure

- Keep the invite card unchanged.
- While link creation has failed, hide the unrelated one-person helper and the disabled bottom **Send invite** action.
- Directly below the card, split the existing localized error into its message and recovery phrase, then style that existing recovery phrase as the text action in one wrapping horizontal group.
- Keep the group left-aligned with the card. Longer translations may wrap naturally while the action remains attached to the error.
- Keep the error outside the card so the card retains its normal shape and the message reads like validation for the failed link field.

## Shared rules

- Do not change localization resources or introduce new copy. Reuse the existing localized recovery phrase instead of adding a second **Retry** label.
- Preserve the warm Blab canvas, typography, colors, and existing navigation.
- Use quiet text actions for retry recovery and a standard close icon for leaving resolver states.
- Verify English, German, Spanish, and Ukrainian at the supported phone width with no clipping or overflow.
- Preserve offline behavior: one top **No connection** banner and automatic retry on reconnection.

## Acceptance

- No invite error action is forced to full width or stacked with an escape action.
- Every Retry action is the closest action to its error message.
- Recoverable failures offer one Retry action; terminal states use the close action as the route back to Chats.
- All visible controls retain at least a 48 dp touch target.
- Existing invite behavior and localized strings remain unchanged.
