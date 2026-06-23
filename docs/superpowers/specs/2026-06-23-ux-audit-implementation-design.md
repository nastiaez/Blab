# UX Audit Implementation Design
_2026-06-23. Screen-by-screen fixes from `tasks/ux-audit.md`. Skips all [research] items — those are blocked on open product decisions._

---

## Scope

All [quick], [medium], and [large] items from the audit, tackled screen by screen in the order below. [research] items excluded entirely.

Within each screen: [quick] → [medium] → [large].

---

## Screen order

### 1. Screen 6 — Invite landing (valid + expired + used)
Files: `invite_landing_screen.dart`, `invite_pick_language_screen.dart`

**[quick]**
- Remove Blab logo and EN language switcher from all three states (valid, expired, used) — they're only shown to existing logged-in users, so redundant
- Remove trailing period: "invited you to chat." → "invited you to chat"
- Fix inconsistent copy: expired uses inviter's name, used doesn't — apply name to both: "Ask [name] for a fresh link"

**[medium]**
- Replace dead-end expired + used states: add two CTAs — "Go to chats" and "Send [name] an invite instead"

---

### 2. Screen 6b — Language picker (invite flow + all pickers)

**[quick]**
- Non-latin script labels: add latin name in parens for all non-latin languages everywhere in the app (e.g. "தமிழ் (Tamil)", "हिन्दी (Hindi)"). Apply to: invite flow picker, new chat picker, interface language picker, change-language sheet.
- Tap animation: remove gray flash on selection, go directly to brand orange

**[medium]**
- Unified card-per-language style: update new-chat picker and interface language picker to match invite flow card style (one card per language, full-width, with flag + name)

---

### 3. Screen 12 — Forgot password

**[quick]**
- CTA copy: "Send reset link" → "Email me a reset link →"
- Remove subtitle: "Enter the email you signed up with — we'll send you a reset link." (redundant once CTA is clear)

---

### 4. Screen 1b — Log in

**[quick]**
- Remove tagline from log-in screen
- Move "Sign up" link from top-right → bottom of screen
- Move "Forgot password?" from below CTA → directly below the password field
- Add caption below email field: "Use the email you signed up with."

**[medium]**
- Match structure to sign-up: SSO first, then "Continue with email →" opens a separate screen with email + password form only

---

### 5. Screen 1 — Sign up

**[quick]**
- Move "Log in" link from top-right → bottom of screen
- CTA copy: "Create account →" → "Join Blab →"
- Move backend error from below form → above the CTA button
- Consent copy: "By creating an account you agree to our…" → "By continuing, you agree to…"

**[medium]**
- Terms/Privacy: also show "By continuing, you agree to…" on the language picker screen (for SSO users who skip the form)

**[large]**
- Email form on separate screen: SSO button first, then "Continue with email →" opens a second screen with name + email + password form only. Password and CTA no longer require scroll.

---

### 6. Screen 2 — Chat list

**[quick]**
- Empty state copy: current generic text → "Invite a friend and start chatting."
- Remove bold on unread message preview text — use badge count only for unread indicator

**[medium]**
- Empty state icon: replace generic chat bubble with Blab mark
- Sort order: verify chats sort by most recent message (last_at descending)
- Deduplicate chats bug: multiple entries per user pair — fix deduplication by pair (Step 2.9 logic)
- Add FAB (floating action button) for new chat, bottom-right, matches Signal/WhatsApp pattern

---

### 7. Screen 3 — New chat / Invite flow

**[medium]**
- Language picker: update to card-per-language style (matches Screen 6b after that fix)
- Dead space: add simple visual element below invite URL (not instructional text)
- Copy review: rewrite all copy on the "Send the invite" screen

---

### 8. Screen 4 — Chat view

**[quick]**
- Name: always render partner name with first letter capitalised (e.g. "aswin" → "Aswin")
- Remove "Online" indicator: remove presence dot and "Online" label from chat header (Signal privacy model)
- Menu icon: horizontal ··· → vertical ⋮ (Android Material standard)

**[medium]**
- Incoming bubble width: cap at ~75% max width (standard chat convention)
- Timestamp: move inside bubble, bottom-right, muted colour
- Attachment picker: expand "+" to full picker — emoji, photo, camera (audio later)
- Auto-open keyboard: keyboard opens automatically on first visit to an empty chat (Signal pattern)
- Tamil script toggle: add toggle in chat settings for script vs romanisation (for applicable non-latin languages)

**[large]**
- Empty chat info card: first-time empty chat shows a card with partner info and what you'll be doing together. Design separately before building.
- Word tap discoverability: add subtle visual affordance on tappable words + message action icons (TTS play, copy) — design + user test before building
- ··· menu expansion: full chat settings — all media, search in messages, chat settings (colour/wallpaper, notifications), block/report (visible on scroll only, Signal pattern). Design separately.

---

### 9. Screen 8 — Edit profile

**[quick]**
- Avatar initials colour: change from purple/muted → brand orange

**[medium]**
- Avatar with camera badge: camera icon overlay; tap avatar or badge → bottom sheet (Take photo / Choose from library / Remove photo / Create avatar)
- Two name fields: First name (auto-focuses) + Last name (optional)
- About / Bio field: optional text area
- Floating Save button: floats above keyboard when open; pins to bottom when keyboard closed

---

### 10. Screen 9 — Change password

**[quick]**
- Move "Forgot your password?" from below Save button → directly below Current password field
- Strength bar: show faint empty bar on focus (not just while typing)

**[medium]**
- Confirm password blur validation: validate mismatch on blur (when user leaves the Confirm field), not only on submit

---

### 11. Screen 10 — Change email

**[quick]**
- Current email style: read-only styling — gray background, no border (prevents users trying to tap it)
- Shorten helper text: "We'll send a confirmation link. Your old email stays active until you confirm."

**[medium]**
- Add CTA button in body: "Send" is currently top-right nav only — add floating CTA button above keyboard

---

### 12. Screen 11 — Privacy

**[quick]**
- Fix last-line copy: "These two toggles control what your phone shares with our servers" → rewrite to accurately describe that they control what other users see

**[medium]**
- Simplify overall: reduce density — fewer elements, less text. Defer until content decisions ([research] items) are resolved.

---

### 13. Screen 13 — Interface language

**[quick]**
- Non-latin script labels: same fix as Screen 6b — add latin name in parens

**[medium]**
- Update style: compact list inside one card → card-per-language style (matches invite flow picker after that fix)

---

### 14. Screen 14 — Delete account

**[quick]**
- Warning icon colour: orange ⚠ → red ⚠
- "This is permanent" prominence: make larger or bold
- Copy: "Your settings and language picks" → "Your settings and preferences."

**[medium]**
- SSO user confirmation: users who signed up with Google have no password — show different confirmation flow (re-authenticate with Google, or type "DELETE")
- Partner impact: add "Your partners will no longer be able to message you."

---

### 15. Global

**[medium]**
- Arrow convention: all primary CTAs end with " →". Audit and apply consistently across all screens.

**[large]** (design-first, deferred within this track)
- Snackbar + popup audit: review every snackbar, redesign UI. Design before building.
- Navigation restructure: Profile tab → social hub, settings behind gear icon. Wireframe first.
- Onboarding flow: first-run experience. Design before building.
- Screen 5 (Profile): full redesign. Last.

---

## What's excluded

- All [research] items — blocked on open product decisions (see `tasks/ux-audit.md` § Open product questions)
- Screen 4 [large] items (empty chat card, word tap, menu expansion) — design-first
- Screen 5 (Profile redesign) — structural, goes last after navigation restructure is designed
- Global [large] items — all design-first

---

## Implementation notes

- Non-latin script label fix applies globally — one change, multiple screens. Implement once, verify everywhere.
- Language picker card style — same: implement once (shared widget), update all three pickers to use it.
- All [quick] items are copy/style only — no new components needed.
- Screen 1 [large] (email separate screen) requires new route + screen. Significant scope. Do last within Screen 1.
