# Visual Consistency Sweep Design

## Goal

Bring the remaining Blab screens into the visual language established by Chats, Chat, Profile, and the newer recovery screens without changing product behavior or restructuring layouts.

## Approved direction

- Replace the legacy brand color `#D4694A` with `#F88C5A` everywhere.
- Use `#F07D4B` for pressed brand controls.
- Replace the legacy cream canvas `#EFEBE2` with `#FAF7F2`.
- Use `#C62828` for errors, destructive actions, and warning confirmations.
- Use dark warm ink on the new orange for accessible button and badge labels.
- Use `#FFFCF8` surfaces and `#E1DAD2` outlines for warm cards and panels.
- Keep the Profile Log out row neutral; use red for the confirmation action. Keep Delete Account red with stronger emphasis.

## First implementation packet

### Shared theme

Update the shared brand, pressed, canvas, focus, and on-brand tokens so existing controls inherit the approved palette. Remove remaining user-facing ad hoc reds in favor of the semantic error token.

### Chats

- Update the unread badge fill and number contrast.
- Update the empty-state CTA.
- Update the refresh indicator and typing accent.
- Update the active Chats/Profile navigation state.
- Update error copy to the semantic error color.

### Invite

- Update the invite card to the warm surface and divider.
- Update preparation and share errors to the semantic error color.
- Replace the black offline strip with the approved soft warning treatment.
- Use shared palette tokens for the CTA and its label.

### Profile and reference screens

- Update the active tab state through the shared brand token.
- Update the Log out confirmation action to the error color.
- Normalize Delete Account and other user-facing error treatments to `#C62828`.
- Update any remaining legacy brand and background uses inherited by reference screens.

## Non-goals

- No navigation, copy, content, or data-flow changes.
- No new component architecture unless needed to expose a shared token.
- No drastic changes to layout, spacing, or information hierarchy.
- No replacement of the established Chat mode treatments.

## Verification

- Add widget tests for palette roles, button contrast, unread badges, Invite errors/offline treatment, and Log out confirmation.
- Run focused tests, the full Flutter test suite, analysis, and a web build.
- Review Chats populated/empty/loading/error and Invite ready/loading/offline/error in the browser with one account.
- Send matched before/after screenshots with a concise list of visible changes before merge.
