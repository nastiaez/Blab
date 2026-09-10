# Invite sharing checkpoint — 10 September 2026

Current app source: `6d29c2b`, branch `fix/invite-flow-verification`. Android API 36 emulator, local QA backend, Bob Invite QA. No application changes. [Actual screenshots](index.html).

## Results

### Final owner-approved narrowed check

Owner explicitly approved this sharing/clipboard task on 10 September after reviewing the exact text. Matching tracker entries are complete for this narrowed scope only.

Owner cancelled authentication and requested only Telegram app handoff plus exact clipboard review. Closed the pending Telegram Web password page. Selecting Telegram in Blab's native sheet dispatches `android.intent.action.SEND`, MIME `text/plain`, to `org.telegram.messenger.web/org.telegram.ui.LaunchActivity`, result code 0. Telegram immediately returns to Blab while signed out; this is a dispatch check, not a visible authenticated composer pass. Blab prepares a fresh invite.

Selected native Copy for that next invite, then used the native Paste menu in an empty local Blab draft to read the actual clipboard:

```text
Let’s chat on Blab
https://loveblab.com/i/2c0e7bee1965
```

Draft was cleared and verified empty. Nothing sent. WhatsApp is absent and untested. No further login or purchase requested; earlier login blockers below are historical.

| Check | Observed result |
| --- | --- |
| Messages handoff | Selected Messages from Blab's native share sheet. Used dummy recipient 202-555-0147 only to reach the composer. Draft contains exactly `Let’s chat on Blab` followed by `https://loveblab.com/i/b33f620e5f6d`. No SMS sent. Screenshot 02. |
| Return after selecting Messages | Back returned directly to Invite a friend, with fresh token `53f152f74d40` and Send invite enabled. Screenshot 03. This proves handoff/draft/return, not recipient delivery. |
| Gmail handoff | Expanded the native sheet, selected Gmail, then its Gmail (not Chat) subtarget. Gmail onboarding opens but no email account exists, so composer payload/delivery remain unverified. Screenshot 04. Returning through Gmail onboarding left Blab's task; explicitly foregrounding the existing Blab activity restored the invite page with new token `d9630f22b5b8`. Do not count normal Gmail return as passed. |
| Native dismissal | Opened and dismissed the native sheet. Token remained `d9630f22b5b8`. |
| Native Copy | Opened sharing again and selected Copy text. Returned to the same page with fresh token `470c90189cb0`. Screenshot 05. |
| WhatsApp / Telegram | At the initial pass neither was installed. Subsequently, at the owner's request, installed Telegram's official Android download (`https://telegram.org/android`, package `org.telegram.messenger.web`) and opened its phone-number login screen. Phone-call permission declined. Subsequent login was cancelled by the owner; the native dispatch check is recorded above. Screenshot 06. WhatsApp remains absent. |

No real contacts were messaged. Owner-provided login details and email verification were entered only into official Telegram during the subsequently cancelled login attempt; none are saved in this evidence. Emulator networking remains enabled. Untested destinations and delivery are not implied by the owner-approved narrowed check.

## Private Play test prerequisites — not an install pass

Telegram login follow-up: the owner supplied login details and the email verification code, which was accepted. Telegram then presented a UAH 28.75 one-week Premium purchase for phone SMS verification. No purchase made and no authenticated Telegram sharing pass claimed. Screenshot 07 contains the fee screen only; account identifiers and verification code are not saved here.

Owner rejected payment and SMS. Opened `https://web.telegram.org/a/`; owner scanned its QR and reached two-step password entry. Closed that page when the owner cancelled login, without entering a password. No authentication QR saved to repository. Browser Telegram verification is a separate partial check, not a substitute for Android's native share target.

- Current production environment validation fails because `GOOGLE_WEB_CLIENT_ID`, `FIREBASE_PROJECT_ID`, and `SENTRY_DSN` are placeholders. No values copied into evidence.
- `android/key.properties` and the previously recorded external upload key are absent at their documented locations. Restore the original owner-backed-up signing material; do not silently create a replacement key. The July owner backup confirmation remains historical evidence, not proof the files exist today.
- `https://loveblab.com/.well-known/assetlinks.json` returns HTTP 404. The invite page itself still returns HTTP 200. Android reports this local app's domain state as 1024, not verified. Production association needs the actual Play app-signing certificate; do not publish the local debug certificate as a substitute.
- Latest hosted service parity, Play Console access/current track, and a latest Play-delivered package still need verification. No production changes, new release package, or Play upload performed.

Owner sharing/Copy acceptance is complete for the narrowed scope. No further Telegram login work is requested. Remaining invite behavior approval and verified installed-app/private Play install → signup → join stay open.
