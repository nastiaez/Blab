# Partner Profile and Reporting Design

**Status:** Approved in the Blab feedback thread on 2026-09-16.

## Goal

Replace the partner-profile bottom sheet with a normal full-screen page and give person reports and message reports distinct, honest flows. This removes stacked modal sheets while preserving accessible reporting for users and content.

## Scope

This change includes:

- a full-screen partner-profile page opened from the chat header;
- a Signal-inspired centered confirmation dialog for reporting a partner for spam;
- the existing six-reason bottom sheet only for reporting a specific message;
- the existing Block/Unblock behavior, adapted to remain on the profile page;
- English, German, Spanish, and Ukrainian copy and layout coverage.

This change does not add Mute, a blocked-people settings page, translation-error reporting, new profile fields, or a moderation dashboard.

## Partner-profile page

- Tapping the partner avatar or name in the chat header pushes a full-screen page.
- The page has a normal app bar with a localized back affordance. Back returns to the same chat and preserves its scroll, draft, reply, and edit state.
- The page keeps the existing profile information: avatar, partner name, learning language, native and learning languages, chat age, and Safety actions.
- The visual treatment follows Blab's warm app surfaces and cards rather than copying Signal's dark theme. Signal is the interaction reference, not the visual style.
- The Safety section contains exactly two rows when a partner ID exists:
  - `Report {name}`
  - `Block {name}` or `Unblock {name}`, based on live block state
- The page scrolls on small screens and with large text. No safety action may become unreachable.

The page is pushed directly from the chat with the current `Chat` model. It is not a public deep-link destination in this iteration.

## Reporting a partner

Tapping `Report {name}` opens one centered Blab-style dialog over the profile page. It does not open a reason picker.

English reference copy:

- Title: `Report spam?`
- Body: `Blab will be notified that {name} may be sending spam. Messages from this chat won't be included.`
- Actions:
  - `Report spam`
  - `Report and block`
  - `Cancel`

Nothing is submitted until the user chooses one of the two report actions. `Cancel`, the Android back action, and tapping outside the dialog dismiss it without changes.

The dialog follows Signal's compact text-first hierarchy inside Blab's warm visual system: title and body are left-aligned; the three actions are borderless text rows aligned to the right; every action uses the same warm-brown text color. The action labels carry their meaning without relying on color. The card keeps Blab's warm surface, rounded corners, and subtle outer stroke. It must not use centered marketing-style copy or full-width pill buttons.

`Report spam` submits a person report with:

- reason: `spam`;
- reported user ID: the partner ID;
- chat ID: the current chat ID;
- no message ID or message snapshot.

On success, the dialog closes, the profile page stays open, and the shared passive-success pill says the localized equivalent of `Report submitted`.

`Report and block` requests the same person report and blocks the partner. When both succeed, the dialog closes, the profile page stays open, the Block row becomes Unblock from live state, and the same `Report submitted` pill appears. The changed Unblock row is the persistent confirmation that blocking also succeeded.

## Partial failures and recovery

Report and Block are separate user intentions and are handled independently:

- If reporting fails and blocking succeeds, the profile shows Unblock and a localized report failure with a Retry action. Retry submits only the report.
- If reporting succeeds and blocking fails, the app shows `Report submitted` and a localized block failure with a Retry action. Retry performs only the block.
- If both fail, the dialog remains open and shows a localized failure without claiming success.
- Repeated taps are disabled while work is in progress so duplicate reports and block requests are not created.

The existing database validation and moderation record shape remain unchanged.

## Blocking and unblocking

- Tapping `Block {name}` opens a compact confirmation that uses the same warm card, left-aligned title/body, right-aligned borderless text actions, and single warm-brown action color as the person-report dialog.
- A successful block keeps the profile page open and changes the row to `Unblock {name}`. No additional block success pill is needed because the persistent state change is visible.
- Tapping `Unblock {name}` performs the existing unblock action. On success, the row changes back to Block and the existing localized unblock success pill appears.
- Failures keep the profile page open and show the existing localized failure feedback.
- Returning to the chat reflects the existing blocked-composer behavior immediately.

## Reporting a message

- Long-pressing an incoming message continues to expose `Report`.
- Tapping it opens the existing six-reason bottom sheet:
  - Spam or scam
  - Harassment or bullying
  - Hate speech
  - Sexual or inappropriate content
  - Child safety
  - Something else
- Selecting a reason submits that specific message report with its message ID and protected message snapshot.
- The responsive scrolling fix remains in place so every reason is reachable on short screens.
- No profile page or person-report dialog is involved in this path.

## Localization and accessibility

- All new visible copy is authored and generated for English, German, Spanish, and Ukrainian in the same commit as the UI.
- Tests render the profile and person-report dialog in all four locales and prove that every action remains visible and tappable.
- Dialog actions have at least 44 px tap targets and accessible labels.
- Destructive meaning is conveyed by copy and icons as well as color.
- The dialog fits short screens, enlarged text, and long localized names without clipping; content scrolls inside the dialog only when necessary.
- Focus remains trapped in the modal dialog while it is open and returns to the triggering Report row on dismissal.

## Verification

Automated coverage must prove:

- the chat header opens one full-screen profile page, not a bottom sheet;
- the profile page renders in all four interface languages;
- Report opens the spam confirmation and never the six-reason picker;
- Report spam writes a person report with reason `spam` and no message ID;
- Report and block performs both operations and reflects live Unblock state;
- each partial-failure case reports the truthful outcome and retries only the failed operation;
- Block and Unblock remain functional from the page;
- message long-press still opens all six localized reasons and submits a message report;
- Android back and Cancel make no changes.

Final device verification covers English, German, Spanish, and Ukrainian on Android, including a short-height viewport. One QA person report is checked in Supabase and deleted afterward; the test account and locale are restored.
