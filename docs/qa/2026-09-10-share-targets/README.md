# Invite sharing checkpoint — 10 September 2026

Current app source: `6d29c2b`, branch `fix/invite-flow-verification`. Android API 36 emulator, local QA backend, Bob Invite QA. No application changes. [Actual screenshots](index.html).

## Results

| Check | Observed result |
| --- | --- |
| Messages handoff | Selected Messages from Blab's native share sheet. Used dummy recipient 202-555-0147 only to reach the composer. Draft contains exactly `Let’s chat on Blab` followed by `https://loveblab.com/i/b33f620e5f6d`. No SMS sent. Screenshot 02. |
| Return after selecting Messages | Back returned directly to Invite a friend, with fresh token `53f152f74d40` and Send invite enabled. Screenshot 03. This proves handoff/draft/return, not recipient delivery. |
| Gmail handoff | Expanded the native sheet, selected Gmail, then its Gmail (not Chat) subtarget. Gmail onboarding opens but no email account exists, so composer payload/delivery remain unverified. Screenshot 04. Returning through Gmail onboarding left Blab's task; explicitly foregrounding the existing Blab activity restored the invite page with new token `d9630f22b5b8`. Do not count normal Gmail return as passed. |
| Native dismissal | Opened and dismissed the native sheet. Token remained `d9630f22b5b8`. |
| Native Copy | Opened sharing again and selected Copy text. Returned to the same page with fresh token `470c90189cb0`. Screenshot 05. |
| WhatsApp / Telegram | Neither installed on emulator; not tested. Owner asked to connect a signed-in Android phone for the next step. |

No real contacts were messaged and no account credentials were entered into third-party apps. Emulator networking remains enabled. Other share destinations and delivery to recipients remain open.

## Private Play test prerequisites — not an install pass

- Current production environment validation fails because `GOOGLE_WEB_CLIENT_ID`, `FIREBASE_PROJECT_ID`, and `SENTRY_DSN` are placeholders. No values copied into evidence.
- `android/key.properties` and the previously recorded external upload key are absent at their documented locations. Restore the original owner-backed-up signing material; do not silently create a replacement key. The July owner backup confirmation remains historical evidence, not proof the files exist today.
- `https://loveblab.com/.well-known/assetlinks.json` returns HTTP 404. The invite page itself still returns HTTP 200. Android reports this local app's domain state as 1024, not verified. Production association needs the actual Play app-signing certificate; do not publish the local debug certificate as a substitute.
- Latest hosted service parity, Play Console access/current track, and a latest Play-delivered package still need verification. No production changes, new release package, or Play upload performed.

All owner acceptance checkboxes stay open. Next: signed-in phone sharing tests; separately restore release prerequisites before private Play install → signup → join.
