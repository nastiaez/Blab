# PRD: Blab — Language Exchange Chat App

## Introduction

Blab is a peer-to-peer language exchange app. Two people teach each other their native languages through real conversations. People can write in any language. Practice shows the viewer's learning-language result; Normal shows authored text the reader knows and a primary-known-language translation when they do not. Exact authored text remains authoritative and is available through Normal's Original action whenever the displayed text differs. The app is built around mutual exchange — not courses, not AI conversation partners, not tutors. Real people, real chat.

This document captures the full scope as prototyped across 4 phone flows.

---

## Goals

- Let two people start a language exchange in under 60 seconds
- Make every message a learning opportunity (tappable words, inline translations)
- Show both sides of the exchange symmetrically (each person is both teacher and learner)
- Keep the chat UX familiar (WhatsApp/iMessage feel) so there's no learning curve

---

## Flows Overview

| Flow | Screen | POV |
|------|--------|-----|
| Flow 1 | Auth | Any new user |
| Flow 2 | Main App — Chats + Profile | Nastia (existing user) |
| Flow 3 | Chat view | Nastia (learning Tamil from Aswin) |
| Flow 4 | Invite + Join + Chat | Aswin (new user, learning Ukrainian) |

---

## User Stories

### FLOW 1 — Authentication

---

### US-001: Sign up with email
**Description:** As a new user, I want to create an account with my name, email, and password so I can access Blab.

**Acceptance Criteria:**
- [ ] Screen shows "Sign up" tab active by default
- [ ] Fields: name, email, password
- [ ] Name field hidden when "Log in" tab active
- [ ] Email validated on blur — shows inline error "Enter a valid email address" if invalid
- [ ] Password shows strength bar below field (Weak / Fair / Strong) during signup
- [ ] Password field has show/hide eye toggle
- [ ] Empty field on submit shows inline error per field
- [ ] CTA: "Create account →" (signup) / "Log in →" (login)
- [ ] Successful submit navigates to main app (Phone 2)

---

### US-002: Log in with email
**Description:** As a returning user, I want to log in with my email and password.

**Acceptance Criteria:**
- [ ] Tapping "Log in" tab hides name field, shows "or log in with email" divider
- [ ] "Forgot password?" link appears below CTA in login mode
- [ ] Successful login navigates to main app

---

### US-003: SSO — Apple / Google
**Description:** As a user, I want to sign up or log in with Apple or Google to skip the form.

**Acceptance Criteria:**
- [ ] Two SSO buttons above email form: "Continue with Apple", "Continue with Google"
- [ ] Either button skips all fields and goes directly to main app
- [ ] Apple + Google logos render correctly

---

### US-004: Forgot password
**Description:** As a user who forgot their password, I want to request a reset link via email.

**Acceptance Criteria:**
- [ ] "Forgot password?" link visible only in login mode
- [ ] Tapping opens Forgot Password screen with email field (pre-filled)
- [ ] Tapping "Send reset link →" navigates to confirmation screen
- [ ] Confirmation shows 📬 icon + "Check your email" + email address
- [ ] "Back to log in" link returns to login tab

---

### US-005: Interface language selector
**Description:** As a user, I want to set my interface language before or during sign up.

**Acceptance Criteria:**
- [ ] Globe icon 🌐 with language code (e.g. "EN") in top-right of auth screen
- [ ] Tapping opens a bottom sheet containing English, Ukrainian, German, and Spanish
- [ ] English is the first-launch default and fallback; selecting another language updates all localized app chrome
- [ ] Same sheet accessible from Profile → Interface language
- [ ] The pre-auth choice persists locally; a signed-in choice persists to that account without leaking across logout/account switches
- [ ] Switching the interface language immediately re-renders localized word-popup definitions from a cache keyed by both learning and interface language (no app restart, no stale locale)

---

### FLOW 2 — Main App (Chats + Profile)

---

### US-006: Chat list
**Description:** As a user, I want to see all my active language exchange chats in one list.

**Acceptance Criteria:**
- [ ] "Chats" tab active by default
- [ ] Each chat item shows: avatar (initial), name, last message preview, timestamp, unread badge
- [ ] Tapping a chat opens the chat view (Phone 3)
- [ ] "+" button in top-right navigates to Invite a friend
- [ ] A newly claimed connection appears in the same priority position as an unread message with preview `Ready to chat · Say hi`; it remains unread until that participant chooses a practice language

---

### US-007: Empty state — no chats
**Description:** As a new user with no chats, I want to see a clear prompt to start one.

**Acceptance Criteria:**
- [ ] If no chats, show empty state: 💬 icon + "No chats yet" + subtitle + "Invite someone" button
- [ ] Button navigates to Invite a friend

---

### US-008: Invite a friend
**Description:** As a user, I want to send one clear invite link so a friend can join Blab and start a chat with me.

**Acceptance Criteria:**
- [ ] Entry points are Chats + and the no-chats `Invite someone` action; there is no contacts screen, contacts permission, or language picker before this page
- [ ] Header: `Invite a friend`; link card: `Let’s chat on Blab` + `loveblab.com/i/{token}`; helper below the card, without a bullet: `Only one friend can use this link`
- [ ] Primary `Send invite` button has no icon and opens the native share sheet
- [ ] The shared text is `Let’s chat on Blab` plus the invite URL
- [ ] Returning from Copy or another app returns to this same page, not Chats; no success page is shown
- [ ] Every exposed link is unique and remains valid until one successful claim; a fresh link is prepared after Copy or a selected share target
- [ ] The first link is prepared in the background for a signed-in online user, so the first visit normally opens ready to share
- [ ] While offline, the standard `No connection` banner is visible and `Send invite` is disabled; no special offline card or second banner is shown
- [ ] If preparing the next link fails while online, show inline `Couldn’t prepare a new invite. · Try again` below the card and keep `Send invite` disabled until it succeeds

---

### US-009: Share sheet
**Description:** As a user, I want to share my invite link via popular messaging apps.

**Acceptance Criteria:**
- [ ] Blab opens the device's native share sheet, including that platform's Copy affordance and confirmation
- [ ] The operating-system sheet uses its standard scrim and return behavior; Blab does not build a second custom sheet
- [ ] Dismissing the native sheet without copying or choosing a target leaves the current link in place

---

### US-010: Profile screen
**Description:** As a user, I want to view and manage my profile.

**Acceptance Criteria:**
- [ ] Profile tab shows hero section: static avatar initial and persisted display name
- [ ] Settings card (one container, dividers): Interface language | Edit profile | Change email | Change password | Log out
- [ ] "Interface language" row shows current language name in purple, tapping opens language sheet
- [ ] "Edit profile" navigates to Edit Profile screen
- [ ] "Change email" navigates to Change Email screen (US-039)
- [ ] "Change password" navigates to Change Password screen
- [ ] Tapping "Log out" first opens a confirm dialog (title: "Log out?", buttons: Cancel + Log out); only on confirm does it sign out and return to auth screen with all fields reset
- [ ] Learning language is shown only within its chat because it is a per-chat setting

---

### US-011: Edit profile
**Description:** As a user, I want to update my display name.

**Acceptance Criteria:**
- [ ] Nav: back (‹) | "Edit profile" title | "Save" (top right)
- [ ] Static initial avatar is shown without photo actions or upload affordances
- [ ] "DISPLAY NAME" label above bordered text input pre-filled with current name
- [ ] Tapping "Save" in nav returns to profile + shows a "Profile updated ✓" toast (matches the toast pattern from Change password)

---

### US-012: Change password
**Description:** As a user, I want to change my password securely.

**Acceptance Criteria:**
- [ ] Fields: Current password, New password (with strength bar), Confirm new password
- [ ] All password fields have show/hide toggle
- [ ] "Save" button submits; returns to profile with toast "Password updated ✓"
- [ ] "Forgot your password?" link at bottom opens forgot-password flow

---

### US-039: Change email
**Description:** As a user, I want to fix or change the email on my account — primarily to recover from a typo at signup, but also if I switch addresses.

**Why:** Signup is intentionally low-friction with no email-confirmation gate (see Resolved Decisions in `tech-spec.md`). The cost is that a typo'd address survives signup, and the user later can't receive password resets or notifications. This flow is the deliberate fix-path.

**Acceptance Criteria:**
- [ ] Entry point: a "Email" row on the Edit profile screen, below Display name, showing the current email + chevron
- [ ] Tapping opens the Change email screen: back arrow + "Change email" title
- [ ] Top: read-only "Current email" pill with the existing address
- [ ] "New email" text field with email-keyboard, inline validation (empty / invalid format / same as current)
- [ ] Helper text under the field: "We'll send a confirmation link to the new address. Your email only changes after you tap it. Old email keeps working until then."
- [ ] Brand-purple "Send confirmation" CTA, spinner while in flight
- [ ] On success the screen swaps to a "Check your inbox" confirmation (📬 + new address + Done)
- [ ] Tapping the link in the new inbox opens Blab and shows a "Email changed ✓" toast
- [ ] Old email continues to log in until the link in the new inbox is tapped
- [ ] Works for both password-auth and Google-auth accounts

---

### FLOW 3 — Chat View (Nastia's POV, learning Tamil)

---

### US-013: Chat header
**Description:** As a user in a chat, I want to see who I'm talking to.

**Acceptance Criteria:**
- [ ] Nav: back (‹) | avatar + vertically centered name | Normal/Practice switch | ··· menu button
- [ ] No online / "last seen" indicator — Blab does not ship presence as a feature (privacy posture, see § Privacy)
- [ ] The name temporarily gains a second line reading "typing…" (brand color) while the partner is typing AND both sides have the typing-indicator toggle ON; it returns to vertical center when typing stops (see § Privacy)
- [ ] Header identity uses a 36 px avatar with the approved warm palette and subtle shadow; back icon → avatar and avatar → name are both 10 px; name is 15 px heavy, 18 px line height, `#46281C`
- [ ] The entire Normal/Practice switch is one tap target; tapping anywhere on the control always flips to the other mode
- [ ] Back navigates to chat list

---

### US-014: ··· chat menu
**Description:** As a user, I want quick access to translation and correction settings from within the chat.

**Acceptance Criteria:**
- [ ] Tapping ··· opens dropdown menu below nav
- [ ] Menu: "Show translations and corrections" toggle (green = on) + "Learning language [name] ›"
- [ ] Menu auto-width (no wrapping on long language names)
- [ ] Tapping outside closes menu
- [ ] The floating menu uses `#FFFCF8` fill, 1 px `#E1DAD2` outline/divider, 14 px radius, a subtle `#231208` 10% shadow at y 2 / blur 12, 52 px rows, regular 15 px `#46281C` labels, regular 14 px `#917869` values, and supplied 20 px `#917869` right arrows
- [ ] The toggle hides/shows learning-aid rows in the message area only
- [ ] "Learning language ›" opens change-language bottom sheet

---

### US-015: Messages — translations and corrections
**Description:** As a learner, I want each message to show the right language for my selected mode without losing the authored text or making a correction feel punitive.

**Acceptance Criteria:**
- [ ] Incoming bubbles: `#FFFCF8` with a 1 px `#EBE1DA` outline, left-aligned in both modes
- [ ] In both modes, bubbles hug short-message content and expand only as needed until the existing maximum width, where longer text wraps
- [ ] Practice mode shows one collapsed learning-language line; Normal mode shows authored text for known languages and one primary-known-language translation for unknown incoming languages
- [ ] The interface language controls app chrome, definitions, and explanations only; it is never a message-translation target
- [ ] If an author makes a clear mistake in their learning language, that author sees the minimal correction inline with replaced text struck through plus a short interface-language explanation
- [ ] Recipients never see the author's correction marks or coaching explanation; they see one clean corrected learning-language line
- [ ] Correct target-language writing remains clean; uncertain author corrections are labeled "Possible correction" and do not invent missing meaning
- [ ] Sender and receiver reuse the same correction cache variant when their learning and interface languages match
- [ ] Translation words are tappable and definitions use the selected interface language
- [ ] Reaction badges overlap the bubble edge nearest the conversation center: right edge for incoming messages and left edge for outgoing messages; every badge uses `#FFFCF8` fill and `#DCD2C8` outline, with a subtle shadow in Practice only
- [ ] Tapping a learning-language word opens its word description; tapping empty bubble padding does nothing; message actions require long press
- [ ] Practice long press temporarily reveals the reader's primary-known-language translation below the existing divider; Normal conditionally offers Original for the exact authored text
- [ ] With learning aids disabled, authored text is shown and no new AI request is made
- [ ] Expressive stretching, playful capitalization, and chat abbreviations are treated as style rather than mistakes; confidently identified names are transliterated into a different target script without changing their identity, while uncertain name-like text remains authored
- [ ] If source language is outside Blab's supported language set, keep the exact authored text and show a neutral localized hint (`Blab doesn’t speak this one yet — try [learning language].`) in muted 12 px text; do not show Retry, Listen, Original, or word-description actions
- [ ] A failed learning aid keeps the authored text usable and shows localized `Couldn’t translate · Retry` in `#C62828` below the bubble with no standalone icon
- [ ] Timestamp shown below bubble (no read ticks on incoming)
- [ ] Date labels such as "Today", "Yesterday", and weekday names sit directly on the chat canvas with no pill fill or background

---

### US-016: Messages — outgoing with read receipts
**Description:** As a sender, I want to see when my messages are delivered and (optionally) read.

**Acceptance Criteria:**
- [ ] Outgoing bubbles are right-aligned; Normal uses `#D7C8BE` with a 1 px `#C8B9AF` outline and no shadow, while Practice uses `#F88C5A` with a 1 px `#F07D4B` outline and the approved subtle Practice shadow
- [ ] Sending or locally queued shows a single gray clock icon
- [ ] Server accepted and friend's device received both show the supplied single gray check; these two states are not visually distinguished at launch
- [ ] Read shows the supplied double gray check only when both sides have Read receipts ON
- [ ] If either side has Read receipts OFF, the message remains at the single gray check
- [ ] When the reader's toggle is OFF, their phone sends no read event and the server keeps no hidden read record
- [ ] Default for the toggle: **ON** (matches Signal default; Privacy section explains the rationale)

---

### US-017: Message grouping
**Description:** As a user sending multiple messages in a row, I want them grouped visually.

**Acceptance Criteria:**
- [ ] Consecutive outgoing messages: reduced gap (-4px margin-top), no timestamp repeated on grouped bubble
- [ ] Timestamp + ticks shown only on last message in a group

---

### US-018: Tappable words — word lookup popup
**Description:** As a learner, I want to tap any word in the chat to see its meaning and pronunciation.

**Acceptance Criteria:**
- [ ] Every content word in Tamil messages is wrapped in a tappable span (both incoming and outgoing)
- [ ] Tapping a word opens a popup. Layout: 🔊 speaker icon on the left, vertically centered; to its right, a single left-aligned column with learning-language word (large, w700) / Latin-script transliteration (13 px muted, NOT italic) / primary-known-language translation (15 px w500). All three text rows share the same left edge; word-containing learning lines are never cached without this metadata
- [ ] Speaker icon belongs to the target word (left side), not the English translation
- [ ] When TTS for the language is unavailable, the speaker icon stays in place but renders disabled: 40% opacity, no tap response, no tooltip, no text — silent disabled state. (FR-24)
- [ ] Popup positions above the tapped word; clamps to phone bounds (no overflow)
- [ ] × closes popup; tapping anywhere in message area closes popup
- [ ] Tapping a tappable word does NOT trigger long-press on the parent bubble

---

### US-019: Message actions on outgoing messages
**Description:** As a user, I want to edit, copy, reply to, or delete my own messages.

**Acceptance Criteria:**
- [ ] Long press opens the floating reaction row plus composer-replacement action row; the reaction row sits below by default, moves above when there is no room below, and overlaps only a viewport-filling message; tapping empty bubble padding does nothing and tapping a learning word still opens its definition
- [ ] Practice actions: Reply | Edit | Copy | Listen | Delete; Normal actions: Reply | Edit | Copy | Original | Delete, with conditional actions hidden when ineligible
- [ ] Practice long press temporarily reveals the primary-known-language translation; Normal Original temporarily reveals exact authored text below the existing divider
- [ ] Tapping outside or starting a scroll closes reactions, actions, and temporary Translation/Original content
- [ ] Reply uses the primary text currently presented in chat, opens the keyboard, and threads the quote into the sent bubble
- [ ] A deliberate horizontal swipe anywhere across the message's full row, including empty background beside the outgoing bubble, starts Reply; short movement and diagonal/vertical scrolling do not; open background outside message rows does nothing
- [ ] **Edit window: 24 hours** from the moment the message was sent (Signal-style). Past 24h the Edit row is hidden from the sheet
- [ ] Edit keeps the existing bubble visible, loads exact authored text into the composer, opens the keyboard, preserves the draft across mode/settings/profile navigation, and ends only on Send or ×
- [ ] Emoji/whitespace-only edits reuse translation; any changed letter, number, or punctuation invalidates stale language help and translates/corrects the full edit again
- [ ] Edited bubbles show permanent `edited · time · receipt` metadata at 10 px in the timestamp color
- [ ] Copy copies the complete primary text currently presented in chat and never concatenates a temporary Translation/Original line
- [ ] **Delete: no time limit** — confirmation uses `Delete message?` and explains it will also be deleted for `{name}`; confirm removes it completely for both people with no tombstone or Undo

---

### US-020: Message actions on incoming messages
**Description:** As a user, I want to reply to or copy messages from my chat partner.

**Acceptance Criteria:**
- [ ] Long press opens the floating reaction row plus composer-replacement action row; the reaction row sits below by default, moves above when there is no room below, and overlaps only a viewport-filling message; tapping empty bubble padding does nothing and tapping a learning word still opens its definition
- [ ] Practice actions: Reply | Copy | Listen | Report; Normal actions: Reply | Copy | Original | Report, with conditional actions hidden when ineligible
- [ ] Copy and Reply use the complete primary text currently presented in chat; a translation failure therefore uses the readable authored text
- [ ] Tapping outside or starting a scroll closes reactions, actions, and temporary Translation/Original content
- [ ] A deliberate horizontal swipe anywhere across the message's full row, including empty background beside the incoming bubble, starts Reply; short movement and diagonal/vertical scrolling do not; open background outside message rows does nothing

---

### US-021: Reply bar
**Description:** As a user replying to a message, I want to see what I'm replying to.

**Acceptance Criteria:**
- [ ] Reply preview appears above input and uses only `You` or the partner's exact name, never `Replying to…`
- [ ] `You` uses brand color; partner uses the assigned avatar accent or `#46281C` fallback for a photo avatar
- [ ] No divider separates Reply preview from the text field; × aligns with the Send column and the text/ellipsis aligns with the text-field edge
- [ ] Reply opens the keyboard automatically and quotes exactly the primary text currently presented in chat
- [ ] Sending includes a visual quote block inside the bubble; outgoing quote fill is `#FAB894`, incoming quote fill is `#F5F0E8`, with existing radius and side line unchanged
- [ ] Photo replies use the same container with thumbnail + caption, or thumbnail + localized `Photo`
- [ ] Cancel (×) dismisses reply bar

---

### US-022: Change learning language (in-chat)
**Description:** As a user mid-chat, I want to change which language I'm currently learning.

**Acceptance Criteria:**
- [ ] Bottom sheet: "Learning language" heading + scrollable list of 11 languages with flag + checkmark on selected
- [ ] Selecting language updates chat header label and ··· menu label
- [ ] "Done" button closes sheet
- [ ] Backdrop tap also closes sheet

---

### US-023: Input area
**Description:** As a user, I want to type and send messages naturally.

**Acceptance Criteria:**
- [ ] Auto-growing textarea (starts at 1 row)
- [ ] Normal placeholder is the localized equivalent of "Message"; Practice shows localized guidance `Type in [learning language] or [primary known language]` on one line, without restricting what the user may send
- [ ] Messages may be authored in any language; the interface language is never used as a translation target
- [ ] Messages are capped at 2,000 user-perceived characters end to end, including translation
- [ ] When input is empty, only the send-button circle fill dims to 40%; its arrow remains solid white, and the fill brightens when text is entered
- [ ] The 44 px send button contains 20 px arrow artwork; its subtle Practice shadow is absent in Normal mode
- [ ] Tapping send appends message and clears input

---

### FLOW 4 — Invite Flow + Aswin's Side

---

### US-024: Static invite landing page
**Description:** As someone without Blab who received an invite, I want a simple route to download it.

**Acceptance Criteria:**
- [ ] One static page serves every `loveblab.com/i/{token}` URL; the URL is dynamic but page content is not
- [ ] Black Blab logo links to `https://www.loveblab.com/`; page copy is `You’re invited to Blab` + `Chat naturally while Blab helps you practice a language.`
- [ ] Equal store buttons read `Download on the App Store` and `Download on Google Play`
- [ ] Use `#46281C` primary and `#917869` secondary text; do not show inviter name, language, `Open in Blab`, or “your invite will be waiting”
- [ ] The web page never validates or claims the invite; a verified installed-app link normally opens Blab directly

---

### US-025: Invitee sign up
**Description:** As an invited user, I want to create an account and join the chat without friction.

**Acceptance Criteria:**
- [ ] The recipient uses the standard email sign-up or login page; no invite-specific account page, account-confirmation prompt, or phone-number flow is added
- [ ] Opening a valid link while signed out preserves the most recently opened invite through sign-up, login, app close, and return
- [ ] After successful authentication, Blab claims the saved invite and opens the resulting chat directly
- [ ] If two links are opened before authentication, only the most recently opened link is claimed; earlier links remain valid
- [ ] A browser or store-page visit never claims an invite

---

### US-026: New connection in Chats
**Description:** As either participant in a new chat, I want to immediately understand that the chat is ready to start.

**Acceptance Criteria:**
- [ ] Both people see the same chat row with `Ready to chat · Say hi` in the message-preview position
- [ ] The row sorts and styles as unread until that participant chooses a practice language; there is no separate in-app joined banner
- [ ] If a real message arrives first, it replaces the preview and shows authored text until the participant chooses a practice language
- [ ] After practice language selection, a real-message preview uses that participant's Practice result
- [ ] An already-existing pair chat receives no new-connection row, unread state, language reset, or required sheet

---

### US-027: New chat — empty state and required practice language
**Description:** As a participant in a newly created chat, I want to choose my practice language in context before I start messaging.

**Acceptance Criteria:**
- [ ] After the required language choice, an empty chat shows a simple text container: `No messages here yet…` + `Send any message to start.`; no launch illustration. Hide this container while initial language selection is required so it cannot peek above the open sheet
- [ ] Required bottom sheet title: `Choose a language to practice`; helper: `You can change it anytime.`; it uses the existing language list
- [ ] The sheet shows over the chat with no blur and a subtle `#46281C` 8% veil; authored first messages remain visible behind it if they already exist
- [ ] Required-sheet styling follows the owner’s 2026-09-08 refinement: warm-white `#FFFCF8` surface, 24 px top corners, warm outline/shadow, 22 px bold title, 14 px muted helper, 15 px language rows with generous 56 px minimum tap targets and dividers, and a persistent slim scrollbar
- [ ] Tapping outside or swiping down does not close the sheet; composer, messages, and mode switch are inactive until selection
- [ ] Back leaves for Chats; reopening the new chat shows the required sheet again. Profile and Settings remain reachable outside the chat
- [ ] Each participant's choice is independent and affects only their own display

---

### US-028: Aswin's chat — same core features as Nastia's
**Description:** As Aswin, I want the same chat capabilities Nastia has.

**Acceptance Criteria:**
- [ ] All core chat features follow Flow 3 after the required initial practice-language selection
- [ ] Before selection, authored text remains uncorrected and untranslated; after selection, messages and previews use the participant's Practice result where applicable
- [ ] Reply preview + incoming long-press follow US-020 / US-021, including Normal Original, Practice Listen, and Report eligibility
- [ ] Input placeholder: localized "Message"
- [ ] Send button uses the same empty-state treatment as US-023: dimmed circle fill with a solid-white arrow

---

### FLOW 5 — Cross-cutting (added during tech-spec gap audit)

---

### US-029: Word audio playback source
**Description:** As a learner, when I tap the 🔊 button in the word popup, I want to hear the word pronounced.

**Acceptance Criteria:**
- [ ] Audio is on-device TTS (platform-native: Android `TextToSpeech`, iOS `AVSpeechSynthesizer`) — no external API calls in the popup path
- [ ] If TTS for the target language is unavailable on the device, the 🔊 button stays in place at 40% opacity with no tap response, tooltip, or replacement text
- [ ] Tapping 🔊 while audio is playing replays from start (no queuing)

---

### US-030: Message send failure + retry
**Description:** As a sender, when a message fails to deliver, I want to retry without re-typing.

**Acceptance Criteria:**
- [ ] Failed delivery shows localized `Not sent · Tap to try again` in `#C62828` directly below the bubble with no error or Retry icon
- [ ] The failure row is left-aligned to the bubble block, uses a 160 px minimum width for short messages, follows wider bubble widths, and retries when tapped
- [ ] A reaction badge remains between the bubble and failure row; starting Reply never hides the failure row
- [ ] Pending (in-flight) bubbles show a single gray clock icon, never a tick
- [ ] Failed messages persist locally across app restarts until retried or deleted

---

### US-031: Offline / no-connection state
**Description:** As a user without internet, I want clear feedback that the app is offline.

**Acceptance Criteria:**
- [ ] Thin banner under the nav bar reads "No connection — messages will send when you're back online" with a gray background
- [ ] Banner appears on connectivity loss within 3 seconds, disappears within 3 seconds of recovery
- [ ] Composed messages queue locally and auto-send on reconnect
- [ ] Chat list still opens; existing chats render from local cache
- [ ] Invite a friend uses the same top banner, keeps its normal layout, and disables `Send invite` while offline
- [ ] A valid invite opened in the installed app before a connection loss is preserved and claimed automatically on recovery; if the user leaves, its finished chat appears unread in Chats

---

### US-032: Loading + error states
**Description:** As a user, I want clear feedback when content is loading or failed to load.

**Acceptance Criteria:**
- [ ] Chat list initial load: skeleton rows (3) for ≥150ms before content shows
- [ ] Chat view initial load: skeleton bubbles
- [ ] Failure to load: inline error card with "Retry" button (no full-screen blockers)
- [ ] Pull-to-refresh available on chat list

---

### US-033: Accessibility baseline
**Description:** As a user relying on assistive tech, I want the app to be usable.

**Acceptance Criteria:**
- [ ] All interactive elements have semantic labels (screen reader: TalkBack / VoiceOver)
- [ ] Tap targets ≥ 44×44 pt
- [ ] Color contrast ≥ WCAG AA for all text on its background
- [ ] App respects system font-scale up to 200% without clipping critical UI
- [ ] Read receipts and online indicators are not color-only (paired with shape or text)

---

### US-034: Legal links on signup
**Description:** As a new user, I want to see Terms and Privacy before creating an account.

**Acceptance Criteria:**
- [ ] Below the signup CTA, fine print: "By creating an account you agree to our Terms and Privacy Policy"
- [ ] Both links open in an in-app web view
- [ ] No checkbox required (consent is implicit by submitting)

---

### US-035: Delete account
**Description:** As a user, I want a path to permanently delete my account, distinct from logging out.

**Acceptance Criteria:**
- [ ] "Delete account" row appears in Profile, visually separated below "Log out", in red
- [ ] Tapping opens a confirmation sheet listing what will be deleted (chats, messages, profile)
- [ ] Requires re-entering password to confirm
- [ ] On success: all local data wiped, returns to auth screen
- [ ] Deletion is irrevocable (no grace period in v1)

---

### US-036: Message length cap
**Description:** As a system, I want a reasonable upper bound on message size.

**Acceptance Criteria:**
- [ ] Hard limit: 2000 characters per message
- [ ] Character counter appears below input at 1800+ characters, red at 2000
- [ ] Send button disabled when over limit

---

### US-037: Invite link — invalid / already used (recipient side)
**Description:** As someone who cannot use an invite link, I want a clear explanation and a way back to Blab.

**Acceptance Criteria:**
- [ ] Invite links do not expire with time; an unclaimed link remains valid until one friend uses it
- [ ] Invalid or unknown link: shows "We couldn’t find that invite." + "Check the link is correct, or ask for a new one." + "Go to chats"
- [ ] A used link reopened by its claimant opens their existing chat; a used link opened by another account shows `This invite has already been claimed` + `Ask your friend for a new link.` + `Go to chats`
- [ ] A self-opened unused link never self-claims and opens Invite a friend; a self-opened claimed link opens the resulting chat
- [ ] Unavailable-link states are shown in Blab; the no-app web page remains static and generic

---

### US-038: Push notification opt-in
**Description:** As a user, I want to be asked for notification permission at the right time.

**Acceptance Criteria:**
- [ ] System permission prompt requested *after* first chat is opened, not at app launch
- [ ] If denied, a single inline reminder appears once in the chat header: "Enable notifications to hear from your partner" with a × dismiss
- [ ] Settings deep-link available from Profile (Phase 2)

---

### US-040: Typing indicators (Signal-symmetric toggle)
**Description:** As a user, I want to know my partner is actively replying, but I want to be able to turn this off (and have my own typing hidden too) without thinking about it.

**Acceptance Criteria:**
- [ ] "Typing indicators" toggle lives in Privacy settings (Phase 2 — settings screen TBD)
- [ ] **Default: ON** (matches Signal's default; the privacy guarantee is in the symmetric off path, not the default)
- [ ] When my toggle is OFF, my client does not send typing events at all — server has no record (not just "hidden on receive")
- [ ] When my toggle is OFF, I also don't see my partner's typing — symmetric fairness rule ("if I don't share mine, I don't see yours")
- [ ] When both sides are ON: chat header subtitle line ("Learning Tamil 🇮🇳") is replaced with "typing…" in brand color while the partner is composing; the chat-list tile preview replaces last-message text with "typing…" in brand color
- [ ] Throttle: typing indicator appears 300 ms after partner's first keypress and auto-clears 3 s after their last keypress
- [ ] Transport: Supabase Realtime presence channel per chat — no persistent rows
- [ ] No analogous "Online" / "Last seen" feature is shipped (this is intentional — see § Privacy)

---

### US-041: Read receipts toggle (Signal-symmetric)
**Description:** As a user, I want control over whether my read state is shared, with the same symmetric guarantee as typing indicators.

**Acceptance Criteria:**
- [ ] "Read receipts" toggle lives in Privacy settings alongside typing indicators
- [ ] **Default: ON** (Signal default)
- [ ] When my toggle is OFF, my client never sends read receipts — server has no record. I also don't see my partner's read state (symmetric)
- [ ] When both sides are ON, US-016 behavior applies: single gray check → double gray check on read
- [ ] When either side is OFF, the message stays at the single gray check

---

### US-042: Resolve ambiguous grammatical forms in chat
**Description:** As a learner, I want Blab to ask which natural grammatical form fits a person only when a translation cannot be completed without it, so I can learn the real sentence without being blocked or repeatedly correcting the same choice.

**Acceptance Criteria:**
- [ ] One unresolved person appears as a compact `…` marker inside the sentence; multiple unresolved people use `#1`, `#2`, and so on, with every linked agreement change for one person controlled by the same marker
- [ ] The first unresolved chooser opens by default beneath the message and uses `Choose your gendered form` or `Choose [name]’s gendered form`; the first prompt per learning language also explains that the language changes some words to match the person they describe
- [ ] Only one chooser is open at a time; tapping another marker switches to it, tapping the active marker closes it, and tapping elsewhere in chat does not dismiss it
- [ ] Choosing a form resolves the natural sentence immediately and briefly shows `[Person]: [form] · Change`; this confirmation disappears after the next sent or received message
- [ ] Unresolved markers remain in history; reopening the chat opens the newest unresolved chooser, and a later choice for the viewer or partner quietly resolves their earlier unresolved markers without a wave or automatic scroll
- [ ] A first clear form authored directly in the learning language is accepted and remembered silently, with no correction mark
- [ ] Once a form is saved, a later opposite authored form is automatically corrected to it with the normal visible correction treatment; no contradiction chooser, warning, or explanation appears
- [ ] A just-made choice can be revised while its temporary `Change` row remains; after that row disappears, the authoritative form changes only in Translation preferences and never through contradictory authored text
- [ ] The person’s own form is account-wide and takes priority; somebody else’s selection is a private fallback for that one-to-one relationship and never edits the person’s profile
- [ ] Chat → Translation preferences exposes `Your gender form`, `[Name]’s gender form`, and `Conversation tone` as three direct rows in one outlined container without section subtitles; Profile → Translation preferences also exposes the account-wide self form. The page uses `#FAF7F2` canvas, `#FFFCF8` header/card, `#E1DAD2` card outline, regular 18 px `#46281C` title, regular 15 px `#46281C` labels, regular 14 px `#917869` values, supplied 20 px navigation arrows, `#46281C` back arrow, and `#917869` row arrows. The header title begins at the same horizontal position as the chat-header avatar, leaving the same 10 px visual gap after the back arrow
- [ ] A name alone never determines gender; explicit language in the same paragraph can resolve a named reference, while choices for other named people remain message-local
- [ ] The chooser appears only for sentences and supported languages that require it; English and Turkish can remain naturally gender-neutral, while Tamil usually requires it only for third-person references
- [ ] Photo captions use the same form, correction, and ambiguity rules as text messages
- [ ] V1 offers feminine and masculine only; nonbinary grammatical systems and regional variants beyond the launch locales remain explicit limits rather than invented or stiff rewrites

---

### US-043: Message lifecycle and translating state
**Description:** As a person chatting while learning, I want translation or correction to feel like one clear transformation, so I can trust that my message sent and understand what Blab is doing without seeing duplicate text or a dead end.

**Acceptance Criteria:**
- [ ] Outgoing Practice messages follow the approved under-180ms / 180–350ms / over-350ms display branches, including subtle arrival motion and the glyph-only wave after 350ms for slow results
- [ ] Source and generated text are never visible together, and no text is visible while a bubble changes its measured final size
- [ ] Mechanical writing fixes are silent; clear author mistakes use the normal inline correction treatment; recipients see only clean output
- [ ] Emoji, URLs, mentions, hashtags, code, protected names, and number-only content are never corrected or translated; mixed messages preserve them in natural target-language order
- [ ] Incoming Practice messages wait for their target-language result; incoming Normal messages translate only when their source is unknown to the reader
- [ ] After one quiet retry and no more than ten seconds, language-help failure preserves readable original text and shows an actionable Retry; delivery failure remains a separate state
- [ ] Cached messages, mode switches, edits, deletion, captions, grammatical alternatives, off-screen resolution, concurrent sends, and reduced-motion behavior follow `2026-08-12-translating-state-animation-design.md`

---

### US-044: Open unread chats with translations ready
**Description:** As a recipient, I want messages translated before I open the chat so I can begin reading immediately without bubbles arriving in a random order.

**Acceptance Criteria:**
- [ ] After message delivery, Blab prepares and persists the recipient's Practice and Normal views without requiring that participant to open the chat
- [ ] Under normal service availability, opening a prepared chat paints final messages immediately with no replayed translation state
- [ ] A genuine remaining miss appears as a normal incoming bubble with two static `#EAE6E0` skeleton lines; one muted group row reads `Translating…` or `Translating N messages…`
- [ ] Pending results reveal oldest-first, and each ready result appears without waiting for every other pending message
- [ ] Incoming Practice never exposes the authored message while processing; Normal shows authored text immediately when the reader knows its source language
- [ ] A final failure replaces only that skeleton with readable authored text plus `Couldn’t translate · Retry` and never blocks later messages

---

### US-045: Stable unread position and truthful read state
**Description:** As a recipient, I want the chat to start where my unread messages begin and preserve my place while I read or switch modes.

**Acceptance Criteria:**
- [ ] Chat entry anchors the oldest unread message at the top of the readable viewport behind a centered `{count} new message(s)` divider
- [ ] The divider uses regular 12 px `#8C735F`, 1 px `#E1DAD2` side lines, 8 px line gap, 16 px vertical spacing, and remains until the chat is closed
- [ ] A pending skeleton never counts as read; final translated, authored, or final-failure fallback content counts after at least 50% becomes visible
- [ ] Reaching the bottom marks every resolved incoming message through the latest as read; pending rows become read only after they resolve while the reader remains caught up
- [ ] Normal/Practice switching keeps the reader at bottom or preserves the same top visible message and relative offset elsewhere
- [ ] Translation failure never triggers automatic scrolling

---

### US-046: Preserve learning-language history
**Description:** As a learner, I want completed messages to retain the language I was learning at that point in the conversation, while new and still-unseen work follows my latest language choice.

**Acceptance Criteria:**
- [ ] Completed Practice results remain in their historical learning language after a later language change
- [ ] A private centered marker `Now learning [language]` appears in both modes using the date-label treatment: regular 12 px `#8C735F`, no lines, pill, outline, or icon. When it starts a dated section, the order is date label → language marker → messages, with 18 px from the previous bubble to the date label, 10 px from the date label to the language marker, and 10 px from the marker to the next bubble. When it sits between message bubbles, it keeps 10 px of visible space above and below the marker.
- [ ] The marker and language history belong only to that participant and never appear in the partner's view
- [ ] Still-pending unseen work is cancelled or invalidated, reassigned to the new language, and placed below the marker
- [ ] A late result for the old language can never overwrite the active new-language result
- [ ] Repeated switching creates small private timeline events without duplicating original messages or clearing completed translations

---

### US-047: View synced chat photos offline
**Description:** As a participant, I want photos I have already synced to remain recognizable and usable when my phone is offline.

**Acceptance Criteria:**
- [ ] The private full-resolution original remains durably stored in Supabase Storage; every attachment also has a chat-sized preview
- [ ] Synced previews persist in app-private device storage; a full-size photo persists in the bounded device cache after it has been opened
- [ ] A cached full photo opens normally offline; a preview-only photo opens at its available quality
- [ ] If no preview has downloaded, the bubble retains its photo geometry and 12 px corners with a neutral `#EAE6E0` placeholder plus muted photo asset
- [ ] The offline placeholder has no visible error text, red cross, dim overlay, or enabled tap
- [ ] Reconnection loads the missing preview automatically without moving the message

---

### US-048: Invite-opening loading state
**Description:** As a recipient, I want calm feedback while Blab validates or claims my invite.

**Acceptance Criteria:**
- [ ] Show only after validation takes longer than one second, including the post-auth claim of a saved invite
- [ ] Centered canvas is `#FAF7F2`; first row is `Opening invite` in 17 px semibold `#46281C`
- [ ] Three 16 px `#F88C5A` dots appear 16 px below the text with 10 px gaps; opacity cycles left-to-right through 100%/60%/30% over a 900 ms loop, without movement or scaling
- [ ] Reduced motion uses the static 100%/60%/30% dot state
- [ ] The state routes directly to normal auth, the resulting chat, or the relevant terminal error state

---

### US-049: First-time mode tips
**Description:** As a new chat participant, I want a short explanation of Practice and Normal after choosing a practice language.

**Acceptance Criteria:**
- [ ] Practice tip appears after the participant's first practice-language choice; Normal tip appears the first time they switch to Normal; each appears once per account
- [ ] Tips anchor to the mode switch with no dimming or blur and close when the user taps anywhere else
- [ ] Practice copy: `Messages appear in {practice language}. Blab helps correct mistakes and translates from {primary known language}. Switch to Normal to see the original.`
- [ ] Normal copy: `Messages in languages you know stay as written. Others are translated for you. Long-press to see the original.` followed by `Edit known languages`
- [ ] Tips use `#F88C5A` fill, `#46281C` text, 280 px maximum width, 12 px padding/radius, 13 px semibold title, 12 px / 16 px body, and a low-opacity warm-ink y2/blur8 shadow

---

## Functional Requirements

- FR-1: Auth supports sign up, login, SSO (Apple/Google), forgot password — all as tab-toggle on one screen
- FR-2: Password field has show/hide toggle, strength meter visible during sign up only
- FR-3: Interface-language picker exposes English, Ukrainian, German, and Spanish from auth and Profile; English is the default/fallback, and the preference persists locally before auth and per account after auth
- FR-4: Invite creation never asks for a language or contacts access. A link is valid until one successful claim, with no time expiry; each exposed link is unique and a fresh link is prepared after Copy or a selected share target
- FR-5: `Send invite` opens the device native share sheet with the standard Copy affordance and return behaviour; no custom share sheet or success page is used
- FR-6: Chat list shows avatar, name, last message preview, timestamp, unread badge, and `Ready to chat · Say hi` for an unmessaged new connection until that participant selects a practice language
- FR-7: Empty state shown when no chats exist
- FR-8: Profile settings in a single card: Interface language | Edit profile | Change email | Change password | Log out. Log out triggers a confirm dialog before signing out
- FR-9: Edit profile loads and validates the persisted display name. Save (in nav) returns to profile + shows "Profile updated ✓" only after the server succeeds
- FR-10: Change password has current/new/confirm fields with strength bar; success shows toast
- FR-11: Every content word in normalized learning-language text is tappable → popup (word + romanization + translation + audio)
- FR-12: Popup positions above word, clamps to phone bounds, closes on tap-outside
- FR-13: Practice mode renders one collapsed learning-language line and temporarily reveals the primary-known-language line on long press; Normal renders authored text for known languages, translates an unknown incoming language once into the reader's primary known language, and conditionally exposes exact authored text through Original. The interface language controls chrome, definitions, and correction explanations only. Author mistakes in their learning language render as minimal inline strike-through corrections; recipients receive clean corrected output without coaching marks. Disabling learning aids prevents new AI requests and shows only the original; failures preserve the original with an inline text-only Retry action
- FR-14: Outgoing status is clock while sending, single gray check when accepted or device-received, and double gray check when read. Read requires both Read receipts toggles ON; otherwise it stays single. Default ON, symmetric, and OFF emits no read event
- FR-15: Outgoing message actions require long press. Normal uses Reply | Edit | Copy | Original | Delete; Practice uses Reply | Edit | Copy | Listen | Delete. Conditional actions hide when ineligible; Delete confirms, removes for both, and has no tombstone or Undo
- FR-16: Incoming message actions require long press. Normal uses Reply | Copy | Original | Report; Practice uses Reply | Copy | Listen | Report. Tapping empty bubble padding does nothing
- FR-17: Reply preview uses only You/name with the approved accent and visible primary message text, opens the keyboard, and threads the same text or photo preview into the sent bubble
- FR-18: Consecutive outgoing messages group (reduced gap, no repeated timestamp)
- FR-19: ··· menu: show/hide translations and corrections toggle + change learning language, auto-width
- FR-20: Change learning language sheet: 11 languages, checkmark on current, updates header label
- FR-21: Send button disabled-state dims the circle fill to 40% when input is empty while keeping the arrow solid white; input is an auto-growing textarea
- FR-22: A new unmessaged chat shows `No messages here yet…` / `Send any message to start.` in a simple centered text container. Its required initial practice-language sheet uses no blur and a subtle 8% warm scrim, hides the empty-state container, and must be completed before chat interaction
- FR-23: Translations toggle scoped per chat (phone3 vs phone4 separate state)
- FR-24: Word popup audio uses on-device TTS only — no external API. When TTS unavailable for the language, speaker icon stays in place but renders disabled (40% opacity, no tap, no tooltip, no text)
- FR-25: Delivery failure shows `Not sent · Tap to try again`; language-help failure shows `Couldn’t translate · Retry`. Both are `#C62828` text-only rows below the bubble with no standalone icon; pending remains a clock
- FR-26: Offline banner appears within 3s of connectivity loss; composed messages queue and auto-send on reconnect. Invite a friend uses the same banner and disables Send invite while offline; a pending valid invite claim resumes automatically on reconnection
- FR-27: Loading skeletons on first paint of chat list and chat view; failures use inline retry, not full-screen blockers
- FR-28: All interactive elements have semantic labels; tap targets ≥ 44pt; contrast ≥ WCAG AA; respects system font scaling through 200%. The temporary five-action launch row uses 16 px icons, 11 px labels, and two-line wrapping under enlarged text rather than clipping or truncating
- FR-29: Push permission requested after first chat opens, not at launch
- FR-30: No online / "last seen" feature exists. Chat header shows learning-language subtitle, replaced by "typing…" only when both sides have Typing-indicator toggle ON (US-040)
- FR-31: Typing indicators + Read receipts are Signal-symmetric toggles in Privacy settings; default ON; OFF path = client never broadcasts the event (server has no record) AND user does not see partner's signal either
- FR-32: Edit window is 24h and Delete has no time limit; both apply to outgoing messages only. Edit preserves its draft across navigation until Send or ×, marks the message edited, and refreshes language help after any changed letter, number, or punctuation
- FR-33: Interface-language switch immediately re-renders word definitions on loaded chats from locale-specific cache entries — no restart and no gloss from another interface locale
- FR-34: When a generated target sentence genuinely requires an unknown feminine or masculine form, render a compact inline marker with one non-blocking chooser. One subject decision resolves every linked agreement change for that subject; multiple unresolved people receive numbered markers. Unresolved markers persist in history until selected, while resolved words retain normal word-popup behavior
- FR-35: Grammatical-form memory has only `not set`, `feminine`, and `masculine`. A self-owned form is account-wide; another participant’s choice is a private one-to-one fallback. The first clear authored form is learned silently; once saved, it is authoritative and later opposite authored forms receive the normal visible correction until the user changes the preference in settings. Conversation tone is stored separately per chat
- FR-36: Message lifecycle follows `docs/superpowers/specs/2026-08-12-translating-state-animation-design.md`: a slow delivered outgoing Practice message receives a glyph-only wave after 350ms, then a measured clear → reshape → land transition; text states never duplicate. Language-help failure quietly retries once for up to 10 seconds, then preserves original text with Retry. Expressive stretching, playful capitalization, and chat abbreviations are not correction mistakes; confidently identified names are transliterated when the target script differs without changing their identity. Unsupported source languages preserve the original with a neutral hint and no Retry or learning actions. Delivery failures remain distinct, and reduced-motion behavior has no decorative motion
- FR-37: The launch message interaction follows `docs/superpowers/specs/2026-08-24-chat-ui-refresh-simple-long-press-design.md`: word tap opens lookup, empty bubble padding does nothing, long press opens reactions/actions without a scrim or bubble movement, the reaction row prefers free space below then above before overlapping a viewport-filling message, Copy/Reply use the primary displayed text, and the compact action row localizes without clipping
- FR-38: Delivered messages are prepared and persisted for each participant's Normal and Practice views before chat open. Genuine misses use ordered static skeleton bubbles plus one `Translating N messages…` group row; final failures fall back independently to authored text with Retry
- FR-39: Chat entry anchors at the oldest unread behind an `N new messages` divider. Pending skeletons never count as read; final content requires 50% visibility unless the reader reaches bottom. Mode switching preserves the visible-message anchor and never scrolls to a failure
- FR-40: Learning-language history is private per participant. Completed results retain their assigned historical language; `Now learning [language]` marks the boundary; pending unseen work retargets to the latest revision; stale language results cannot become active
- FR-41: Chat-photo originals remain in private Supabase Storage, synced previews persist on-device, opened full files use a bounded cache, and an unavailable offline preview renders the approved neutral placeholder without framework error UI
- FR-42: Invite handoff preserves the most recently opened valid invite through standard email auth and app return. Claim happens only once a signed-in recipient is known; existing pairs reuse their chat and no one can self-claim. The static web page is generic and never validates or claims a token
- FR-43: First-time Practice and Normal guidance is a once-per-account, non-modal mode-switch tip using the approved copy and warm-orange treatment

---

## Security & Encryption (End-to-End)

Chat content is end-to-end encrypted. Supabase Auth + RLS control **who can fetch** ciphertext; E2EE controls **who can read** it. Both layers required.

### Shape

1. **Auth & access control** — Supabase Auth for login; Row-Level Security (RLS) on every table and Storage bucket. `service_role` key never ships in the client.
2. **Key generation** — encryption keys generated on the Flutter device, never on Supabase or in Edge Functions.
3. **Ciphertext only at rest** — Postgres rows and Storage objects store only ciphertext for any user-content field (message body, message metadata that reveals content, attachments).
4. **Key storage** — public keys uploaded to Supabase (per user, per device); private keys stay on-device in **iOS Keychain** / **Android Keystore**. Private keys never leave the device.
5. **Encrypt before write** — client encrypts locally before any `insert`/`update`.
6. **Decrypt after read** — client decrypts locally after fetch; server-side code never sees plaintext.
7. **Shared content (1:1 chat)** — generate a random per-message (or per-conversation) **content key**; encrypt the payload once with the content key; then wrap the content key separately for each recipient device's public key. Adding/removing a device re-wraps the key, never re-encrypts the payload.
8. **No plaintext in server compute** — Edge Functions, triggers, logs, and analytics must never receive plaintext, private keys, or decrypted payloads. Treat server logs as public.

### Crypto choices (recommended)

- **Flutter libraries:** `cryptography` / `cryptography_flutter` or `sodium` (libsodium bindings).
- **Payload encryption:** XChaCha20-Poly1305 or AES-GCM (authenticated encryption, required).
- **Key exchange:** X25519 + HKDF, or libsodium **sealed boxes** for the wrap step.
- **For chat with forward secrecy:** do **not** invent a protocol. Use Signal-style (Double Ratchet) or Matrix/Olm. Decide in tech-spec before shipping real-time chat.

### Caveats — accept these

- **Encrypted fields cannot be searched or sorted** by Postgres normally. If we need search over message content, either (a) decrypt locally and search client-side, or (b) add a **blind index** field — knowing it leaks some metadata (length, equality patterns). Default: client-side only.
- **Metadata still visible:** timestamps, sender/recipient IDs, message counts, attachment sizes. E2EE hides content, not the social graph. Minimize what we store.
- **Key loss = data loss.** If a user loses all their devices, their old ciphertext is unrecoverable unless we implement a recovery scheme (passphrase-wrapped backup key, secure enclave attested backup, etc.) — decide in tech-spec.

### References

- Supabase Flutter quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- Supabase data security & RLS: https://supabase.com/docs/guides/database/secure-data
- Dart `cryptography` package: https://pub.dev/packages/cryptography
- Dart `sodium` (libsodium): https://pub.dev/packages/sodium

---

## Privacy posture

Blab is sold as a "language-learning app that respects your privacy." This section locks the user-facing promise + the technical commitments behind it.

### The honest promise

> Your messages are end-to-end encrypted — we can't read them. We don't analyze your behavior, sell your data, or track you for ads. Some basic activity (when you're typing, when you read) flows through our servers to make chat work, **but only if you've opted in** — both toggles default to ON for usability, are symmetric (off = neither side sees), and OFF means the event never leaves your phone.

Reasoning: the strongest defensible privacy claim is E2EE content + "no behavioral analytics." We don't pretend to be Signal-level metadata-blind in V1 (we'd need sealed sender + onion routing + similar), but we do not collect any metadata for ads, profiling, or analytics. We pick EU server region to keep data under GDPR.

### Technical commitments

1. **End-to-end encryption** for message content (see § Security & Encryption). Server stores ciphertext, key lives on device.
2. **No online / "last seen" feature exists at all.** Not a toggle, not an opt-out — the capability is simply not built. (Signal model.)
3. **Typing indicators are a Signal-symmetric toggle.** Default ON. Off path = client never sends the event. See US-040.
4. **Read receipts are a Signal-symmetric toggle.** Default ON. Off path = client never sends the event. See US-016, US-041.
5. **No behavioral analytics, no ads SDKs, no third-party trackers.** Period. Sentry crash reports only (no message bodies, no PII beyond user id).
6. **Server region = EU (GDPR).** Locked in tech-spec Resolved Decision #9.
7. **Key loss = data loss in V1.** No key recovery scheme yet — reinstalling wipes chat history. This is surfaced clearly in onboarding copy. V2 may add an optional passphrase-wrapped key backup. (See § Security & Encryption Caveats.)
8. **Report, block, and staffed moderation are required in V1.** The invite-only design reduces exposure but does not remove the need for accessible reporting/blocking, validated report intake, timely human review, enforcement, and child-safety escalation.

### What we do not promise

- We do **not** claim Signal-level metadata privacy. Sealed Sender, message-padding, traffic-shaping, etc. are V2+ research items in tech-spec.
- We do **not** claim "off the grid" or "uncompliable to subpoenas" — lawful EU requests still apply.
- We do **not** claim history is backed up. It isn't.

---

## Non-Goals (Out of Scope)

- No real backend, database, or user accounts
- No actual push notifications (simulated in prototype)
- No real audio playback (simulated play interaction)
- Profile photos and file uploads are out of scope; launch profiles use initial avatars only
- No contacts discovery, recipient-email matching, invite cancellation, or invite-management screen
- No group chats
- No voice or video messages
- No AI conversation partners or generated replies; AI is limited to user-controlled message translation and writing correction
- No language matching algorithm / discovery feed
- No in-app payments or subscription
- No notifications settings screen
- No blocking or reporting

---

## Languages Supported (Prototype)

- **Interface:** English (default/fallback), Ukrainian, German, Spanish
- **Chat learning:** Dutch, English, French, German, Hindi, Italian, Portuguese, Spanish, Tamil, Turkish, Ukrainian

---

## Design Principles

- iOS-native feel: rounded corners, bottom sheets, nav-bar Save, system fonts
- Purple brand (`#5B4FE8`) as primary action color
- Translations visible by default, toggleable per chat
- Partner's language always shown first; English always second
- Read receipts only on outgoing messages (never on incoming)
- No icebreakers — exchange card explains the setup, user starts conversation

---

## Success Metrics

- User can sign up and send first invite link in under 60 seconds
- Tapping a word and getting its meaning in under 1 tap
- User can long-press any message and find their action in under 2 seconds
- Both sides of exchange (learner POV and teacher POV) are immediately clear on first open

---

## Resolved Questions

Originally tracked as "Open Questions"; resolved 2026-05-28 in one batch.

- **Multiple simultaneous language exchanges per user?** → **Yes**, per-chat. Each chat owns its `learning_language_code` + `teaching_language_code`; languages can repeat across chats or differ. Profile shows the primary (most active) as a hint. (Affects US-022, chat schema in Phase 2.2.)
- **Interface-language switch refreshing existing translations?** → **Yes**, immediately for the bottom interface-language lane, word definitions, and correction explanations. The learning-language line stays unchanged; an author's third-language-original exception continues to show the original. The four launch interface locales use separate cache variants. (Updated US-005 by L-15.)
- **Invite link single-use or reusable until claimed?** → **Reusable until claimed** (single *successful* claim), with no time expiry so a delayed or offline share is not invalidated. (Updated US-024, US-037, FR-4 on 2026-09-07.)
- **Exchange card disappearance on first message?** → **200 ms opacity fade-out**, no slide/scale. (Updated US-027.)
- **Edit-profile Save success toast?** → **Yes**, "Profile updated ✓" toast on return to profile. (Updated US-011.)
- **Log-out confirm dialog?** → **Yes** (Signal-style). "Log out?" with Cancel + Log out before actually signing out. (Updated US-010.)
- **TTS — on-device good enough or recorded fallback?** → **V1: on-device only.** Disabled state for unavailable languages = icon dimmed in place (40% opacity, no tap, no tooltip, no text). Cloud TTS or recorded human audio re-evaluated in V2 once we have real usage data on which languages matter most. (Updated US-018, US-029.)
- **Chat history across reinstalls — server-side or device-local?** → **V1: ciphertext on server, key on device, no key recovery.** Reinstall = lose history. Surface clearly in onboarding copy. V2 may add an optional passphrase-wrapped key backup. (See § Privacy posture #7.)
- **Typing indicators — ship or skip?** → **Ship as Signal-symmetric toggle.** Default ON. Off path = client never broadcasts. See US-040.
  - Bonus decision: **read receipts get the same Signal-symmetric toggle** (US-041), and the **"Online / last seen" feature is dropped entirely** — no toggle, no opt-out, the capability simply is not built. (Updated US-013, US-016.)
- **Edit / delete time window — forever or limited?** → **Edit: 24 h** (Signal-style). **Delete: forever** (sender can delete any sent message at any time, propagates to recipient). (Updated US-019.)
