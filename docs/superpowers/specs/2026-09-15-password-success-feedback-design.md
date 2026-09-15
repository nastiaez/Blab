# Password Success Feedback Design

**Status:** Approved by the owner on 2026-09-15.

## Goal

Confirm a completed password change without the heavy visual weight or redundant controls of the current Snackbar.

## Approved behavior

- Show a compact, light, content-sized pill after a successful password change or password reset.
- Place a 20 px outlined check-circle icon before the localized message.
- Use localized copy without a trailing textual checkmark.
- Do not show a close icon. The pill dismisses after 2.5 seconds, on swipe, on replacement, or on subsequent navigation.
- Keep failure feedback on the password form where the action occurred.

## Visual direction

- Reuse the calm `Copied` acknowledgement treatment: `#ECE7E1` surface, dark ink, fully rounded corners, and compact padding.
- Keep the success icon and message on one line at the default phone width in English, German, Spanish, and Ukrainian. Allow natural wrapping at enlarged text sizes.
- Keep actionable feedback such as interface-language Undo visually distinct; this change applies only to passive success feedback.

## Acceptance checks

- Both password-success entry points use the shared passive-success presenter.
- The message has a leading check-circle and no trailing `✓` in all four interface locales.
- The rendered Snackbar explicitly has no close icon and lasts 2.5 seconds.
- Android evidence shows the compact pill without clipping or overlap.

