# Play Store listing + Data Safety — draft (Step 3.5)

Everything below is ready to paste/click into the Play Console. It matches
the hosted Privacy Policy (`web/privacy.html`) exactly — keep them in sync.

> Two things only you can supply are marked **[YOU]**.

---

## Store listing

**App name:** Blab

**Short description** (≤ 80 chars):
> Chat with a friend and learn their language — every message, translated.

**Full description:**
> Blab is the simplest way to learn a language: just chat with someone who
> speaks it.
>
> Invite a friend, pick the language you each want to practise, and start
> texting. Every message is translated for you, with tap-to-hear
> pronunciation and a tap-any-word breakdown so you actually learn as you
> chat — not just copy and paste.
>
> • Real conversations, not flashcards
> • Tap any word to see what it means and hear it spoken
> • Each of you sees the chat in the language you're learning
> • Clean, quiet, no streaks or guilt
>
> Blab works best between two people who already know each other and want to
> help each other learn. Invite someone with a single link and start.
>
> Note: this version does not yet use end-to-end encryption (it's planned).
> Your messages travel over a secure connection and are stored on protected
> servers in the EU. We don't show ads or sell your data.

**Category:** Education *(recommended — the value prop is learning; Communication is the alternative)*

**Tags/keywords:** language learning, language exchange, chat, translate

**Contact email:** me@aswin.sh

**Privacy Policy URL:** https://blab-gray.vercel.app/privacy.html
*(swap to the real domain when Step 3.7 lands)*

---

## Graphics needed

- **App icon** — ✅ already shipped (adaptive icon generated).
- **Phone screenshots** — reuse the Track A portfolio shots (`docs/portfolio/`). Need 2–8, 16:9 or 9:16.
- **Feature graphic** 1024×500 — **[YOU]** needs designing. Suggestion: the Blab wordmark on the cream background with one translated chat bubble.

---

## Data Safety form (exact answers)

Google asks, section by section. Answer like this:

**Does your app collect or share any of the required user data types?** → **Yes**

**Is all of the user data collected by your app encrypted in transit?** → **Yes**

**Do you provide a way for users to request that their data is deleted?** → **Yes** (in-app: Profile → Delete account)

### Data types — collected (none "shared" in Google's sense; providers below are processors acting on our behalf only)

| Data type | Collected | Purpose | Notes |
|---|---|---|---|
| Email address | Yes | Account management, app functionality | Not shared |
| Name | Yes | App functionality (display name) | Not shared |
| Photos (optional) | Yes | App functionality (profile picture) | Only if the user sets one |
| Messages (in-app) | Yes | App functionality | Stored to deliver chats; text sent to a translation provider to produce translations |
| Crash logs | Yes | Diagnostics / app stability | Scrubbed — no message content |
| App interactions | Yes | App functionality | Read/typing state per the privacy toggles |

For each row, when asked "Is this data shared with third parties?" → **No**
(service providers that only process on our behalf — Supabase, the translation
provider, Sentry — are not "sharing" under Google's definition).

When asked "Is this data processed ephemerally?" → No for messages (stored),
crash logs (sent to Sentry).

**Security practices:**
- Data is encrypted in transit → Yes
- Users can request deletion → Yes
- Committed to Play Families Policy → not a kids app; declare 13+

---

## Content rating questionnaire

Answer honestly — Blab has user-to-user messaging:
- Users can interact / communicate with each other → **Yes**
- Users can share content (messages) → **Yes**
- Users can share their location → **No**
- No violence, no sexual content, no gambling, no controlled substances in the app's own content → **No** to all of those.
- Note: messages are translated faithfully, so user-typed profanity may appear in translation. That's user-generated, not app content.
- This typically yields a **Teen / PEGI 12** rating because of open user communication. Expected and fine.

**Minimum age:** 13+ (stated in Terms + confirmed at signup).

---

## Child safety / CSAE (required for social apps)

Google Play requires apps with social features to declare child-safety standards
and a reporting path. We have:
- A **zero-tolerance CSAE** section in the Terms (`/terms.html#child-safety`).
- **In-app Report + Block** (Step 3.6a).
- A **point of contact**: me@aswin.sh.

In Play Console:
- **App content → Child safety standards**: provide the Terms URL (the CSAE
  section) as the published standards, and me@aswin.sh as the contact.
- Affirm compliance with Google's CSAE policy when prompted.

---

## Demo account for the Play reviewer  **[YOU]**

Play reviewers need a working login. Create one throwaway account and note it
here before submitting:
- Email: __________
- Password: __________
- (Optionally seed one chat so the reviewer sees the core flow.)

---

## Closed-testing note (Step 3.6)

Play now requires **12+ testers opted in for 14 continuous days** before
production. Line up the tester emails early — that 14-day clock is the only
thing on this whole list you can't speed up. Invite copy is in
`docs/tester-invite.md`.

---

## ✅ Final checklist before you hit "Publish" on Play

Do these last, right before submitting to production:

- [ ] **Run the full manual test pass** on a real phone (`docs/manual-test-plan.md`), ideally on the signed release build. Don't submit until it passes.
- [ ] **Fill the operator legal name** in `web/privacy.html` — replace
      `[OPERATOR NAME]` (location is already set to Berlin, Germany). This is
      legally required (GDPR controller identity). Re-deploy the page after.
      *No EU representative needed — the operator is based in the EU.*
- [ ] Deploy `web/privacy.html` + `web/terms.html` (Vercel) and confirm both
      open in a browser.
- [ ] Paste the Privacy Policy URL into the Play listing.
- [ ] Fill the **Data Safety** form using the answers above.
- [ ] Complete the **content rating** questionnaire (lands at Teen).
- [ ] Fill **Child safety standards** (Terms `#child-safety` URL + me@aswin.sh).
- [ ] Upload the **feature graphic** (1024×500) + screenshots.
- [ ] Add the **reviewer demo account** credentials.
- [x] **Sentry DSN** set (in gitignored `env/sentry.json`; builds use `--dart-define-from-file=env/sentry.json`).
- [ ] Confirm **Report + Block** is live in the build (Step 3.6a).
- [ ] Closed test: **12+ testers, 14 continuous days** complete.

---

## Release signing (one-time keystore)  [YOU]

The app build is Play-ready, but the release must be signed with YOUR upload
key (currently it falls back to the debug key). One-time setup:

1. Create an upload keystore (keep it safe + backed up — losing it means you
   can't update the app):
   ```
   keytool -genkey -v -keystore ~/blab-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (already gitignored — never commit it):
   ```
   storePassword=<the password you set>
   keyPassword=<the password you set>
   keyAlias=upload
   storeFile=/Users/anastasiiayezhyzhanska/blab-upload.jks
   ```
3. Build the signed bundle for upload:
   ```
   flutter build appbundle --release --dart-define-from-file=env/sentry.json
   ```
   → upload `build/app/outputs/bundle/release/app-release.aab` to Play.
4. Enable **Play App Signing** (Play's default). After the first upload, copy
   the **app-signing SHA-256** from Play Console → and update
   `web/.well-known/assetlinks.json` with it so invite App Links verify on
   production builds (the file currently lists the debug fingerprint).
