# UX Audit — Blab
_June 2026. Screen-by-screen issues with solutions. Go screen by screen, skip larger tasks and return to them._

Size labels: **[quick]** = copy/style tweak · **[medium]** = component work · **[large]** = structural/design-first · **[research]** = needs decision before building

---

## Screen 1 — Sign up

1. **[large] Email form on separate screen** — All fields (name, email, password) are on the same screen as the SSO button. Password and CTA require scroll. Solution: SSO button first, then "Continue with email →" opens a second screen with the form only.
2. **[quick] Mode switch placement** — "Log in" link is top-right. Solution: move to bottom of screen.
3. **[quick] CTA copy** — "Create account →" → "Join Blab →"
4. **[research] Tagline copy** — "Learn a language by chatting with a friend." needs a stronger, brand-voice version. Solution: copy research task.
5. **[quick] Error message placement** — backend error appears below form. Solution: move above the CTA button.
6. **[quick] Consent line copy** — "By creating an account you agree to our…" → "By continuing, you agree to…"
7. **[large] Onboarding flow** — new users have no idea what Blab is before signing up. Solution: design an onboarding flow (shown before or right after sign-up) explaining the concept.
8. **[medium] Terms/Privacy placement** — fine print only on sign-up screen. Solution: also show "By continuing, you agree to…" on the language picker screen for SSO users.

---

## Screen 1b — Log in

1. **[quick] Remove tagline** — log-in screen doesn't need a tagline.
2. **[quick] Mode switch placement** — same as sign-up: move "Sign up" link to bottom of screen.
3. **[medium] Match structure to sign-up** — log-in should use the same layout as sign-up (SSO first, "or use email" → separate screen with email + password form).
4. **[quick] "Forgot password?" placement** — currently below the CTA. Solution: move to directly below the password field.
5. **[quick] No account hint** — nothing tells the user which email to use. Solution: add caption "Use the email you signed up with."

---

## Screen 2 — Chat list

1. **[research] Preview text language rule** — unclear which language shows in the preview. Solution: define the rule — translations ON = show English; translations OFF = show learning language.
2. **[research] Language indicator without flags** — flags removed from tiles but nothing replaced them. Solution: research how to show which language a chat is in (text label? color? icon?).
3. **[quick] Empty state copy** — generic. Solution: "Invite a friend and start chatting."
4. **[medium] Empty state icon** — generic chat bubble. Solution: replace with Blab mark.
5. **[quick] Unread preview bold** — bold preview text on unread messages is too heavy. Solution: use badge count only, remove bold.
6. **[medium] Sort order** — verify chats sort by most recent message (last_at descending).
7. **[medium] Duplicate chats bug** — multiple entries per user pair. Solution: Step 2.9 fix (deduplicate by pair).
8. **[medium] New message FAB** — Signal/WhatsApp both have a prominent compose button on the chat list. Solution: add FAB (floating action button) for starting a new chat.

---

## Screen 3 — New chat / Invite flow

1. **[medium] Language picker style** — new chat picker uses a different style from the invite flow picker. Solution: update to card-per-language style (match Screen 6b).
2. **[research] English in language list** — open product question: what does learning English mean in Blab's pivot-English model? Solution: decide before launch.
3. **[medium] Empty space on "Send the invite"** — large dead space below the invite URL. Solution: add a simple visual element (not instructional text).
4. **[medium] Copy review on invite screen** — all copy on the "Send the invite" screen needs review.

---

## Screen 4 — Chat view

1. **[quick] Name capitalisation** — partner name renders as typed at sign-up (e.g. "aswin"). Solution: always render with first letter capitalised.
2. **[quick] Remove "Online" indicator** — Blab follows Signal's privacy model (no presence data stored or shown). Solution: remove online dot and "Online" label from chat header.
3. **[medium] Incoming bubble width** — incoming bubbles stretch full width. Solution: cap at ~75% max width (standard chat convention).
4. **[medium] Timestamp position** — timestamp sits outside the bubble. Solution: move inside bubble, bottom-right, muted colour.
5. **[medium] Attachment picker** — "+" currently limited. Solution: expand to full picker — emoji, photo, camera. Audio messages later.
6. **[quick] Menu icon** — horizontal ··· should be vertical ⋮ (Android Material standard).
7. **[medium] Auto-open keyboard** — keyboard should open automatically when a chat is empty for the first time (Signal pattern).
8. **[large] Empty chat info card** — first-time empty chat needs a card showing partner info and what you'll be doing together. Solution: design later.
9. **[large] Word tap discoverability** — user testing showed users didn't know to tap a word for translation. They long-pressed instead (triggering message menu). Also: users expect message-level action icons (play audio, copy). Solution: add subtle visual affordance on tappable words + message action icons (TTS play, copy).
10. **[medium] Tamil script vs romanisation** — users who don't know Tamil script can't read translations. Solution: add toggle in chat settings (script vs romanisation for applicable languages).
11. **[large] ··· menu expansion** — currently only Show translations + Learning language. Solution: expand to full chat settings: all media, search in messages, chat settings (colour/wallpaper, notifications), block/report (visible on scroll only, Signal pattern).
12. **[research] English-only users** — do we support users who just want to chat in English without learning a language? Needs product decision before launch.
13. **[research] Audio/video calls** — worth adding for v1? Needs scoping.

---

## Screen 5 — Profile (full redesign)

The current profile screen is being replaced. New structure decision:

**[large] Redesign Profile tab as social hub (Duolingo-style):**
1. Avatar/photo at top — tap to edit (bottom sheet: Take photo / Choose from library / Remove photo / Create avatar)
2. Name display
3. Learning languages as chips — prominent, scrollable
4. "+ Add a language" action
5. "Invite a friend" action
6. Settings gear icon top-right → opens Settings screen

**[large] New Settings screen (replaces current profile settings list):**
- Edit name
- Interface language
- Change email
- Change password
- Notifications
- Privacy
- Log out
- Delete account

---

## Screen 6 — Invite landing (valid)

1. **[quick] Remove Blab logo + language switcher** — this screen is only shown to existing users inside the app. Logo and EN picker are redundant.
2. **[quick] Remove period** — "invited you to chat." → "invited you to chat"
3. **[research] Back button on language picker** — if user backs out of "Pick a language" after tapping "Join Nastia", what happens to the invite? Do they land on chats without joining, or return to invite landing? Define before building.

---

## Screen 6 — Invite landing (expired + used)

4. **[quick] Remove Blab logo + language switcher** — same reason as valid state.
5. **[medium] Replace dead-end with CTAs** — both expired and used states offer nothing to do. Solution: add two CTAs — "Go to chats" and "Send [name] an invite instead."
6. **[quick] Inconsistent copy** — expired uses the inviter's name ("Ask Nastia for a fresh link"), used doesn't ("Ask for a fresh link"). Solution: pick one rule and apply to both.
7. **[large] Better illustration** — generic icons. Solution: replace with on-brand illustrations. Later.

---

## Screen 6b — Language picker (invite flow)

8. **[quick] Non-latin script labels** — languages like Tamil and Hindi are unrecognisable to learners who don't know the script. Solution: add latin name in parentheses → "தமிழ் (Tamil)", "हिन्दी (Hindi)". Apply to ALL language pickers across the app.
9. **[quick] Tap animation** — gray flash before orange on selection. Solution: fix to go directly to orange (or brand selection colour).
10. **[medium] All language pickers → same style** — new chat picker and interface language picker don't match this screen. Solution: update all to card-per-language style.
11. **[research] Scroll discoverability** — not obvious more languages are below. Solution: user testing needed; may need a scroll hint.
12. **[large] Non-Blab user invite flow** — when Nastia shares the invite link to someone without the app, the link opens in a browser. Needs: web landing page (invite context + value prop + app store links) + deep link handoff after install. Design task.
13. **[research] Language display for non-latin interfaces** — if a user picks Hindi as interface language, do all language names show in Hindi? What's the right approach? Research how Duolingo and Google Translate handle this.

---

## Screen 8 — Edit profile (redesign)

Full redesign to Signal pattern (replaces current screen):

1. **[medium] Avatar with camera badge** — camera icon overlay on avatar; tap avatar or badge → bottom sheet (Take photo / Choose from library / Remove photo / Create avatar).
2. **[medium] Two name fields** — First name (auto-focuses, keyboard opens on entry) + Last name (optional).
3. **[medium] About / Bio field** — optional text area.
4. **[medium] Floating Save button** — floats above keyboard when open; pins to bottom of screen when keyboard is closed.
5. **[quick] Avatar initials colour** — currently purple/muted. Solution: use brand orange.

---

## Screen 9 — Change password

1. **[quick] "Forgot your password?" placement** — currently below Save button. Solution: move to directly below Current password field.
2. **[medium] Confirm password blur validation** — mismatch error only shows on submit. Solution: validate on blur (when user leaves the Confirm field).
3. **[quick] Strength bar on empty state** — bar only appears while typing. Solution: show faint empty bar on focus so users know it's there.
4. **[research] Single-field-per-screen** — Signal puts each field on its own screen for settings flows. Consider splitting Change password into steps. Research and test which is better for mobile.

---

## Screen 10 — Change email

1. **[medium] CTA only in nav bar** — "Send" is top-right, hard to reach. Solution: add CTA button on screen body, floating above keyboard.
2. **[quick] Current email looks editable** — same white card style as the input below it. Users will try to tap it. Solution: read-only style — gray background, no border.
3. **[quick] Shorten helper text** — "We'll send a confirmation link. Your old email stays active until you confirm."

---

## Screen 11 — Privacy

1. **[research] What belongs here** — typing indicators and read receipts may belong in Notifications instead. Research what should stay on Privacy vs move.
2. **[quick] Fix last-line copy** — "These two toggles control what your phone shares with our servers" is inaccurate (they control what other users see, not server data). Rewrite or remove.
3. **[research] E2E encryption disclosure** — "End-to-end encryption isn't in this version yet — it's on the way." Decide: keep for transparency or cut to avoid concern?
4. **[research] Legal links placement** — Privacy Policy + Terms appear here and are planned in Help too. Decide: one place only, or intentionally both?
5. **[medium] Simplify overall** — too many elements and too much text. Reduce density once content decisions above are made.

---

## Screen 12 — Forgot password

1. **[quick] CTA copy** — "Send reset link" implies the user is sending. Solution: "Email me a reset link →"
2. **[quick] Remove subtitle** — "Enter the email you signed up with — we'll send you a reset link." becomes redundant once CTA copy is clear. Solution: remove.

---

## Screen 13 — Interface language

1. **[medium] Update style** — uses compact list inside one card. Solution: update to card-per-language style (match Screen 6b language picker).
2. **[quick] Non-latin script labels** — same as Screen 6b issue 8: add latin name in parens.
3. **[research] Subtitle accuracy** — "Used across menus and buttons" may not be fully accurate if app isn't completely localised. Revisit once localisation scope is clear.

---

## Screen 14 — Delete account

1. **[quick] Warning icon colour** — orange ⚠ icons on a destructive screen feel off-brand. Solution: use red.
2. **[quick] "This is permanent" prominence** — most critical message is small and muted at top. Solution: make it larger or bold.
3. **[quick] Copy** — "Your settings and language picks" → "Your settings and preferences."
4. **[medium] SSO user confirmation** — users who signed up with Google have no password. Solution: show a different confirmation flow (re-authenticate with Google, or type "DELETE").
5. **[medium] What happens to partners** — no explanation of effect on other users. Solution: add "Your partners will no longer be able to message you."

---

## Global — cross-screen

1. **[large] Snackbar + popup audit** — review every snackbar in the app (interface language switch "Switched to… Undo", message deleted, copied, offline banner, failed-send sheet). For each: is it needed? Is the copy right? Is timing right? Then redesign UI of snackbar and the offline banner popup.
2. **[large] Navigation restructure** — Profile tab becomes social hub, settings move behind gear icon. Needs wireframing before building (affects Profile, Edit profile, and all settings screens).
3. **[large] Onboarding flow** — design the first-run experience explaining what Blab is and how it works.
4. **[medium] Arrow convention on CTAs** — all primary CTAs should end with " →". Audit and apply consistently across all screens.
5. **[research] "Open a chat" in dev menu doesn't load** — investigate and fix the dev route.
6. **[research] Vertical ··· menu in chat list header** — most messengers have a ⋮ top-right that opens settings/filters. Blab has settings elsewhere (profile tab). Decide: do we need a ⋮ menu on the chat list, and if so what goes in it?

---

## Open product questions (no build until decided)

- English in the language list — what does learning English mean in Blab?
- English-only users — do we support chatting without language learning?
- Audio/video calls — scope for v1?
- Back button on language picker in invite flow — cancel join or return to invite?
- Single-field-per-screen for settings flows — research needed
- Language display for non-latin interface languages — research needed
- Scroll discoverability on language pickers — user testing needed
- E2E encryption disclosure on Privacy screen — keep or cut?
- Legal links — one location or two?
