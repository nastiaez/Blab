# Physical Android Launch QA Plan

**Goal:** Close the launch checks that genuinely require a real Android phone, while keeping onboarding, visual-design work, store preparation, and non-device security work in their own tracks.

## Test setup

- Use one physical Android phone connected to the development computer by USB.
- Enable Developer options and USB debugging, then accept the computer authorization prompt.
- Install a private staging/release candidate directly with ADB. Blab does not need to be public in Google Play.
- Use the physical phone as one participant and the existing browser or Android emulator on the computer as the second participant.
- Use disposable test accounts for signup, password/email changes, report/block, and deletion.
- Keep screenshots, device/build identity, pass/fail result, and defect notes for each packet.

## Phase 0: Repair before testing

These are known product gaps, not useful manual tests until the implementation exists.

1. Restore completed text and photo-caption translations after an offline restart (L-26).
2. Open a received invite correctly when Blab is already running (L-24).
3. Remove the dead Apple sign-in action from Android v1.

## Phase 1: Physical-phone session on the private staging build

### Packet A: Installation and account journey

- Install, cold-start, and reopen the app.
- Email signup and verification.
- Google sign-in on the staging identity if the installed candidate is configured for it.
- Reset password, change password, change email, edit name, log out, and sign back in.
- Delete a disposable account and confirm the session/data behavior.

### Packet B: Invite and two-device continuity

- Create and share a fresh invite.
- Open it from the physical phone with Blab closed, backgrounded, and already open.
- Sign up/sign in, claim it once, and confirm both participants reach the same chat.
- Confirm a reused invite cannot create a duplicate chat.
- Verify the no-app web fallback separately on a device/browser without Blab.

### Packet C: Live messaging and media

- Send and receive text on both clients.
- Verify reply, edit, delete/undo, reactions, read receipts, typing, reconnect, and chat-list updates.
- Exercise gallery permission denial/approval, multi-select, camera, preview, caption, send, receive, full-screen viewing, and sharing an image into Blab.
- Confirm existing messages/photos remain usable after app restart.

### Packet D: Offline and recovery

- Enable airplane mode, send a message, reconnect, and confirm automatic delivery.
- Trigger a controlled server failure, confirm Retry, and verify successful recovery.
- Queue a message, close/reopen the app, reconnect, and confirm the queue survives.
- After an online translation completes, restart offline and confirm the same text and photo-caption translation is restored.
- Switch accounts and confirm cached translations never cross accounts.
- Change one participant's learning language and confirm older completed messages keep their original language while later messages use the new language (L-25).

### Packet E: Safety

- Report an incoming message and report the person.
- Block the partner; confirm the chat disappears and new contact/messages are prevented.
- Unblock; confirm the chat returns and communication works again.
- Confirm the report reaches the moderation intake without exposing unrelated message data.

### Packet F: Accessibility and device behavior

- Complete the key journey with TalkBack: signup/sign-in, chat list, chat, compose, send, message actions, profile, and logout.
- Test Android font size/display size at 200%.
- Check focus order, spoken labels, tap targets, contrast, keyboard overlap, and reduced-motion behavior.
- Rotate/background/reopen during the critical journey and check for crashes or lost state.

### Packet G: Crash reporting

- Use the staging/release candidate's test-error action.
- Confirm the event reaches the correct Sentry environment promptly.
- Confirm the report contains no message text, email, token, or other sensitive content.

## Phase 2: Notification session on a Firebase-enabled release candidate

Run this only when the installed candidate, Firebase project, Supabase notification worker, and environment identity match.

- Permission appears after the first authenticated chat opens, not at startup/sign-in.
- Denial reminder appears once, can be dismissed, and Profile opens Android notification settings.
- Preview on: background/terminated message notification shows sender plus bounded original text, never a translation.
- Preview off: notification is generic and exposes no sender/message text.
- Taps from background and terminated states open the correct chat once.
- Foreground messages do not create duplicate system notifications.
- Account switching does not leak notifications between accounts.
- Invite claim notifies the inviter and opens the resulting chat.
- Failed notification delivery never fails or duplicates the saved message.

## Phase 3: Final Play-installed release session

Run only after Play App Signing, Google OAuth certificate registration, website association, and internal-track upload are complete.

- Install from the Play internal/closed track, not by USB.
- Verify Google sign-in on the Play-signed identity.
- Verify a valid invite opens Blab directly with Android domain verification and no chooser.
- Repeat the critical signup -> invite -> chat -> media -> safety -> settings smoke journey.
- Repeat notifications, crash reporting, accessibility smoke, cold startup, background resume, and basic performance/ANR review.
- Record the final owner go/no-go result.

## Explicitly outside this phone plan

- Onboarding copy/flow implementation and first-user design review: owned by the onboarding branch. A short onboarding smoke check belongs only in the final Play session after that branch merges.
- Visual consistency/UI polish: owned by the UI branch. Only device-breaking issues such as clipping, unreadable text, or blocked controls should be reported here.
- Language and localization QA: completed and published in commit `34d6d04`; the hosted tracker is stale on this item.
- Store screenshots, feature graphic, listing copy, content rating, Data Safety, privacy/legal publishing, reviewer instructions, and release notes.
- Credential protection, repository/history secret scan, production-service parity, and disclosure reconciliation.
- Play Console creation, signing-key restoration, certificate registration, internal-track upload, closed-test administration, and the 48-hour stability window.
- Post-launch ideas and iOS work.

## Estimate

- Setup and private build installation: 15-20 minutes.
- Phase 1 physical-device QA: 90-120 minutes if no blocking defect appears.
- Phase 2 notification matrix: 30-45 minutes after the Firebase-enabled release candidate is ready.
- Phase 3 Play-installed final smoke: 45-60 minutes after the Play internal build is ready.

Plan two shorter physical-phone sessions instead of one long session. The phone owner should expect roughly 30-45 minutes of active participation across Phase 1; the remaining steps can be driven from the development computer once USB debugging is authorized.
