# Clickable settings retry

**Status:** Approved by owner on 2026-09-21
**Scope:** Inline save failures on Privacy and Translation Preferences.
**Principle:** If the whole failure sentence looks like one action, the whole sentence behaves like one action.

## Problem

Privacy uses different copy from Translation Preferences, and neither failure line clearly performs the recovery it describes. Asking users to tap or click would add instructional copy without making the interaction clearer.

## Approved interaction

- Both screens show the existing localized **Couldn’t save. Try again.** message.
- The complete bold sentence is one tappable retry action, not only the final phrase.
- The visible line keeps the existing quiet below-card placement and warm error styling.
- Its invisible touch target is at least 48 dp tall.
- Accessibility exposes the whole sentence as one button and announces the failure as a live-region update.
- Do not add “Tap” or “Click” to the copy.

## Retry behavior

- A failed save rolls the visible control back to its last saved value.
- The screen retains the exact rejected change.
- Tapping the error line retries that rejected change without asking the user to select it again.
- While retrying, the action cannot be triggered twice.
- Success applies the requested value and removes the error line.
- Another failure keeps the prior saved value and leaves the retry action visible.

Examples:

- Privacy: turning Typing indicators off fails, so the switch returns on. Tapping the error retries turning it off.
- Translation Preferences: choosing Feminine fails, so Masculine remains visible. Tapping the error retries Feminine.

## Localization and scope

- Reuse the current `couldNotSavePreference` translations in English, German, Spanish, and Ukrainian.
- Do not edit locale catalogs or introduce a second Retry label.
- Do not change Profile load recovery or any other settings layout.

## Acceptance

- Privacy and Translation Preferences use identical localized failure copy and interaction.
- The whole visible sentence activates one retry with a 48 dp minimum touch target.
- The retry replays the exact failed value once and prevents duplicate saves.
- Successful retry updates the control and removes the error.
- Failed retry keeps the saved value and actionable error visible.
- Android screenshots confirm the final states before implementation is committed.
