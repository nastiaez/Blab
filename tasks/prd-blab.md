# PRD: Blab — Language Exchange Chat App

## Introduction

Blab is a peer-to-peer language exchange app. Two people teach each other their native languages through real conversations. Every message is shown in the learning language with an English translation beneath it. Words are tappable for instant lookup. The app is built around mutual exchange — not courses, not AI, not tutors. Real people, real chat.

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
- [ ] Tapping opens bottom sheet with language list (checkmark style)
- [ ] Selecting language closes sheet and updates label
- [ ] Same sheet accessible from Profile → Interface language
- [ ] Switching the interface language immediately re-renders translation subtitles + word-popup translations on existing chats (no app restart, no cache stale)

---

### FLOW 2 — Main App (Chats + Profile)

---

### US-006: Chat list
**Description:** As a user, I want to see all my active language exchange chats in one list.

**Acceptance Criteria:**
- [ ] "Chats" tab active by default
- [ ] Each chat item shows: avatar (initial), name, last message preview, timestamp, unread badge
- [ ] Tapping a chat opens the chat view (Phone 3)
- [ ] "+" button in top-right navigates to New Chat screen

---

### US-007: Empty state — no chats
**Description:** As a new user with no chats, I want to see a clear prompt to start one.

**Acceptance Criteria:**
- [ ] If no chats, show empty state: 💬 icon + "No chats yet" + subtitle + "Invite someone" button
- [ ] Button navigates to New Chat screen

---

### US-008: New chat — pick language & invite
**Description:** As a user, I want to invite a friend to learn my language while I learn theirs.

**Acceptance Criteria:**
- [ ] "New chat" screen shows: "What do you want to learn?" heading
- [ ] Searchable flat list of 11 languages (Dutch, English, French, German, Hindi, Italian, Portuguese, Spanish, Tamil, Turkish, Ukrainian) with flag emoji
- [ ] Search filters list in real time
- [ ] Selecting a language: list collapses, confirmed card appears (flag + language name + "Change" link)
- [ ] Link info card appears below: "Only one person can use this link", "Valid for 48 hours"
- [ ] "Share invite link" button enables (was disabled/gray before selection)
- [ ] Tapping "Share invite link" opens native share sheet

---

### US-009: Share sheet
**Description:** As a user, I want to share my invite link via popular messaging apps.

**Acceptance Criteria:**
- [ ] Bottom sheet shows: WhatsApp, iMessage, Telegram, Email icons
- [ ] "Copy link" row with 🔗 icon; tapping copies and shows "Now paste it in a chat" hint
- [ ] Cancel button dismisses sheet
- [ ] Tapping any app icon: visual feedback (scale animation) + sheet closes

---

### US-010: Profile screen
**Description:** As a user, I want to view and manage my profile.

**Acceptance Criteria:**
- [ ] Profile tab shows hero section: avatar initial, name, "Learning" chips (language + flag)
- [ ] Settings card (one container, dividers): Interface language | Edit profile | Change email | Change password | Log out
- [ ] "Interface language" row shows current language name in purple, tapping opens language sheet
- [ ] "Edit profile" navigates to Edit Profile screen
- [ ] "Change email" navigates to Change Email screen (US-039)
- [ ] "Change password" navigates to Change Password screen
- [ ] Tapping "Log out" first opens a confirm dialog (title: "Log out?", buttons: Cancel + Log out); only on confirm does it sign out and return to auth screen with all fields reset
- [ ] Avatar in the hero is tappable — opens the same photo action sheet as Edit profile (quick path)

---

### US-011: Edit profile
**Description:** As a user, I want to update my display name and photo.

**Acceptance Criteria:**
- [ ] Nav: back (‹) | "Edit profile" title | "Save" (top right)
- [ ] Avatar shown clean (no camera badge, no overlay icon). Press state = scale 0.96 + opacity 0.85 for tappable affordance
- [ ] Inline "PROFILE PHOTO" settings-card directly below the avatar with rows: Take photo / Choose from library / Remove photo (red). "Remove photo" only renders when a photo actually exists
- [ ] No bottom sheet on this screen — actions live inline
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
- [ ] Nav: back (‹) | avatar + name + subtitle ("Learning <language> <flag>") | ··· menu button
- [ ] No online / "last seen" indicator — Blab does not ship presence as a feature (privacy posture, see § Privacy)
- [ ] Subtitle line is replaced with "typing…" (brand color) while the partner is typing AND both sides have the typing-indicator toggle ON (see § Privacy)
- [ ] Back navigates to chat list

---

### US-014: ··· chat menu
**Description:** As a user, I want quick access to translation settings from within the chat.

**Acceptance Criteria:**
- [ ] Tapping ··· opens dropdown menu below nav
- [ ] Menu: "Show translations" toggle (green = on) + "Learning language [name] ›"
- [ ] Menu auto-width (no wrapping on long language names)
- [ ] Tapping outside closes menu
- [ ] "Show translations" toggle hides/shows all `.transl-line` rows in message area only
- [ ] "Learning language ›" opens change-language bottom sheet

---

### US-015: Messages — incoming with translation
**Description:** As a learner, I want to see my partner's messages in their language with an English translation below.

**Acceptance Criteria:**
- [ ] Incoming bubbles: white, left-aligned
- [ ] Main text = partner's language (Tamil for Nastia)
- [ ] Subtitle = English translation in gray
- [ ] Timestamp shown below bubble (no read ticks on incoming)
- [ ] Date divider "Today" shown above first messages of the day

---

### US-016: Messages — outgoing with read receipts
**Description:** As a sender, I want to see when my messages are delivered and (optionally) read.

**Acceptance Criteria:**
- [ ] Outgoing bubbles: purple, right-aligned
- [ ] Ticks are SVG double-checkmark (WhatsApp style), not text characters
- [ ] Delivered tick (gray) always shown — proves the message reached our server
- [ ] Read tick (purple) only shown when **both** sides have the "Read receipts" toggle ON (Signal-symmetric — see § Privacy). If either side has it OFF, ticks stay gray forever
- [ ] Read-receipt event is not sent at all when the sender's toggle is OFF (not just hidden on receive — the event never leaves the client)
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
- [ ] Tapping a word opens a popup. Layout: 🔊 speaker icon on the left, vertically centered; to its right, a single left-aligned column with target word (large, w700) / romanization (13 px muted, NOT italic) / English translation (15 px w500). All three text rows share the same left edge
- [ ] Speaker icon belongs to the target word (left side), not the English translation
- [ ] When TTS for the language is unavailable, the speaker icon stays in place but renders disabled: 40% opacity, no tap response, no tooltip, no text — silent disabled state. (FR-24)
- [ ] Popup positions above the tapped word; clamps to phone bounds (no overflow)
- [ ] × closes popup; tapping anywhere in message area closes popup
- [ ] Tapping a tappable word does NOT trigger long-press on the parent bubble

---

### US-019: Long-press on outgoing message
**Description:** As a user, I want to edit, copy, reply to, or delete my own messages.

**Acceptance Criteria:**
- [ ] Long-press (500ms) on outgoing bubble opens action sheet
- [ ] Action sheet: Reply | Edit (only while editable) | Copy | Delete
- [ ] Tapping outside sheet closes it
- [ ] Reply: shows reply bar above input with quoted message preview; send threads reply
- [ ] **Edit window: 24 hours** from the moment the message was sent (Signal-style). Past 24h the Edit row is hidden from the sheet
- [ ] Edit: inline text editing of the bubble content; edited bubbles show "· edited" 10 px muted label
- [ ] Copy: copies English translation text to clipboard; shows "Copied" toast
- [ ] **Delete: no time limit** — sender can delete any sent message forever (Signal-style). Removes the bubble on both sides; shows undo toast "Message deleted" with "Undo" for 3 seconds on the sender's side only

---

### US-020: Long-press on incoming message
**Description:** As a user, I want to reply to or copy messages from my chat partner.

**Acceptance Criteria:**
- [ ] Long-press on incoming bubble opens action sheet
- [ ] Action sheet shows: Reply | Copy only (no Edit, no Delete)
- [ ] Copy: copies original language text (not translation)
- [ ] Reply: same reply bar behavior as outgoing

---

### US-021: Reply bar
**Description:** As a user replying to a message, I want to see what I'm replying to.

**Acceptance Criteria:**
- [ ] Reply bar appears above input with purple left border, quoted preview text, × cancel
- [ ] Sending message includes visual quote block inside the bubble
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
- [ ] Send button dims (opacity 0.4) when input is empty; brightens when text entered
- [ ] Tapping send appends message and clears input

---

### FLOW 4 — Invite Flow + Aswin's Side

---

### US-024: Invite landing page
**Description:** As someone who received an invite link, I want to understand what Blab is before joining.

**Acceptance Criteria:**
- [ ] Web landing screen: Blab logo + tagline + "Nastia invited you to learn Ukrainian together 🇺🇦"
- [ ] Language exchange card shows: 🇺🇦 "She teaches you Ukrainian" ⇄ 🇮🇳 "You teach her Tamil"
- [ ] "Accept & join" CTA button
- [ ] Link validity: **valid until a single successful claim**, within a 48h TTL. Tapping the link multiple times before claim → still works. Once an invitee actually creates an account / signs in via the link, the link becomes "used" (US-037 state) for everyone else
- [ ] Sender can re-share the same URL within the 48h window if the recipient lost the message

---

### US-025: Invitee sign up
**Description:** As an invited user, I want to create an account and join the chat without friction.

**Acceptance Criteria:**
- [ ] Sign up form: name, email, password with same validation as Flow 1
- [ ] "Or continue with Google / Apple" SSO options
- [ ] Successful signup: push notification shown ("Aswin joined! Start chatting. 🎉"), navigates to Aswin's chat list

---

### US-026: Aswin's chat list
**Description:** As Aswin (newly joined), I want to see Nastia's chat ready and waiting.

**Acceptance Criteria:**
- [ ] Nastia's chat appears in list (avatar, name, timestamp "Now")
- [ ] Chat shows invite-state styling indicating new connection
- [ ] Tapping opens Aswin's chat view

---

### US-027: Aswin's empty chat — exchange card
**Description:** As a new chat participant with no messages yet, I want to see a reminder of who's teaching whom.

**Acceptance Criteria:**
- [ ] Exchange card centered vertically: 🇺🇦 "You learn Ukrainian" ⇄ 🇮🇳 "Help Nastia learn Tamil"
- [ ] Card fades out (200 ms opacity dissolve, no slide/scale) the moment the first message bubble appears
- [ ] No pre-seeded messages; card is the only content until the first send

---

### US-028: Aswin's chat — same core features as Nastia's
**Description:** As Aswin, I want the same chat capabilities Nastia has.

**Acceptance Criteria:**
- [ ] Ukrainian words tappable → popup with word, romanization, English meaning, audio
- [ ] ··· menu: Show translations toggle + Learning language (Ukrainian) ›
- [ ] Change learning language sheet (11 languages)
- [ ] Reply bar + incoming long-press (Reply + Copy)
- [ ] Input placeholder: "English or Ukrainian…"
- [ ] Send button dims when empty

---

### FLOW 5 — Cross-cutting (added during tech-spec gap audit)

---

### US-029: Word audio playback source
**Description:** As a learner, when I tap the 🔊 button in the word popup, I want to hear the word pronounced.

**Acceptance Criteria:**
- [ ] Audio is on-device TTS (platform-native: Android `TextToSpeech`, iOS `AVSpeechSynthesizer`) — no external API calls in the popup path
- [ ] If TTS for the target language is unavailable on the device, the 🔊 button is disabled with a tooltip "Voice not available"
- [ ] Tapping 🔊 while audio is playing replays from start (no queuing)

---

### US-030: Message send failure + retry
**Description:** As a sender, when a message fails to deliver, I want to retry without re-typing.

**Acceptance Criteria:**
- [ ] Outgoing bubble shows a small red ⚠ icon in place of read ticks when send fails
- [ ] Tapping the bubble opens an action sheet: Retry | Delete
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

### US-037: Invite link — expired / already used (recipient side)
**Description:** As someone tapping an invite link that's no longer valid, I want a clear explanation.

**Acceptance Criteria:**
- [ ] Expired (>48h): web landing shows "This invite has expired. Ask [name] for a new link." with no signup form
- [ ] Already used: web landing shows "This invite has already been claimed." with no signup form
- [ ] Both states show the Blab logo + "Get the app" link (no auto-redirect)

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
- [ ] When both sides are ON, US-016 behavior applies: delivered → read tick transition
- [ ] When either side is OFF, ticks stay at delivered (gray) forever

---

## Functional Requirements

- FR-1: Auth supports sign up, login, SSO (Apple/Google), forgot password — all as tab-toggle on one screen
- FR-2: Password field has show/hide toggle, strength meter visible during sign up only
- FR-3: Language picker available from auth screen and from profile settings; auto-saves on selection
- FR-4: New chat requires language selection before enabling share; invite link is valid until a single successful claim, within a 48h TTL
- FR-5: Share sheet surfaces WhatsApp, iMessage, Telegram, Email; copy-link action with confirmation hint
- FR-6: Chat list shows avatar, name, last message preview, timestamp, unread badge
- FR-7: Empty state shown when no chats exist
- FR-8: Profile settings in a single card: Interface language | Edit profile | Change email | Change password | Log out. Log out triggers a confirm dialog before signing out
- FR-9: Edit profile shows an inline "PROFILE PHOTO" card under the avatar with 3 actions (Take / Choose / Remove — Remove hidden until a photo exists). Save (in nav) returns to profile + shows "Profile updated ✓" toast
- FR-10: Change password has current/new/confirm fields with strength bar; success shows toast
- FR-11: Every word in partner's language is tappable → popup (word + romanization + translation + audio)
- FR-12: Popup positions above word, clamps to phone bounds, closes on tap-outside
- FR-13: Incoming messages show partner language + English translation subtitle
- FR-14: Outgoing messages show delivery (gray) always; read state (purple) only when both sides have Read receipts ON (Signal-symmetric, US-041). Default ON
- FR-15: Long-press on outgoing: Reply, Edit (24h window), Copy (translation), Delete (forever) + undo
- FR-16: Long-press on incoming: Reply, Copy (original text) only
- FR-17: Reply bar shows quoted message preview, threads into bubble on send
- FR-18: Consecutive outgoing messages group (reduced gap, no repeated timestamp)
- FR-19: ··· menu: show/hide translations toggle + change learning language, auto-width
- FR-20: Change learning language sheet: 11 languages, checkmark on current, updates header label
- FR-21: Send button disabled-state (dim) when input empty; input is auto-growing textarea
- FR-22: Exchange card shown centered on empty chat; fades out (200 ms opacity) on first message
- FR-23: Translations toggle scoped per chat (phone3 vs phone4 separate state)
- FR-24: Word popup audio uses on-device TTS only — no external API. When TTS unavailable for the language, speaker icon stays in place but renders disabled (40% opacity, no tap, no tooltip, no text)
- FR-25: Failed messages surface a retry affordance; pending messages distinguishable from delivered
- FR-26: Offline banner appears within 3s of connectivity loss; composed messages queue and auto-send on reconnect
- FR-27: Loading skeletons on first paint of chat list and chat view; failures use inline retry, not full-screen blockers
- FR-28: All interactive elements have semantic labels; tap targets ≥ 44pt; contrast ≥ WCAG AA; respects system font scaling
- FR-29: Push permission requested after first chat opens, not at launch
- FR-30: No online / "last seen" feature exists. Chat header shows learning-language subtitle, replaced by "typing…" only when both sides have Typing-indicator toggle ON (US-040)
- FR-31: Typing indicators + Read receipts are Signal-symmetric toggles in Privacy settings; default ON; OFF path = client never broadcasts the event (server has no record) AND user does not see partner's signal either
- FR-32: Edit window 24h; delete forever; both apply to outgoing messages only
- FR-33: Interface-language switch immediately re-renders existing translation subtitles and word popups on all loaded chats — no restart, no stale cache

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
8. **No moderation / blocking / reporting in V1** (already a Non-Goal). Personal-safety from harassment is out of scope and must not be claimed in marketing.

### What we do not promise

- We do **not** claim Signal-level metadata privacy. Sealed Sender, message-padding, traffic-shaping, etc. are V2+ research items in tech-spec.
- We do **not** claim "off the grid" or "uncompliable to subpoenas" — lawful EU requests still apply.
- We do **not** claim history is backed up. It isn't.

---

## Non-Goals (Out of Scope)

- No real backend, database, or user accounts
- No actual push notifications (simulated in prototype)
- No real audio playback (simulated play interaction)
- No real file/photo upload (photo action sheet is UI-only)
- No real invite link generation or validation
- No group chats
- No voice or video messages
- No AI translation or auto-translate
- No language matching algorithm / discovery feed
- No in-app payments or subscription
- No notifications settings screen
- No blocking or reporting

---

## Languages Supported (Prototype)

Dutch, English, French, German, Hindi, Italian, Portuguese, Spanish, Tamil, Turkish, Ukrainian

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
- **Interface-language switch refreshing existing translations?** → **Yes**, immediately. Translation subtitles + word popups re-render on switch, no app restart. (Updated US-005.)
- **Invite link single-use or reusable until claimed?** → **Reusable until claimed** (single *successful* claim), within the 48h TTL. (Updated US-024, FR-4.)
- **Exchange card disappearance on first message?** → **200 ms opacity fade-out**, no slide/scale. (Updated US-027.)
- **Edit-profile Save success toast?** → **Yes**, "Profile updated ✓" toast on return to profile. (Updated US-011.)
- **Log-out confirm dialog?** → **Yes** (Signal-style). "Log out?" with Cancel + Log out before actually signing out. (Updated US-010.)
- **TTS — on-device good enough or recorded fallback?** → **V1: on-device only.** Disabled state for unavailable languages = icon dimmed in place (40% opacity, no tap, no tooltip, no text). Cloud TTS or recorded human audio re-evaluated in V2 once we have real usage data on which languages matter most. (Updated US-018, US-029.)
- **Chat history across reinstalls — server-side or device-local?** → **V1: ciphertext on server, key on device, no key recovery.** Reinstall = lose history. Surface clearly in onboarding copy. V2 may add an optional passphrase-wrapped key backup. (See § Privacy posture #7.)
- **Typing indicators — ship or skip?** → **Ship as Signal-symmetric toggle.** Default ON. Off path = client never broadcasts. See US-040.
  - Bonus decision: **read receipts get the same Signal-symmetric toggle** (US-041), and the **"Online / last seen" feature is dropped entirely** — no toggle, no opt-out, the capability simply is not built. (Updated US-013, US-016.)
- **Edit / delete time window — forever or limited?** → **Edit: 24 h** (Signal-style). **Delete: forever** (sender can delete any sent message at any time, propagates to recipient). (Updated US-019.)
