# Invite flow redesign — launch spec

**Status:** Drafted from approved product decisions — ready for review  
**Scope:** Invite creation, sharing, app/web handoff, invite claiming, first chat entry, and first-time mode guidance.  
**Principle:** Ship the familiar messaging flow with the fewest new screens. The invite creates a chat; choosing a practice language happens only after that chat exists.

## Problem

The current flow asks for a language before a user can invite anyone, adds extra invite-specific screens, and makes an invite expire after 48 hours. That is too much work before a friend can simply start chatting, and it makes a delayed or poor-connection share unexpectedly fail.

Blab should feel like a simple messenger: create a link, send it, and start the chat once the friend joins. Language learning begins inside the chat, where it has context.

## Goals

- An existing user can send an invite in one familiar screen and one system share sheet.
- A recipient can finish normal email sign-up or login and land directly in the chat.
- An unclaimed invite remains usable until one friend claims it; no time-based expiry blocks a delayed share.
- Both people see the same clear new-chat state and choose their own practice language independently.
- The redesign adds no contact-permission flow, no contact discovery, no invitee-only sign-up page, and no success page.

## Non-goals for launch

- Contact permissions, contact import, and “friends already on Blab” discovery. Launch sign-in remains email-only.
- Phone-number sign-up or recipient-email matching.
- A dynamic per-invite web page. The web page is one static template; the token only identifies the invite when Blab receives it.
- Invite cancellation, invite history, or an invite-management screen. An unused link remains active until claimed.
- An inviter-facing in-app “friend joined” banner or a launch push notification. The unread chat row is the notification in the app.
- A language choice before creating or sharing an invite.

## Decisions at a glance

| Decision | Launch behaviour |
| --- | --- |
| Link lifespan | Valid until one successful claim; no 48-hour expiry. |
| Link ownership | One friend can claim a link. The first successful claimant gets it. |
| Multiple links | Every completed Copy or selected share target prepares a fresh, separate link. Earlier unclaimed links remain valid. |
| Offline sharing | The invite page opens, but **Send invite** is disabled while offline. |
| Web landing | One static page with store-download buttons only; no **Open in Blab** button. |
| Claim timing | A link is claimed only after Blab knows the recipient’s signed-in account. |
| First language choice | Required inside the new chat, after the claim; each participant chooses independently. |
| Existing pair | Reuse the existing chat; never reset a language or create a duplicate. |

## 1. Inviter flow

### Entry points

- Chats **+** opens **Invite a friend**.
- The empty-state **Invite someone** action opens the same page.
- There is no contacts screen and no language picker before this page.

### Invite a friend

```
←  Invite a friend

┌──────────────────────────────┐
│ Let’s chat on Blab            │
│ loveblab.com/i/7K4M2P         │
└──────────────────────────────┘
  Only one friend can use this link

[          Send invite          ]
```

- Canvas: `#FAF7F2`.
- The card uses the approved warm surface, outline, and rounded-card treatment already used in Blab.
- Card title: **Let’s chat on Blab**. The URL is readable but not separately tappable.
- Helper below the card, without a bullet: **Only one friend can use this link** (owner refinement, 2026-09-08).
- Primary button label: **Send invite**. It has no icon, uses `#F88C5A`, and uses `#46281C` text.
- Tapping the button opens the device share sheet. Its normal dimmed background belongs to the operating system.
- The shared text is exactly:

  ```
  Let’s chat on Blab
  loveblab.com/i/{token}
  ```

- Copy uses the system’s normal confirmation. Returning from Copy or another app returns to this same page, never to Chats.
- There is no separate “invite sent” page. The user can invite another person from the same page.

### Link preparation

- Once a signed-in user is online, Blab keeps one unused invite ready in the background. The first visit to **Invite a friend** should therefore normally be instant.
- After the user copies the link or chooses a share target, Blab treats that link as exposed and prepares a fresh link for the next friend.
- Each exposed link remains valid until claimed. The same friend receiving two links still resolves to one existing chat.
- If preparing the next link fails while the user is online, keep the page in place, disable **Send invite**, and show the persistent inline banner below the card:

  **Couldn’t prepare a new invite. · Try again**

  **Try again** retries only the link preparation. The banner disappears and the button activates when a new link is ready.

### Offline state

- Use the same top-of-screen offline banner as Chats: **No connection**.
- Keep the normal Invite a friend layout and visible card.
- Disable **Send invite**. Do not add a special offline card, explanatory paragraph, dialog, or second banner.
- Re-enable the button automatically on reconnection.

## 2. Static web landing

The URL is dynamic; the web page is not. A single static template serves every `loveblab.com/i/{token}` link, so it does not create a copy of the website for each invite.

```
[Blab black logo]

You’re invited to Blab
Chat naturally while Blab helps you practice a language.

[ Download on the App Store ]
[ Download on Google Play   ]
```

- The black `blab-logo_black` is clickable and leads to `https://www.loveblab.com/`.
- Primary text: `#46281C`; secondary text: `#917869`.
- Store buttons have equal visual weight and use the exact labels above.
- Do not show an inviter name, a language, an **Open in Blab** action, or “your invite will be waiting.”
- The static page never validates or claims the invite. It merely leads to the stores.
- When an installed app receives a verified app link, it normally opens Blab directly. A messaging app may still force a browser; opening that browser page never claims the link.

## 3. Recipient flow

### Valid link, recipient already logged in

1. Maya taps the invite.
2. Blab validates it against Maya’s current account.
3. Blab claims the link, creates or reuses the one-to-one chat, and opens it directly.
4. The required language sheet is visible over that chat.

There is no acceptance confirmation screen.

### Valid link, recipient signed out or does not yet have Blab

1. Blab preserves the most recently opened valid link.
2. The recipient sees the normal email sign-up or login page—no invite-specific account page and no account-confirmation prompt.
3. After successful authentication, Blab claims the saved link and opens the chat directly.
4. If the recipient closes Blab before authentication, the saved link remains and resumes after they return.

If Maya opens Anna’s link and then Bob’s before signing up, Blab preserves Bob’s most recently opened link. Only Bob’s link is claimed after signup; Anna’s link stays valid and may be opened later.

### Recipient already uses Blab

- A logged-in recipient claims the invite immediately when Blab validates the opened link.
- If the pair already has a chat, open that chat. The new link is marked claimed, but no duplicate chat, unread “new connection” row, language reset, or language sheet is created.
- There is no “You’re signed in as…” prompt or “use another account” path in launch scope.

## 4. Claim rules and edge cases

| Situation | Result |
| --- | --- |
| Recipient only views a browser page or store page | Nothing is claimed. |
| Recipient leaves before sign-up/login | The saved link remains unclaimed. |
| Two people open the same link | The first successful signed-in claim wins. |
| Second person finishes signup after the winner | Their account is created normally; they see the claimed state and no chat is created. |
| Same recipient reopens their used link | Open their existing chat. |
| Another account opens a claimed link | Show the claimed state. |
| Inviter opens their own unused link | Do not claim it; open **Invite a friend** with that link. |
| Inviter opens their own claimed link | Open the resulting chat. |
| Link is malformed or unknown | Show the invalid-link state. |
| Connection drops before a claim completes | Preserve the link, show **No connection**, and finish automatically on reconnection. If the user leaves, the finished chat appears unread in Chats. |

### Claimed and invalid states

These are in-app states. The static web page remains generic.

**Claimed by someone else**

```
This invite has already been claimed
Ask your friend for a new link.

[ Go to chats ]
```

**Invalid or unknown link**

```
We couldn’t find that invite.
Check the link is correct, or ask for a new one.

[ Go to chats ]
```

- There is no expired-link state.
- **Go to chats** always opens Chats inside Blab.
- System Back follows where the user came from: back to the external app for an external link, or Chats for an in-app link.

## 5. New connection in Chats

After a new pair is created, both people see the same chat treatment.

- The row moves into the same priority position as an unread incoming message.
- Its preview is **Ready to chat · Say hi**.
- The row is unread until that participant chooses a practice language. This is not a notification pill or a separate in-app banner.
- If a real message arrives first, the message replaces the preview. Before a practice language is chosen it appears exactly as authored, with no correction or translation.
- Once that participant selects a practice language, a real-message preview switches to their Practice result. The row’s new-connection unread state clears.
- Existing chats between the same pair do not receive this treatment.

## 6. New-chat language choice

The inviter and invitee use the same chat entry experience.

### Background state

- With no messages, show a simple centered text container after the required language choice. Keep it hidden during initial language selection so no part can peek above the sheet:

  **No messages here yet…**  
  Send any message to start.

- Do not add an illustration for launch.
- If a message already exists, show it behind the sheet in its authored form until a practice language is selected.

### Required bottom sheet

```
Choose a language to practice
You can change it anytime.

[language list]
```

- It uses the existing language list and selection behaviour.
- It appears over the real chat background with **no blur and a subtle `#46281C` 8% veil** (owner refinement, 2026-09-08).
- It cannot be dismissed by tapping outside or swiping down. The composer, messages, and mode switch are inactive until a language is selected.
- Back leaves the chat for Chats; reopening the new chat shows the sheet again.
- Profile and Settings remain reachable outside this chat.
- The choice affects only that participant’s view. It does not choose a language for the other person.
- No Practice or Normal mode is available in this chat until the choice is complete.

#### Required-sheet visual refinement — 2026-09-08

- Full-width, bottom-anchored 520 px content height plus bottom safe area; clamp to the available viewport on smaller screens. Increased from 442 px in the owner’s spacing refinement to cover more of the chat. The supplied absolute y=304 does not govern bottom anchoring on an 844 px screen.
- Surface `#FFFCF8`, 24 px top corners, clipped content, 1 px `#E1DAD2` outline. Shadow: `#917869` at 12%, x0/y−4/blur24/spread−2. No drag handle.
- Header: 20 px padding, 6 px gap, 22 px bold `#46281C` title and 14 px regular `#917869` subtitle. Use platform fonts per tech-spec Decision #6.
- List padding: top0/left16/right24/bottom16. Rows have 16 px horizontal and 18 px vertical padding, 56 px minimum tap height, regular 15 px `#46281C` text, unchanged surface, and 1 px full-row `#E1DAD2` dividers. Text scaling may increase row height.
- A fresh required choice starts unselected. A tapped language is bold with the owner’s existing `check - 20.svg` artwork, tinted `#D4694A`, and a separate saving indicator; no selected-row background tint. Reuse the supplied artwork instead of a newly drawn stroke. Successful persistence closes the sheet; failure retains the existing retry path.
- Persistent scrollbar: 3 px width, 2 px radius, 9 px right inset, `#C2B8AB` 30% track, `#8C7A6B` 70% thumb. The thumb reflects actual content/viewport proportions rather than hardcoded dimensions.
- Scope is the initial mandatory sheet only, not the later Change language sheet. Preserve Back to Chats and outside-tap/drag blocking.

## 7. First-time mode tips

### Timing

- After a participant selects their first practice language, close the language sheet and show the Practice tip next to the mode switch.
- The first time that participant changes to Normal, show the Normal tip.
- Each tip appears once per account, not once per chat.
- Tips are non-modal: no dimmed background, no blur, and a tap anywhere else closes them.

### Container

- Fill: `#F88C5A`; text: `#46281C`.
- Anchor: mode switch, with a small pointer toward it.
- Maximum width: 280 px; 12 px internal padding; 12 px radius.
- Title: 13 px semibold; body: 12 px regular / 16 px line height; 2 px title-to-body gap.
- Action: 12 px semibold text link with 8 px top spacing.
- Shadow: warm ink at low opacity, y 2 / blur 8. No outline is needed.

### Copy

**Practice mode**

> Messages appear in {practice language}. Blab helps correct mistakes and translates from {primary known language}. Switch to Normal to see the original.

**Normal mode**

> Messages in languages you know stay as written. Others are translated for you. Long-press to see the original.

Text action: **Edit known languages**

## 8. Invite-opening loading state

Show this state only if link validation takes longer than one second. Reuse it after successful sign-up or login while Blab claims the saved invite.

```
Opening invite

●  ●  ●
```

- Canvas: `#FAF7F2`.
- Center the two rows vertically.
- **Opening invite**: `#46281C`, 17 px, semibold.
- Dots sit on their own row, 16 px below the text. Each dot is 16 px with 10 px gaps.
- Dots use `#F88C5A`; their opacity cycles left to right through `100% / 60% / 30%`, then `30% / 100% / 60%`, then `60% / 30% / 100%`.
- Motion is opacity only, smooth, and loops every 900 ms. Reduced-motion users see the static `100% / 60% / 30%` state.
- The state disappears as soon as Blab routes to the normal auth page, the chat, or a terminal error state.

## P0 acceptance checklist

- [ ] Chats **+** and the empty-state action open Invite a friend directly, with no contact access and no language picker.
- [ ] A ready one-friend link can be sent through the native share sheet; Copy and app switching return to Invite a friend.
- [ ] Every exposed link remains valid until one successful claim; no UI or server outcome expires it by time.
- [ ] Invite a friend disables Send invite and shows only the standard No connection banner while offline.
- [ ] A no-app recipient sees the static logo, copy, and equal store buttons; the page does not validate or claim the invite.
- [ ] A signed-out recipient completes normal email sign-up or login and lands in the chat without reopening the link.
- [ ] A signed-in recipient lands directly in the chat; an existing pair reuses its chat without a language reset.
- [ ] Claim timing, self-link, repeat-link, concurrent-claim, invalid-link, and claimed-link behaviours match section 4.
- [ ] A new pair sees Ready to chat · Say hi as an unread row until each person selects a practice language.
- [ ] Both sides see the same mandatory language sheet with the owner-approved subtle warm veil over the empty state or authored first message.
- [ ] Practice and Normal tips appear once with the approved copy, style, and non-blocking dismissal.
- [ ] Invite loading uses the approved two-row three-dot state.

## Success measures

Because launch does not use behavioural analytics, validate these through the release test matrix and support feedback:

- A new invite can be created and opened by a friend in under one minute on a healthy connection.
- The two-device acceptance matrix passes for email sign-up, email login, installed-app recipient, no-app recipient, same-pair re-invite, used link, invalid link, self-link, and a concurrent claim.
- Each available Android share target returns to the Invite a friend page and preserves the expected link state.
- No link becomes invalid because of elapsed time.
- No acceptance creates a duplicate chat or resets either person’s practice language.

## Dependencies and launch notes

- Launch is Android-first. The web page may show both store buttons, but iOS App Store handoff and deferred invite preservation are a later platform-delivery dependency.
- Android must preserve a no-app recipient’s token through Play installation so normal sign-up can claim it afterward.
- The production invite domain and final store destinations must be configured before release testing.
- Push notification on friend join is deferred. The unread chat row is the launch in-app signal.
