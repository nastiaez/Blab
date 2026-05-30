# QA Report — 2026-05-25

## Summary
- Total flows tested: **13 of 13**
- Bugs found: **11** (0 critical, 4 major, 5 minor, 2 cosmetic)
- Device: Samsung S25, serial `RFCY20SH9SF`, app `sh.aswin.blab` (debug build), 1080×2340.
- No crashes observed across all 13 flows.

## Bugs

### BUG-001: Apple SSO button is missing on auth and invite-signup screens
- **Severity**: major
- **Flow**: 1 — `/auth` (Sign up tab, Log in tab); also Invite signup (`/invite/signup`)
- **Steps to reproduce**:
  1. Dev menu → "Sign up / Log in".
  2. Inspect the SSO area above the email form on both "Sign up" and "Log in" tabs.
- **Expected**: PRD US-003 — Two SSO buttons: "Continue with Apple" AND "Continue with Google", both above the email form, with their respective logos.
- **Actual**: Only "Continue with Google" is shown. No Apple SSO button exists anywhere in the auth screen (or on the invite-signup page).
- **Screenshot**: docs/qa/bug-no-apple-sso.png
- **PRD reference**: US-003 (FR-1)
- **Status**: fixed 2026-05-25

---

### BUG-002: Email validation does not run on blur — only on submit
- **Severity**: major
- **Flow**: 1 — `/auth` Sign up form
- **Steps to reproduce**:
  1. Open `/auth`, focus email field.
  2. Type an invalid value (e.g. `notanemail`).
  3. Move focus to the Name field (or any other field) to blur Email.
- **Expected**: PRD US-001 — "Email validated on blur — shows inline error 'Enter a valid email address' if invalid". The inline error should appear immediately after focus moves away.
- **Actual**: No inline error is shown on blur. The error "Enter a valid email address" only appears after pressing the Create account button.
- **Screenshot**: docs/qa/bug-email-blur.png
- **PRD reference**: US-001
- **Status**: fixed 2026-05-25

---

### BUG-003: "Back to log in" link returns to the Sign up tab, not the Log in tab
- **Severity**: major
- **Flow**: 1 — Forgot password → Check-your-email screen
- **Steps to reproduce**:
  1. Open `/auth`, switch to Log in tab.
  2. Tap "Forgot password?".
  3. Enter `me@aswin.sh`, tap "Send reset link →".
  4. On the "Check your email" screen, tap "Back to log in".
- **Expected**: PRD US-004 — "Back to log in" returns to the **login** tab.
- **Actual**: Returns to `/auth` with the **Sign up** tab selected (Name field visible, CTA reads "Create account →").
- **Screenshot**: docs/qa/bug-back-to-login.png
- **PRD reference**: US-004
- **Status**: fixed 2026-05-25

---

### BUG-004: Aswin's invite chat header & input placeholder say "English" instead of "Ukrainian"
- **Severity**: major
- **Flow**: 5 + 8 — Invite valid → signup → Aswin's chat list → open Nastia's chat
- **Steps to reproduce**:
  1. Dev menu → "Invite landing — valid" → Accept & join.
  2. Fill name/email/password, submit.
  3. On Aswin's chat list, tap the Nastia tile.
- **Expected**: PRD US-024/US-028 — Aswin is learning Ukrainian. Header subtitle should read "Learning Ukrainian 🇺🇦" and the message input placeholder should read "English or Ukrainian…".
- **Actual**: Header reads "Learning English 🇬🇧" (wrong language and wrong flag). Input placeholder reads "English or English…" (duplicated). The exchange card on the same screen correctly shows "You learn Ukrainian / Help Nastia learn Tamil", so the underlying state is right — only the header/placeholder are wired to the wrong language token.
- **Screenshot**: docs/qa/bug-learning-english.png, docs/qa/bug-placeholder.png
- **PRD reference**: US-024, US-028
- **Status**: fixed 2026-05-25

---

### BUG-005: Password "Fair" tier never appears — 8-char mixed-case is still rated "Weak"
- **Severity**: minor
- **Flow**: 1 — `/auth` Sign up form, password field
- **Steps to reproduce**:
  1. Open Sign up tab, focus Password field.
  2. Type `abc` → label = "Weak" (1 red segment) ✓
  3. Clear and type `Abcdefgh` (8 chars, upper + lower) → still "Weak".
  4. Clear and type `Abcdef1!23` → "Strong" (3 green segments).
- **Expected**: PRD US-001 + FR-2 — Strength bar has three tiers: Weak / Fair / Strong. A mid-quality password like `Abcdefgh` should land in the Fair bucket.
- **Actual**: Only two visible tiers — Weak (1 red segment) and Strong (3 green segments). "Fair" is never produced for any password I tried; the meter jumps directly from Weak → Strong when special chars/digits are added.
- **Screenshot**: docs/qa/bug-pw-strength.png
- **PRD reference**: US-001, FR-2
- **Status**: fixed 2026-05-25

---

### BUG-006: Stale "Enter a valid email address" error persists on Forgot-password screen after the user corrects the input
- **Severity**: minor
- **Flow**: 1 — Forgot password screen
- **Steps to reproduce**:
  1. `/auth` → Log in tab → "Forgot password?".
  2. Type `invalid`, tap "Send reset link →" — inline red error "Enter a valid email address" appears (correct).
  3. Without leaving the field, replace the text with a valid email (`me@aswin.sh`).
- **Expected**: When the field's value becomes valid, the red border + error string should clear immediately (or on the next blur).
- **Actual**: The red border and "Enter a valid email address" remain on screen even though the field now contains a valid email. Tapping Send proceeds correctly to the Check-your-email screen — the error is purely visual but misleading.
- **Screenshot**: docs/qa/bug-stale-error.png
- **PRD reference**: US-004 (inferred from validation feedback expectations)
- **Status**: fixed 2026-05-25

---

### BUG-007: Online indicator and "Online" label stay visible while the offline banner is shown
- **Severity**: minor
- **Flow**: 12 — Toggle offline (dev menu) + open chat
- **Steps to reproduce**:
  1. Dev menu → Toggle offline → on.
  2. Open Aswin chat.
- **Expected**: When the app is offline (banner visible), the partner's online dot + "Online" text shouldn't claim live status — it should be hidden, dimmed, or replaced with "Last seen…" / nothing.
- **Actual**: "No connection — messages will send when you're back online" banner is shown immediately below the nav bar **and** the header still says "Aswin · Online" with the green dot. These two states contradict each other.
- **Screenshot**: docs/qa/bug-offline-online-indicator.png
- **PRD reference**: US-031 (consistency)
- **Status**: fixed 2026-05-25

---

### BUG-008: Read receipts in Aswin's invite chat flip to "read" (purple) instantly — no delivered (gray) state visible
- **Severity**: minor
- **Flow**: 8 — Aswin's chat → first message
- **Steps to reproduce**:
  1. As in BUG-004, reach Aswin's chat with Nastia.
  2. Type "Hi", send.
- **Expected**: PRD US-016 / FR-14 — Ticks should start gray (delivered) and transition to purple (read) after ~1500 ms.
- **Actual**: Ticks render purple immediately on send; no gray-state frame is observable. Note: the existing Nastia↔Aswin chat (Flow 4) does show grayed timestamps that turn purple, so the behaviour is missing specifically in Aswin's POV chat. May be related to the same incorrect language-state issue that drives BUG-004.
- **Screenshot**: docs/qa/bug-placeholder.png (same screen, shows immediate `‹‹` purple read ticks at 16:58)
- **PRD reference**: US-016, FR-14
- **Status**: fixed 2026-05-25

---

### BUG-009: Word-lookup popup overlaps the chat header instead of clamping under it
- **Severity**: minor
- **Flow**: 4 — Open chat → tap a Tamil word near the top of the message list
- **Steps to reproduce**:
  1. Open Aswin chat.
  2. Tap the first Tamil word "காலை" in the topmost incoming bubble.
- **Expected**: PRD US-018 / FR-12 — Popup positions above the tapped word AND clamps to phone bounds (no overflow).
- **Actual**: Popup renders at the top-left of the screen, overlapping the chat header — it covers the partner's avatar/name. It is technically inside the screen bounds, but the implementation appears to clamp to the device viewport rather than to the message-list area, so it draws on top of the persistent nav bar.
- **Screenshot**: docs/qa/auth-signup.png is NOT this — see /tmp/word-popup-sm.png if needed; popup screenshot captured during test, header text "Aswin" partially obscured.
- **PRD reference**: US-018, FR-12
- **Status**: fixed 2026-05-25

---

### BUG-010: Word-popup 🔊 button is always tappable on a device with no Tamil TTS installed — no "Voice not available" affordance
- **Severity**: minor
- **Flow**: 4 — Word popup → speaker icon
- **Steps to reproduce**:
  1. Open Aswin chat (learning Tamil).
  2. Tap a Tamil word to open the popup.
  3. Tap the 🔊 icon.
- **Expected**: PRD US-029 — If TTS for the target language is unavailable, the 🔊 button should be **disabled** with the tooltip "Voice not available".
- **Actual**: The 🔊 icon is rendered enabled (full-opacity purple) regardless of whether Tamil TTS is installed on the device. Tapping produces no sound and no feedback (no SnackBar, no toast). The app does not crash, but there is no way for the user to know audio is unsupported. Note: no Tamil TTS voice is installed on this Samsung S25 (default Samsung TTS does not bundle Tamil), so this is the path US-029 exists to handle.
- **Screenshot**: (popup screenshot exists at /tmp/tts-sm.png; speaker is rendered normally)
- **PRD reference**: US-029
- **Status**: fixed 2026-05-25

---

### BUG-011: Tapping the camera-icon overlay on Edit Profile avatar does not open the photo sheet
- **Severity**: cosmetic
- **Flow**: 10 — Profile → Edit profile → camera icon overlay
- **Steps to reproduce**:
  1. Profile tab → Edit profile.
  2. Tap the small camera badge at the bottom-right of the avatar (NOT the avatar circle, NOT the "Change photo" link).
- **Expected**: PRD US-011 — "Tapping camera icon **or** 'Change photo' opens photo action sheet."
- **Actual**: Tapping the visible camera badge overlay does nothing. Only tapping the avatar circle proper, or the "Change photo" text link, opens the sheet. The camera badge appears at roughly (660, 575) in real coords, but the avatar's clickable rect ends at y=643; the badge graphic visually sits inside the rect, but the badge sub-element doesn't behave as a separate hit target and the rest of the badge area between the avatar and the text link is dead.
- **PRD reference**: US-011
- **Status**: fixed 2026-05-25

---

## Possible / unverified

- **No "Aswin joined! 🎉" notification banner visible** after the invite-signup submit landed on Aswin's chat list (PRD US-025). The route did transition correctly to the chat list, but no in-app banner/toast was captured. May be a fast-dismiss snackbar I missed between screen captures.

## Flows passed (no defects beyond bugs listed above)

1. **Sign up / Log in** — tab toggle, empty submit per-field errors, language picker (globe FR works, persists to Profile), legal links → SnackBar ("Terms (placeholder link)"), eye toggle on password, Forgot → Send reset link → Check your email screen, SSO Google → /chats. (Defects: BUG-001, 002, 003, 005, 006.)
2. **Your chats** — list with 3 tiles (Aswin/María/Lukas), avatars with initials, last message preview, timestamp, unread badge "2" on Aswin, tap → chat, "+" → /chats/new, Profile tab → /profile, back button works.
3. **Your chats — empty** — empty state with chat-bubble SVG icon, "No chats yet", subtitle, "Invite someone" button → /chats/new.
4. **Open a chat** — header (back, avatar+name, online dot, "Learning Tamil 🇮🇳", ··· menu); incoming bubbles white-left with English subtitle; outgoing purple-right with double-tick read state; grouped consecutive outgoing messages collapse their timestamp; "Today" date divider; tappable Tamil words → popup with romanization + English + 🔊; long-press outgoing → Reply/Edit/Copy/Delete (Copy → "Copied" SnackBar, Delete → "Message deleted [Undo]" SnackBar, Undo restores); long-press incoming → Reply/Copy only; Edit appends "· edited" tag after timestamp; reply-bar quote threads into the next sent bubble; ··· menu shows Show-translations toggle + "Learning language Tamil ›"; toggling translations hides English subtitles; learning-language sheet lists 11 languages with checkmark on current, auto-closes on select, updates header subtitle + input placeholder; character counter appears at 1800 ("1800 / 2000") and turns **red at 2000** with the input hard-capped at 2000. (Defects: BUG-009, 010.)
5. **Invite landing — valid** — Blab logo + tagline, "Nastia invited you to learn Ukrainian together 🇺🇦", exchange card (Ukrainian ⇄ Tamil), Accept & join → /invite/signup → Create account → Aswin's chat list.
6. **Invite landing — expired** — stopwatch-disabled icon + "This invite has expired" + "Ask Nastia for a new link." + "Get the app" link, no signup form.
7. **Invite landing — used** — broken-link icon + "This invite has already been claimed" + "Get the app" link, no signup form.
8. **Aswin's chats** — single tile "Nastia 🇺🇦", "New connection · say hi", "New" pill; tap → empty-state exchange card centred ("You learn Ukrainian ⇄ Help Nastia learn Tamil"); card disappears after first message sent. (Defects: BUG-004, 008.)
9. **Profile** — hero (avatar N, "Nastia", "Learning Tamil" chip), settings card (Interface language: French [persisted from auth lang picker change], Edit profile ›, Change password ›, Log out ›), Delete account row visually separated below the card in red, Log out → /auth with all fields reset.
10. **Edit profile** — nav `‹ Edit profile Save`, avatar with camera SVG overlay, Change photo link, photo sheet (Take photo / Choose from library / Remove photo / Cancel), DISPLAY NAME label above bordered text input pre-filled "Nastia", Save in nav returns to profile. (Defect: BUG-011.)
11. **Change password** — three fields with show/hide eye toggles, strength bar on New (turns Strong green for `NewPass1!`), mismatch validation on submit ("Passwords don't match" on Confirm with red border), Forgot link routes to /auth/forgot.
12. **Offline toggle** — banner "No connection — messages will send when you're back online" appears at the top of both /chats and the open chat view; banner disappears immediately when toggled off. (Defect: BUG-007.)
13. **Failed-send toggle** — composed outgoing message renders with a red ⚠ icon in place of the read ticks after a short delay; tapping the failed bubble opens a bottom sheet titled "Message failed to send" with Retry (purple) and Delete (red) actions.

## Notes

- The activity respects portrait orientation throughout (Samsung S25 default). Some screenshots render in landscape inside the Read tool, but `dumpsys window` confirms `mRotation=ROTATION_0` and PNGs are 1080×2340 — orientation is fine, just a viewer artifact.
- A green window border appears around the app surface intermittently — looks like Flutter's `debugPaintSize` / focus-visualization paint that activates after certain interactions (first observed after the failed-send toggle was flipped). Not a bug in the app itself, but worth flipping the build flag for release.
- Touch coordinates required compensation when the soft-keyboard opens (form shifts up by ~85 px). All UI dumps consulted with `uiautomator dump` after the keyboard appeared. No tests were blocked by this.
- The PRD's "blur validation on email" expectation (BUG-002) was tested by switching focus to the Name field (above email) so the Android keyboard stayed open — confirmed the email field did not validate on blur.
- The "9-language interface picker" on auth selected "French" → globe label changed from EN → FR, and persisted into Profile → Interface language. The picker itself does not localise the rest of the auth UI (subtitle stays "Language exchange, real conversations"), which appears intentional for the prototype.
