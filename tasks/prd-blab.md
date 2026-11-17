> **20513 ·17 November2026:** Nastia authorized scoped BLA22 commit, main integration and deployment after required quality/security/native gates. Existing Apple agreement/auth and both iOS release pause20294 remains; no Apple build/upload/login authorized. Native UK/accessibility/abuse acceptance remains open.

> **BLA-22 ·16 November2026 ·19998:** report-only journey implementation in dedicated worktree; [private inbox/acceptance record](../docs/translation-report-inbox.md). No automatic translation retry or authored-text/cache changes. Separate menu actions approved20021. Isolated SQL and connected native-sheet intake verified20300; full ordinary-entry/native parity and visual approval remain open. No merge/deployment/release approval.

> **BLA-43 (7 November 2026):** Nastia18294/18297 selects tap URL to external browser; long press URL to existing floating link container; long press non-link message area to existing reactions/actions. No competing menus or bottom-sheet redesign. Nastia approved18395 visuals in18499 and commit/main integration in18502; distribution is not authorized in this step.

> **BLA-39 ·approved18455 ·7 November2026:** profile-photo editor uses frozen [Paper V2](https://app.paper.design/file/01M3PCM6SC0AMB5Q0M3AZ58WBR/p-N-0). Native Camera/Photo → black crop/✓ → unsaved preview → Save; × creates draft removal; Back discards. Initials fallback. Google photo initializes new accounts once, never overwrites custom photos or restores removal; signup remains name-only, no extra consent/review screen. Illustrations and custom gallery excluded. Static approval does not approve implementation or distribution.

# PRD: Blab — Language Exchange Chat App

> **BLA-40 ·2 November2026:** approved URL/menu contract and preserved report: [inline links](../docs/specs/2026-11-02-bla40-inline-links.md). Reviewed Android visuals/journey and commit/main integration approved17374; release explicitly held.

> **BLA-17 approval16778 ·29 October2026:** corrected native implementation clip accepted; scoped current-main reconciliation, commit and integration authorized after verification. Message/text tap opens separate matching-cream anchored functions/reactions; composer retained, scrolling finite and panels fixed in stable viewport. Writing-field tap immediately deselects/closes both panels without changing native keyboard/draft behavior; Edit remains separate. Newer mention identity/styling/picker-overlay behavior must survive. Distribution/uploads/notices/tester sends remain held. Tiny/top fallback, universal readability and async lifecycle are not inferred approved. Evidence: [integration QA](../docs/qa/2026-10-29-bla17-integration/README.md).

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
| Flow 1 | Onboarding + Auth | New and returning users |
| Flow 2 | Main App — Chats + Profile | Nastia (existing user) |
| Flow 3 | Chat view | Nastia (learning Tamil from Aswin) |
| Flow 4 | Invite + Join + Chat | Aswin (new user, learning Ukrainian) |

---

## User Stories

### FLOW 1 — Authentication

---

### US-001: Refreshed onboarding introduction
**Description:** As a new or returning user, I want to understand why Blab is exciting before I am asked to authenticate or complete profile setup.

**Acceptance Criteria:**
- [ ] Every signed-out entry begins with Welcome, then Learn in context, including after logout or reinstall
- [ ] Existing signed-in accounts below the current onboarding version see the introduction once without losing their session
- [ ] Welcome uses the approved Paper composition and copy; Learn reproduces the approved HTML dialogue animation and vocabulary popup
- [ ] Continue never waits for the animation cycle and routes through the central onboarding resolver
- [ ] Hold the animated conversation to pause it; release resumes from the same point. No tap-toggle or added controls. Reading holds are longer and exquisite in the incoming sentence uses normal weight (BLA-7, owner14478).
- [ ] Reduced motion shows the final corrected dialogue and open popup without looping motion
- [ ] Completing the refreshed introduction is persisted per account after authentication; a failed acknowledgement safely replays it

---

### US-002: Sign up and log in with email
**Description:** As a user, I want clear, separate email signup and login paths that retain Blab's working authentication behavior.

**Acceptance Criteria:**
- [ ] Sign up method and Log in method are separate screens with reciprocal navigation
- [ ] Email signup asks for email and password only; name is confirmed after account creation
- [ ] Email login asks for email and password and exposes Forgot password
- [ ] Email, password, strength, existing-account, incorrect-credential, loading, offline, and retry states remain inline and retain recoverable input
- [ ] Email signup does not require email confirmation
- [ ] Every success routes through the central resolver, never directly to Chats

---

### US-003: Google authentication
**Description:** As a user, I want to authenticate with Google and then explicitly confirm my Blab profile setup.

**Acceptance Criteria:**
- [ ] Sign up method and Log in method both offer native Google authentication
- [ ] Cancellation is silent; provider, configuration, exchange, and offline failures are inline and retryable
- [ ] A new Google account receives the provider display name as an editable proposal on Confirm name
- [ ] An existing Blab display name always wins over current Google metadata
- [ ] The returned account/profile state determines the next route; the label of the button does not assume whether the account is new
- [ ] Duplicate actions are disabled while Google authentication is active
- [ ] Apple sign-in remains deferred to the iOS phase

---

### US-004: Forgot password
**Description:** As a user who forgot their password, I want to request a reset link via email.

**Acceptance Criteria:**
- [ ] Forgot password opens from email login with a valid entered email pre-filled and editable
- [ ] Accepted requests show Check your email without revealing whether an account exists
- [ ] Check your email supports resend cooldown and Change email without losing the address
- [ ] A valid recovery callback opens Set a new password
- [ ] Weak, mismatched, offline, update-failure, and expired-session states remain inline
- [ ] Expired, malformed, already-used, or unexchangeable links open Reset link expired with Request a new link
- [ ] Successful password update clears recovery-only state and returns to email login with a quiet acknowledgement

---

### US-005: Interface language selector
**Description:** As a user, I want to set my interface language before or during sign up.

**Acceptance Criteria:**
- [ ] Welcome and Learn expose a language control containing English, Ukrainian, German, and Spanish
- [ ] Selecting a language updates all localizable onboarding/auth copy immediately
- [ ] English is the first-launch default and fallback; selecting another language updates all localized app chrome
- [ ] Same sheet accessible from Profile → Interface language
- [ ] The pre-auth choice persists locally; a signed-in choice persists to that account without leaking across logout/account switches
- [ ] An explicitly changed guest language is synchronized after both email and Google authentication; an unmarked guest default never overwrites an existing account preference
- [ ] Switching the interface language immediately re-renders interface copy only; sentence translations, word descriptions, and audio remain unchanged
- [ ] A successful signed-in change returns to Profile and shows a target-locale `Switched to [language] · Undo` Snackbar for 4 seconds, with no close icon; navigation dismisses it, while an unrelated tap does not

### US-005A: Confirm display name
**Description:** As a new or migrated user, I want to confirm the name other people will see before entering Blab.

**Acceptance Criteria:**
- [ ] New email accounts begin blank; new Google accounts propose the provider name; existing accounts prefill the saved Blab name
- [ ] The value remains editable and requires an explicit Next action even when prefilled
- [ ] Name is trimmed, limited to 1–50 characters, rejects control characters, and keeps input through recoverable failures
- [ ] Saving the name and advancing onboarding is one atomic, idempotent, self-only server operation

### US-005B: Choose translation language
**Description:** As a user, I want to choose the one language Blab translates messages into before entering Chats.

**Acceptance Criteria:**
- [ ] The screen offers Dutch, English, French, German, Hindi, Italian, Portuguese, Spanish, Tamil, Turkish, and Ukrainian in that order
- [ ] Exactly one language can be selected; Start chatting is disabled until a selection exists
- [ ] A legacy client English fallback is not treated as an explicit choice
- [ ] Existing known languages are preserved; the selected language is added when missing and becomes the primary translation language
- [ ] Saving language and completing the current onboarding version is atomic, idempotent, and self-only
- [ ] Interrupted setup resumes at Confirm name or Language you understand without bypassing pending invite continuation

---

### FLOW 2 — Main App (Chats + Profile)

---

### US-006: Chat list
**Description:** As a user, I want to see all my active language exchange chats in one list.

**Acceptance Criteria:**
- [ ] "Chats" tab active by default
- [ ] Each chat item shows: avatar (initial), name, last message preview, timestamp, unread badge
- [ ] Tapping a chat opens the chat view (Phone 3)
- [ ] "+" button navigates to Invite a friend once at least one chat exists; the empty state hides it to avoid duplicating its primary action
- [ ] A newly claimed connection appears in the same priority position as an unread message with preview `Ready to chat · Say hi`; it remains unread until that participant chooses a practice language

---

### US-007: Empty state — no chats
**Description:** As a new user with no chats, I want to see a clear prompt to start one.

**Acceptance Criteria:**
- [ ] If no chats, show the approved two-friends pixel illustration + "Start your first chat" + "Practice a language through real conversations." + "Invite a friend" button
- [ ] The empty state has no duplicate "+" action; the button navigates to Invite a friend
- [ ] A successfully claimed invite bypasses the empty state and shows the new connection in Chats after authentication; tapping that chat opens its initial practice-language choice (US-025, BLA-6 clarification21 October).

---

### US-008: Invite a friend
**Description:** As a user, I want to send one clear invite link so a friend can join Blab and start a chat with me.

**Acceptance Criteria:**
- [ ] Entry points are Chats + and the no-chats `Invite someone` action; there is no contacts screen, contacts permission, or language picker before this page
- [ ] Paper V15 (p-B-0; owner feedback15235/15241, build15272) supersedes old sender visuals: header `Invite a friend`; centered `Let’s chat on Blab`, link card with explicit `Copy link`, then native `Share link`. No hero icon/background, subtitle, or helper below Share.
- [ ] Primary `Share link` native FilledButton.icon opens the native share sheet directly; no intermediate custom sharing menu
- [ ] The shared text is `Let’s chat on Blab` plus the invite URL
- [ ] Returning from Copy or another app returns to this same page, not Chats; no success page is shown
- [ ] One personal link remains valid for unlimited distinct recipients until explicit Regenerate; sharing or Copy never rotates it. Reset link lives in the overflow menu behind a native confirmation and atomically revokes every previous link for this owner
- [ ] The first link is prepared in the background for a signed-in online user, so the first visit normally opens ready to share
- [ ] While offline, the standard `No connection` banner is visible and `Share link` is disabled; no special offline card or second banner is shown
- [ ] If preparing the next link fails while online, show inline `Couldn’t prepare a new invite. · Try again` below the card and keep `Share link` disabled until it succeeds

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
- [ ] `Languages you understand (N)` keeps selected languages visible as compact chips with a separate add action and no unexplained primary-language star
- [ ] A `Translation language` row below the chips shows the current language and opens a matching single-select editor; selecting a new language also adds it to Languages you understand
- [ ] Both language editors use the shared warm selected-row/check pattern, localized explanatory copy, inactive unchanged Save, Back-to-discard, and in-place save failure recovery
- [ ] Tapping "Log out" first opens a confirm dialog (title: "Log out?", buttons: Cancel + Log out); only on confirm does it sign out and return to auth screen with all fields reset
- [ ] Learning language is shown only within its chat because it is a per-chat setting

---

### US-011: Edit profile
**Description:** As a user, I want to update my display name.

**Acceptance Criteria:**
- [ ] Nav: back (‹) | "Edit profile" title | "Save" (top right)
- [ ] Static initial avatar is shown without photo actions or upload affordances
- [ ] "DISPLAY NAME" label above bordered text input pre-filled with current name
- [ ] Tapping "Save" in nav waits for the server, then returns to Profile with the saved display name immediately visible and no redundant success toast
- [ ] A failed save stays on Edit profile and shows the error beside the form

---

### US-012: Change password
**Description:** As a user, I want to change my password securely.

**Acceptance Criteria:**
- [ ] Fields: Current password, New password (with strength bar), Confirm new password
- [ ] All password fields have show/hide toggle
- [ ] "Save" button submits; returns to Profile with a compact light confirmation containing a leading check-circle and localized "Password updated" copy; no trailing checkmark or close icon
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
- [ ] Tapping the link in the new inbox opens Profile and shows a compact light confirmation with a leading check-circle and localized "Email changed" copy; no trailing checkmark or close icon
- [ ] The confirmation appears only after the signed-in account's email truly changes; opening the callback route alone shows no success feedback
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
- [ ] Back navigates to Chats from every chat entry path, including notification/direct entry; an active reply is cancelled first without leaving the chat
- [ ] While more than200 logical pixels from the newest messages, show a small floating down-arrow at the bottom-center of the timeline, above the composer/reply/keyboard/emoji panel. Tap returns to newest messages and hides the button. Preserve drafts, mode and focus; incoming messages do not force history readers to the bottom. Reduced motion uses an immediate jump

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
- [ ] The interface language controls app chrome only; it is never a message-translation, word-description, or learning-explanation target
- [ ] If an author makes a clear mistake in their learning language, that author sees the minimal correction inline with replaced text struck through and the replacement emphasized
- [ ] In Practice, recipients see the author's correction marks only when both participants had the same Learning Language at send time; otherwise they see one clean corrected learning-language line
- [ ] Struck-through correction text has no explanation action for either participant; chat taps use BLA-17 message selection
- [ ] Shared-correction eligibility is fixed when the message is created, remains unchanged after either participant changes language, and is false for messages created before this rule ships
- [ ] Correct target-language writing remains clean; uncertain author corrections are labeled "Possible correction" and do not invent missing meaning
- [ ] Sender and receiver reuse the same correction cache variant when their learning and primary known languages match
- [ ] Use only two response acceptance rules: loose readable structure identifying requested sentences, and nonempty translation text. Allow extra fields and missing optional metadata; word help or form metadata must not reject the sentence. (Owner, 2026-10-16.) Mention identity is the mandatory integrity exception: reject invented, lost or duplicated sentence handles, including zero-selection inputs; discard invalid optional enrichment without rejecting a valid sentence (approved fix17217, 2026-11-02).
- [ ] Message text uses BLA-17 message selection; unrelated word-help surfaces use the reader's Primary Known Language
- [ ] Reaction pills overlap the lower outer bubble corner and grow inward toward the conversation center (left anchored for incoming, right anchored for outgoing) so wider mixed reactions remain onscreen on short messages; one shared oval pill uses `#FFFCF8` fill and `#DCD2C8` outline, with a subtle shadow in Practice only; distinct emojis sit side by side and the total number of reacting people appears inside the pill on the right (owner14372, 20 October 2026), including a count of1; no floating per-emoji number badges
- [ ] Message/text tap opens anchored reactions/actions; old message word lookup and long-press entry are removed (BLA-17 correction16176)
- [ ] Practice message selection temporarily reveals the reader's primary-known-language translation below the existing divider; Normal conditionally offers Original for the exact authored text
- [ ] With learning aids disabled, authored text is shown and no new AI request is made
- [ ] Expressive stretching, playful capitalization, and chat abbreviations are treated as style rather than mistakes; confidently identified names are transliterated into a different target script without changing their identity, while uncertain name-like text remains authored
- [ ] If source language is outside Blab's supported language set, keep the exact authored text and show one neutral localized hint (`Blab doesn’t speak this one yet.`) in muted 12 px text; do not show Retry, Listen, Original, or word-description actions
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

### US-018: Word lookup surfaces
**BLA-17 supersession:** ordinary chat message/text taps select the message and open anchored panels, not word lookup; held press does not enter the old menu. Onboarding and unrelated word-help surfaces retain existing popup/audio behavior. Primary Known Language and Learning Language mapping is unchanged.

---

### US-019: Message actions on outgoing messages
**Description:** As a user, I want to edit, copy, reply to, or delete my own messages.

**Acceptance Criteria:**
- [ ] Double-tap a delivered incoming or outgoing message to toggle your heart reaction; repeating removes your heart, never the other participant’s. A different own reaction is replaced by a heart. Message/text taps follow BLA-17; swipe reply and failed-message recovery retain their existing behavior (BLA-21, owner clarification 2026-10-20).
- [ ] Message/text tap opens separate anchored function/reaction panels, retaining composer and whole-chat scroll. Measure the complete pair below, then above, then approved long overlap. Remove old message word lookup and long-press entry
- [ ] Practice actions: Listen | Reply | Edit | Copy | Delete; Normal actions: Reply | Edit | Copy | Original | Delete, with conditional actions hidden when ineligible
- [ ] Practice message selection temporarily reveals the primary-known-language translation; Normal Original temporarily reveals exact authored text below the existing divider
- [ ] Whole-chat scroll retains fixed panels and temporary content in a stable viewport; writing-field tap and outside tap dismiss immediately; geometry-changing lifecycle remains a review gate
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
- [ ] Double-tap a delivered incoming or outgoing message to toggle your heart reaction; repeating removes your heart, never the other participant’s. A different own reaction is replaced by a heart. Message/text taps follow BLA-17; swipe reply and failed-message recovery retain their existing behavior (BLA-21, owner clarification 2026-10-20).
- [ ] Message/text tap opens separate anchored function/reaction panels, retaining composer and whole-chat scroll. Measure the complete pair below, then above, then approved long overlap. Remove old message word lookup and long-press entry
- [ ] Practice actions: Listen | Reply | Copy | Report; Normal actions: Reply | Copy | Original | Report, with conditional actions hidden when ineligible
- [ ] Copy and Reply use the complete primary text currently presented in chat; a translation failure therefore uses the readable authored text
- [ ] Whole-chat scroll retains fixed panels and temporary content in a stable viewport; writing-field tap and outside tap dismiss immediately; geometry-changing lifecycle remains a review gate
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
- [ ] Cancel (×) or Back dismisses an active reply without leaving the chat; typed composer text is preserved
- [ ] Tapping the quote in a sent reply navigates to the original message, loading older authorized history when needed

---

### US-022: Change learning language (in-chat)
**Description:** As a user mid-chat, I want to change which language I'm currently learning.

**Acceptance Criteria:**
- [ ] Bottom sheet follows `2026-09-12-learning-language-sheet-unification-design.md`: `I want to learn...` heading, helper, 11-name scrollable list, selected-row fill, checkmark, slim scrollbar, and persistent **Done** action
- [ ] Current saved language is selected on opening; tapping another language previews it only
- [ ] **Done** commits the visible choice, updates the chat header and ··· menu label, and closes the sheet on success
- [ ] Backdrop tap and swipe-down close the sheet without changing the saved language; reopening shows the prior saved choice
- [ ] A save in progress locks the sheet and uses the button-only spinner; a failed save restores the same **Done** action with no separate error or retry UI

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
- [ ] After successful authentication, Blab claims the saved invite and opens Chats without a practice-language prompt. The new connection remains unread; tapping that chat opens its required language choice. Explicit signed-in invite-link navigation may still open its specific chat directly (BLA-6 clarification, topic8856,21 October).
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
- [ ] Required bottom sheet follows `2026-09-12-learning-language-sheet-unification-design.md`: title `I want to learn...`; helper `You can change it later in Settings.`; 48 px separated language rows; selected-row fill and check; slim scrollbar; and a persistent **Start practicing** action
- [ ] The sheet shows over the chat with no blur and a `#231208` 30% veil; authored first messages remain visible behind it if they already exist
- [ ] At the 430 × 932 reference viewport, the required and Settings variants are both 567 px high; other viewports use the same `567 / 932` height proportion, capped at 567 logical px plus the bottom safe area
- [ ] The sheet is bottom-anchored, uses 16 px top corners with no drop shadow, covers the empty-state note, and keeps the language list as its only scrolling region
- [ ] A fresh chat starts with no selection and a disabled **Start practicing** action. Tapping a language previews it; **Start practicing** is the only action that commits it
- [ ] Tapping outside or swiping down does not close the sheet; composer, messages, and mode switch are inactive until selection
- [ ] Back leaves for Chats; reopening the new chat shows the required sheet again. Profile and Settings remain reachable outside the chat
- [ ] Each participant's choice is independent and affects only their own display

---

### US-028: Aswin's chat — same core features as Nastia's
**Description:** As Aswin, I want the same chat capabilities Nastia has.

**Acceptance Criteria:**
- [ ] All core chat features follow Flow 3 after the required initial practice-language selection
- [ ] Before selection, authored text remains uncorrected and untranslated; after selection, messages and previews use the participant's Practice result where applicable
- [ ] Reply preview + incoming message selection follow US-020 / US-021, including Normal Original, Practice Listen, and Report eligibility
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
**Description:** As a user without internet, I want messages to queue and cached chats to remain usable without global connection banners. Revised by owner, 2026-10-19.

**Acceptance Criteria:**
- [ ] No global "Connecting…" or "No connection" banner, text or spinner on launch, resume, access refresh, or connection loss; no empty banner space
- [ ] Connectivity monitoring, tester-access checks and message-level pending/failure feedback remain unchanged; update-available notices are a separate feature
- [ ] Composed messages queue locally and auto-send on reconnect
- [ ] Chat list still opens; existing chats render from local cache. Transport failures in test-access refresh never replace chat with a blocking error; ended sessions retain the chat and draft without a session-ended screen; not-approved or configuration-mismatch decisions remain blocking across offline refresh/resume (BLA-16, owner correction 20 October). Server-side command authorization remains unchanged.
- [ ] Invite a friend keeps its normal layout without a connection banner and disables `Send invite` while offline
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
- [ ] Tapping opens a localized confirmation explaining permanent removal of account access, profile, settings and private account data, while existing messages and media remain visible to their authorized conversation recipients (BLA-31, Nastia approval16789, 29 October2026). This is the candidate policy; do not publish before the matching implementation is verified.
- [ ] Confirmation-only deletion: reuse the existing Delete account page and final Cancel / Delete forever dialog; no password, email-entry or reauthentication step (Nastia17520, 2 November2026, option1). The authenticated session remains required server-side.
- [ ] On success: all local data wiped, returns to auth screen
- [ ] Deletion is irrevocable (no grace period in v1)
- [ ] Recipient-visible existing direct-chat messages/media and group history remain; explicit message deletion and personal history cutoffs are never undone. Remove unnecessary profile/auth data and revoke all deleted-account access.
- [ ] Authoritative deleted-account state renders neutral `Deleted account` identity, direct-chat notice `This account has been deleted. You can no longer send messages.` and list preview `Account deleted`; no missing-profile inference or broadcast push.
- [ ] Deleted-account direct chats are read-only server-side and in realtime/offline clients. Existing personal chat deletion and blocking controls/behavior remain unchanged; no new delete-for-both option (Nastia16797).
- [ ] Shared groups continue, reusing the existing account-erasure owner handover (active remaining account, then earliest join); sole-member groups close.
- [ ] Signing up again, including with the same email, creates a new identity without restoring previous chats, memberships or ownership.

---

### US-036: Message length cap
**Description:** As a system, I want a reasonable upper bound on message size.

**Acceptance Criteria:**
- [ ] Hard limit: 2000 characters per message
- [ ] Character counter appears below input at 1800+ characters, red at 2000
- [ ] Send button disabled when over limit
- [ ] The chat composer has the approved left emoji icon. Tap to replace the keyboard with an inline emoji panel; the icon becomes a keyboard to return to typing. Tapping the message field also returns to typing
- [ ] The normal emoji panel occupies the same total bottom space as the measured keyboard, including navigation inset; switching in either direction keeps the composer level. Search may show its own text keyboard with compact results
- [ ] Emoji picks insert at the cursor or replace selected text, preserve the draft/reply/edit target and obey the same 2000-grapheme budget; panel backspace deletes one whole emoji or the selection
- [ ] Back closes the emoji panel before cancelling a reply or navigating away. Emoji search and accessible button labels follow Interface Language, not Learning Language
- [ ] The panel supports repeated picks, categories, recent emojis, skin tones and search; sending keeps the panel available for the next message. No stickers/GIFs are included in this slice

---

### US-037: Invite link — invalid / already used (recipient side)
**Description:** As someone who cannot use an invite link, I want a clear explanation and a way back to Blab.

**Acceptance Criteria:**
- [ ] Invite links do not expire with time; a personal link remains valid for unlimited friends until its owner regenerates it
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

- [ ] Notification receipt prefetches authorized recent messages and already-prepared language variants into the active account's cache when background execution/network permits; notification payloads remain routing hints, not message content or authorization
- [ ] A tap preserves warm chat data, refreshes the target history and chat list concurrently, and opens directly to readable history without an artificial display delay; offline/cold/background limits retain truthful cached/loading recovery

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
**Description:** As a learner, I want complete natural translations with an understandable, correctable grammatical-form suggestion, without choosing unfamiliar foreign words.

**Acceptance Criteria:**
- [ ] Always render a complete sentence. Use the affected person's saved form first, otherwise a provisional suggestion from their name; use feminine when unclear. Do not paraphrase to avoid the choice. Name suggestions never silently save a confirmed profile form.
- [ ] No grammatical gap markers, numbered markers, word-choice containers, help icon, or new explanatory sheet.
- [ ] Once per participant per chat, attach `Using feminine forms for [name] · Change` or `Using masculine forms for [name] · Change` below the first relevant message encountered. Use the same localized wording for every person; “forms” includes verbs, pronouns, adjectives and linked agreement.
- [ ] Change opens existing Chat → Translation preferences. The note remains attached to that message; later messages do not repeat it.
- [ ] Matching preference changes update that annotated message plus future translations, regardless of message age, visibility or intervening messages. Other completed messages remain unchanged. Clearing the preference restores the provisional suggestion/feminine, never a gap. Exact rules: `docs/superpowers/specs/2026-09-11-automatic-grammatical-forms-design.md`.
- [ ] Resolve the affected person before suggesting a form: direct “I” is the author and direct “you” is the recipient, independently of who views the chat. A participant's preference never applies to the other participant.
- [ ] A first clear form authored directly in the learning language is accepted and remembered silently, with no correction mark