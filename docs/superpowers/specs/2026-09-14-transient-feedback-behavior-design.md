# Transient Feedback Behavior Design

**Status:** Approved by the owner on 2026-09-14; redundant Save/Apply feedback rule approved on 2026-09-15.

## Goal

Make interface-language feedback compact, readable in every launch locale, and predictable when the user continues navigating.

## Behavior

- Automatically disappearing Snackbars have no close icon. The close icon is reserved for a future persistent notice that cannot time out.
- A language-change Snackbar contains the localized success message and one localized **Undo** action.
- Actionable Snackbars remain visible for 4 seconds. Passive confirmations remain visible for 2.5 seconds.
- The user may dismiss a Snackbar by swiping it away. Pressing its action also dismisses it.
- A new Snackbar replaces the visible one.
- Moving to a different route, including Back, dismisses the visible Snackbar immediately. An unrelated tap on the current route does not dismiss it, so the Undo target cannot disappear accidentally.
- Route-triggered dismissal runs after Navigator build and applies only to feedback that existed when navigation began. Feedback created by the destination after that navigation must survive.
- The interface-language success message, language name, and Undo label are all built from the successfully saved target locale. The previous locale must not leak into the confirmation.
- Edit Profile and Known Languages do not show success Snackbars. Both use an explicit Save/Apply action and reveal the updated value immediately after returning, so another confirmation is redundant. A failed action stays on the editing surface with its existing error feedback.

## Layout and localization

- The message may wrap naturally and must not be truncated.
- The four launch interface locales, English, Ukrainian, German, and Spanish, must remain at no more than two message lines at the supported phone width and default text size.
- Removing the close icon preserves horizontal room for the single action and prevents avoidable action overflow.
- Enlarged accessibility text may increase the Snackbar height; readable content and a reachable action take priority over forcing a one-line layout.

## Scope

This change updates shared transient-feedback behavior, the interface-language confirmation, and the two approved no-success-feedback flows. It does not redesign Snackbar colors, shape, typography, failure copy, offline banners, inline recovery, or message-level recovery; those remain part of the later feedback-state redesign.

## Acceptance checks

- No close icon appears on automatically disappearing Snackbars.
- Passive and actionable durations are 2.5 seconds and 4 seconds respectively.
- Back, push, replace, and remove navigation dismiss the visible Snackbar.
- Route dismissal produces no build-phase framework error and does not remove newer destination feedback.
- Ordinary taps do not dismiss it; swipe and action do.
- Successful Edit Profile and Known Languages actions return with the updated value visible and no success Snackbar; their failure paths remain on the editing surface.
- Every directed switch among the four interface locales uses the target locale for the message, language name, and Undo label.
- Android screenshots show the language-change Snackbar in English, Ukrainian, German, and Spanish without clipping, overlap, or avoidable action stacking.
