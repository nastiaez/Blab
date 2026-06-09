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
- No violence, no sexual content, no gambling, no controlled substances → **No** to all of those.
- This typically yields a **Teen / PEGI 12** rating because of open user communication. That's expected and fine.

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
