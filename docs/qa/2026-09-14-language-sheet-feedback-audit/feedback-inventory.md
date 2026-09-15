# Current feedback-state inventory

Date: 2026-09-14
Scope: read-only audit before redesign. No feedback-state UI has been changed.

## Recommended categories

1. **Completed actions** — short-lived confirmation after an action succeeds.
2. **Recoverable action failures** — an attempted save/share/safety action failed; the current screen remains usable.
3. **Connectivity and blocked availability** — the app or a specific action cannot work until the network returns.
4. **Content recovery** — a page, list, invite, or profile could not load and owns its Retry action.
5. **Message-owned recovery** — sending or language help failed for one message.
6. **Field-owned validation** — invalid form input; stays next to the relevant field and should not use global feedback.

## 1. Floating action feedback

**Current container:** Material floating snackbar, dark inverse-surface rectangle, white close icon, above the bottom tabs/composer. Plain messages remain for about 2.2 seconds; an action remains for 4 seconds.

### Completed actions

| Copy | Location |
| --- | --- |
| `Switched to {language}` + `Undo` | Profile → Interface language |
| `Profile updated ✓` | Profile → Edit profile; Profile → Known languages |
| `Password updated ✓` | Profile → Change password; reset-password completion |
| `Email changed` / `Email changed ✓` | Return from email-confirmation link; two current code paths disagree about the checkmark |
| `Invite sent ✓` | Invite a friend → successful native share |
| `Thanks — we'll review this.` | Chat → report message; partner profile → report person |
| `{name} blocked` | Partner profile → Block |
| `{name} unblocked` | Partner profile → Unblock |

### Recoverable action failures using the same container

| Copy | Location |
| --- | --- |
| `Could not save the interface language. Try again.` | Profile → Interface language |
| `Could not update your profile. Try again.` | Profile → Edit profile / Known languages |
| `Couldn't save privacy setting.` | Profile → Privacy |
| `Couldn't save notification setting.` | Profile → Notifications |
| `Could not update your password. Try again.` | Profile → Change password / reset password |
| `Couldn't send the report. Try again.` | Report message / report person |
| `Couldn't block. Try again.` | Partner profile → Block |
| `Couldn't unblock. Try again.` | Partner profile → Unblock |
| `Couldn't edit message. Try again.` | Chat → Edit message |
| `Could not open photos. Try again.` | Chat → open photo picker |
| `Could not share photo. Try again.` | Share-image flow |
| `Couldn't save. Try again.` | Translation preferences; grammatical-form chooser |

**Observed issue:** after Bob switched the interface to German, the Profile screen changed to German but the snackbar still said `Switched to German` with `Undo` in English. The close action did localize. This is an English leak caused by building the message from the old screen locale.

## 2. Small acknowledgement pill

**Current container:** light gray, fully rounded pill centered above the chat composer for 800 ms.

| Copy | Location |
| --- | --- |
| `Copied` | Chat → long-press message → Copy. On Android 13+ the OS clipboard confirmation is used instead. |

This is already a calmer visual direction than the global dark snackbar, but it currently exists only for message Copy.

## 3. Connectivity and blocked availability

**Current container:** full-width 40 px dark gray banner directly below the page header.

| Copy | Location / behavior |
| --- | --- |
| `No connection` | Chats, Chat, Invite a friend, invite resolver, and share-image screen |

The banner is identical everywhere, but the effect differs:

- Chats and Chat remain usable from cached content; messages queue for reconnect.
- Invite a friend keeps its normal page layout but disables `Send invite`.
- A pending invite claim waits and resumes when connectivity returns.

## 4. Content and page recovery

These are not global containers. They sit inside the content that failed.

| Copy | Location / container |
| --- | --- |
| `Couldn't load chats` + `Retry` | Chats empty/error state; centered text with a refresh text button |
| `Couldn't load your profile.` + `Retry` | Edit profile load failure; centered content recovery |
| `Couldn’t prepare a new invite.` + `Try again` | Invite a friend; one inline row above the primary action |
| `Couldn’t open sharing. Try again.` | Invite a friend; inline text above the primary action |
| `Couldn’t open the invite.` / `Try again to continue.` + `Try again` | Invite resolver; centered full-page recovery |
| `This invite has already been claimed` / `Ask your friend for a new link.` | Invite resolver; centered terminal state |
| `We couldn’t find that invite.` / `Check the link is correct, or ask for a new one.` | Invite resolver; centered terminal state |

## 5. Message-owned recovery

**Current container:** `#C62828` text-only status beneath the affected bubble; no standalone error icon.

| Copy | Location / behavior |
| --- | --- |
| `Not sent · Tap to try again` | Failed outgoing message; tapping the status retries immediately |
| `Message failed to send` + `Retry` / `Delete` | Tapping the failed bubble opens a bottom action sheet |
| `Couldn’t translate · Retry` | Language-help failure beneath a message |
| `Couldn’t check · Retry` | Language-check failure beneath an outgoing message already authored in the target language |

## 6. Field-owned validation

Authentication, password, profile, email-change, and account-deletion errors render inline by the relevant field or form. Examples include `Email or password is incorrect`, `Passwords don't match`, and `That doesn't match your email`.

These belong in a separate category from action feedback because the user must correct a specific input; moving them into a global confirmation container would remove the field context.

## Screenshot packet

1. `feedback-success-profile-updated-restored.png` — floating completed-action snackbar.
2. `feedback-interface-language-undo.png` — snackbar with Undo plus the English leak.
3. `feedback-copied-pill.png` — lightweight Copy acknowledgement.
4. `feedback-offline-chats-banner.png` — connectivity banner on a usable cached screen.
5. `feedback-offline-new-chat-blocked.png` — same banner with a disabled network-dependent action.
6. `feedback-message-not-sent.png` — message delivery recovery.
7. `feedback-translation-failed-inline.png` — language-help recovery.
8. `feedback-recovery-state-reference.png` — current debug workbench inventory strip for empty/loading/error content states; it is a review reference, not a production failure reached during this run.
