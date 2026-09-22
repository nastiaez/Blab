# Email Change Success Feedback Design

## Decision

Show the shared passive-success pill only after Blab verifies that the signed-in account's email address actually changed.

## Presentation

- Leading 20 px check-circle icon.
- Localized `Email changed` message.
- No trailing textual checkmark and no close icon.
- Automatic dismissal after 2.5 seconds; swipe remains available.
- Present on the Profile destination after the confirmation flow settles.

## Behavior

- A confirmation deep link may consume the Supabase session and return to Profile, but the route itself does not prove success.
- Blab compares the same signed-in user's previous and refreshed email values before announcing success.
- Account switches, initial sign-in, unchanged refreshes, and direct visits to `/auth/email-changed` do not announce success.
- Browser-swallowed redirects remain covered by the existing app-resume refresh fallback.
- Multiple signals from the same confirmation produce one acknowledgement because the stored email baseline is updated immediately.

## Acceptance

- Genuine email confirmation shows the shared success pill in English, German, Spanish, and Ukrainian.
- Opening the callback route without an email change shows no success message.
- The pill survives the return navigation, disappears after 2.5 seconds, and contains no X or trailing checkmark.
