# Chat UI refresh + simple long press

**Status:** approved, ready for implementation  
**Date:** 2026-08-24  
**Figma reference:** `Blab app` → `Ready for build` → Normal, Practice, and `Chat / Practice mode/ Longpress` frames  
**Related:** US-015…US-021, US-030, US-033, US-041; FR-13…FR-17, FR-25, FR-28, FR-31, FR-32; Step 2.13  
**Builds on:** `2026-08-23-chat-practice-mode-ui-refresh-design.md`  
**Supersedes where different:** `2026-08-07-messenger-style-message-interaction-design.md`, the old tap-padding action trigger, the old copy/delete/edit rules, and the old receipt/error treatments

## Problem

The refreshed chat still mixes the old per-message translation control with a newer long-press interaction. Copy and Reply do not consistently use the text the person is actually reading, Edit is incomplete, failed states compete with reactions and Reply, and the current delivery ticks do not express the agreed launch states.

For launch, Blab needs one simple, familiar message interaction: word tap for learning, message long press for reactions and actions, and no elaborate selected-message animation.

## Goals

- Make word tap, message long press, and swipe-to-reply distinct and predictable.
- Keep the currently visible message text authoritative for Copy and Reply.
- Give Practice and Normal mode different, useful long-press language actions without crowding the menu.
- Make Reply, Edit, delivery failure, translation failure, receipts, and deletion complete enough to ship.
- Preserve the approved Figma surfaces, bubble colors, icons, and compact launch action row.

## Non-goals

- No dimmed-background, lifted-bubble, fixed-position bubble, or elaborate selected-message motion. The floating reaction row still uses the lightweight entrance and exit motion defined below.
- No post-launch vertical action-list design. The launch version keeps the compact horizontal row.
- No audio messages.
- No edit-history screen.
- No separate visual distinction between “server accepted” and “friend’s device received”; both use the single gray check.
- No deleted-message tombstone, Delete for me option, or Undo.
- No Translate or Collapse action; those controls are removed rather than replaced.

## User stories

- As a learner in Practice, I want long press to reveal meaning and offer sentence audio so I can understand a message without permanent extra controls beside every bubble.
- As a person in Normal, I want Original only when the displayed text differs so I can verify what was authored without crowding every message.
- As either participant, I want Copy and Reply to use the message text I am currently reading so the result is predictable.
- As a sender, I want Edit, delivery failure, translation failure, and Delete to have complete outcomes so I never lose the message or see stale language help.
- As a person using enlarged text or a launch interface language with longer labels, I want every message action to remain readable and tappable.

## Tracker captions and approved outcomes

The tracker captions remain unchanged. Later decisions in this spec deliberately supersede two captions without renaming them.

| Existing caption | Approved launch outcome |
|---|---|
| `Replace the old chat icons with the new icons you’ve chosen.` | Use the supplied icon family listed below. |
| `Update the chat background and profile/container colors to match the newer visual direction.` | Use the already-approved Normal/Practice surfaces and bubble treatments. |
| `Remove the separate translation icon beside every message.` | Remove Translate, sentence-play, and Collapse controls beside bubbles. |
| `Keep normal tap on a word for word-level learning.` | Word tap continues to open the word description. |
| `On long press of a message, reveal its English/interface-language translation.` | In Practice, reveal the reader’s **primary known language** below the current learning-language line. The caption is retained, but interface language is not the translation target. |
| `Keep this simple for launch — do not build the fancy long-press animation yet.` | Keep the current floating reactions + composer-replacement action row, with no scrim or bubble movement. |
| `Skip adding whole-sentence audio to the long-press actions for now.` | Superseded by the later approved decision: Practice includes `Listen`; Normal uses `Original` in the same slot. |
| `The check asset exists, but it isn’t placed on any approved screen; receipts currently use double-check.` | Superseded by the later approved receipt model: the single-check asset is now used for accepted/delivered; double-check is reserved for read. |
| `Fix translated outgoing bubble wrapping` | Already visually corrected; keep it as a regression requirement. |
| `Restore View original in message actions` | Restore as `Original` in Normal only, with open/closed-eye states. |
| `Finalize deleted-message and Undo behavior` | Confirm first, then remove for both people with no tombstone and no Undo. |

## 1. Visual foundation

Use the approved values from the Normal/Practice refresh:

| Element | Treatment |
|---|---|
| Chat canvas | `#FAF7F2` |
| Header and composer | `#FFFCF8` |
| Header/composer divider | `#E1DAD2`, 1 px |
| Input | `#FFFCF8`, 1 px `#E1DAD2`, 24 px radius |
| Incoming bubble, both modes | `#FFFCF8`, 1 px `#EBE1DA`, no shadow |
| Normal outgoing bubble | `#D7C8BE`, 1 px `#C8B9AF`, no shadow |
| Practice outgoing bubble | `#F88C5A`, 1 px `#F07D4B`, subtle approved Practice shadow |
| Floating chat settings menu | `#FFFCF8`, 1 px `#E1DAD2`, 14 px radius, `#231208` at 10% / y 2 / blur 12 shadow |

Translated outgoing bubbles keep the approved right alignment, 12 px screen-edge breathing room, content-hugging width for short messages, and existing maximum width for wrapping.

The floating chat settings menu keeps two 52 px rows separated by a 1 px `#E1DAD2` divider. Labels are regular 15 px `#46281C`; the learning-language value is regular 14 px `#917869`; both rows use the supplied 20 px right arrow in `#917869`. It remains auto-width with no wrapping, has no scrim, and closes on outside tap.

### Reply quote colors inside sent bubbles

- Reply quote inside an outgoing bubble: fill `#FAB894`.
- Reply quote inside an incoming bubble: fill `#F5F0E8`.
- Keep the existing quote radius and side-line geometry.
- A photo reply uses the same quote container and spacing as a text reply.

## 2. Gesture model

### Word tap

- A normal tap directly on a learning-language word opens the word-description popup.
- Long-pressing the same word opens message selection only; the word popup must not flash first.
- If a word popup is already open, long press closes it before opening message selection.
- Tapping empty padding inside a bubble does nothing.

### Message long press

- Long press anywhere inside the bubble opens the current launch selection state:
  - floating quick-reaction row below the selected bubble by default;
  - if there is not enough visible room below, the row moves above the bubble;
  - only a viewport-filling message may place the row over the bubble near the long-press point;
  - message-action row replacing the composer;
  - no scrim, background dimming, bubble lift, or bubble repositioning.
- The reaction row follows Telegram's compact choreography, softened for Blab:
  - its container scales from 88% to 100% over 250 ms with a soft overshoot, anchored toward the message side (left for incoming, right for outgoing);
  - the six quick reactions and trailing more button settle in at 30 ms intervals, each using a 150 ms ease-out scale;
  - dismissal keeps the container at full size and fades it out over 150 ms;
  - when reduced motion is enabled, the row appears and disappears without scale, overshoot, or stagger.
- In Practice, the selected bubble also reveals the primary-known-language translation using the existing divider and second-line treatment.
- Tapping the chat canvas or beginning a message-list scroll closes reactions, actions, and any temporary Translation/Original line.
- The first tap on Back, avatar/profile, settings, overflow, or the mode switch dismisses message selection only. A second tap performs that control’s normal action.
- System Back dismisses message selection before leaving the chat.

### Swipe to Reply

- Swipe-to-reply remains available across the message’s full horizontal row, including empty canvas beside the bubble.
- Reply triggers after at least 64 px accepted horizontal movement and horizontal movement at least 1.5× vertical movement.
- A successful swipe closes reactions, the action row, and temporary Translation/Original content before opening Reply.
- A cancelled swipe keeps the current long-press state unchanged.
- A translation- or delivery-error row under the source message remains visible when Reply starts.

## 3. Practice translation and Listen

### Temporary translation

- Practice’s primary bubble line remains the learning-language text.
- Long press reveals the reader’s primary-known-language translation below the existing divider, matching the current expanded translation treatment.
- It is temporary: tap outside, scroll, switch mode, Reply, or another selection closes it.
- If translation failed, keep the authored text and its error row; do not show a stale translation.

### Listen

- Practice shows `Listen` in the language-action slot; Practice never shows `Original`.
- Listen speaks the learning-language sentence shown in the bubble.
- Emoji are skipped and their names are never spoken. Punctuation may control natural pauses.
- Mixed text + emoji reads only the text. Emoji-only messages hide Listen.
- Use on-device sentence speech; unavailable speech renders the action disabled without replacing it with another action.

## 4. Normal Original

- Normal shows `Original` only when the primary message text differs from the exact authored text.
- Original uses the open-eye asset while the authored text is hidden.
- Tapping it adds the exact authored text as a temporary second line below the existing divider; it does not replace the primary line.
- While visible, keep the label `Original`, switch to the closed-eye asset, and apply a subtle selected treatment.
- Tapping it again or dismissing selection hides the authored line.
- Original never appears in Practice.

## 5. Action eligibility and order

### Text messages and photo captions

| Message | Normal | Practice |
|---|---|---|
| Own outgoing | Reply · Edit · Copy · Original · Delete | Reply · Edit · Copy · Listen · Delete |
| Incoming | Reply · Copy · Original · Report | Reply · Copy · Listen · Report |

- Edit appears only during the existing 24-hour edit window.
- Original appears only when Normal’s primary line differs from the authored text.
- Listen appears only when the visible learning-language content includes speakable text.
- Delete remains outgoing-only. Report remains incoming-only.
- When a conditional action is absent, remaining actions keep their order and expand evenly.

### Photo-only messages

- Own outgoing photo-only: Reply · Delete.
- Incoming photo-only: Reply · Report.
- Do not show Copy, Original, Listen, or Edit for a photo without a caption.
- For a photo with a caption, text actions operate on the visible caption. An existing own caption can be edited; an already-sent photo without a caption cannot gain one through Edit.

## 6. Temporary launch action-row layout

- Keep one horizontal row for launch.
- Use five equal-width columns when five actions are present.
- Action icons render at 16 px; labels render at 11 px with a 4 px icon-to-label gap.
- At default text scale, the one-line action row matches the collapsed composer height so the message viewport does not shift.
- Every action retains at least a 44 × 44 px tap target.
- At default system text size, approved English, German, Spanish, and Ukrainian labels stay on one line without shrinking, truncation, or abbreviations.
- With enlarged system text, labels may wrap to two lines and the action bar grows vertically. Critical labels must remain visible through 200% text scaling.
- Delete keeps the destructive treatment; other labels/icons use the approved chat ink.
- A vertical action list is a post-launch design task.

## 7. Icon mapping

Use the supplied SVG assets; do not substitute platform icons.

| Action/location | Asset | Visual size |
|---|---|---:|
| Back | `nav-arrow-left - 20.svg` | 20 px |
| Overflow | `more-vert - 20.svg` | 20 px |
| Add media | `media-image - 20.svg` | 20 px |
| Send | `arrow-up - 20.svg` | 20 px |
| Reply and swipe-to-reply | `long-arrow-up-left - 16.svg` | 16 px in action row |
| Edit | `edit-pencil - 16.svg` | 16 px |
| Copy | `copy - 16.svg` | 16 px |
| Original hidden | `eye - 16.svg` | 16 px |
| Original visible | `eye-closed - 16.svg` | 16 px |
| Listen | `sound-high - 16.svg` | 16 px |
| Delete | `trash - 16.svg` | 16 px |
| Report | `white-flag - 16.svg` | 16 px |
| More reactions | `plus-circle - 20.svg` | 20 px |
| Sending | existing clock | 16 px |
| Accepted/delivered | `check - 16.svg` | 16 px |
| Read | `double-check - 16.svg` | 16 px |
| Word pronunciation | `sound-base.svg` + `sound-wave-1.svg` + `sound-wave-2.svg` | existing popup bounds |

- Remove message-adjacent Translate, sentence-play, and Collapse icons.
- Delivery failure and translation failure use text only; do not show `!`, warning, error, or Retry icons.
- Existing × actions remain for closing Reply/Edit states and other existing dismissible UI.

## 8. Copy

- Copy always copies the complete **primary text currently presented as the message**:
  - Practice: the learning-language text shown in the bubble;
  - Normal known-language message: the exact authored text;
  - Normal unknown-language message: the primary-known-language translation;
  - translation failure: the authored text, because that is the readable primary line.
- Temporary secondary Translation/Original lines are not concatenated into the clipboard text.
- Photo captions follow the same rule; photo-only messages do not show Copy.

### Copy feedback

- Remove Blab’s long clipboard confirmation container.
- Android 13+: rely on the system clipboard confirmation only; do not add a duplicate Blab confirmation.
- Older Android and iOS: show a centered `Copied` pill above the text field for 800 ms, with `#ECE7E1` fill and `#231208` text.
- The pill must not cover or block the text field; typing remains available.

## 9. Reply

- Reply uses the same primary visible text rule as Copy.
- If translation failed, Reply quotes the authored text and the source message keeps `Couldn’t translate · Retry` below it.
- Reply opens the keyboard automatically.

### Composer preview

- The preview label is only `You` or the partner’s exact display name; never `Replying to…`.
- `You` and its line always use the brand color.
- A partner with an initial avatar uses that avatar’s assigned accent for the line and name.
- A partner with a photo avatar uses the stable fallback `#46281C`.
- Remove the divider between the Reply preview and text field.
- Place × in the same right-side column as Send so the preview text and ellipsis align with the text-field container’s right edge.
- Photo preview uses a thumbnail plus caption, or thumbnail plus localized `Photo` when there is no caption.

## 10. Edit

- Edit remains available only for the sender’s own message within 24 hours.
- Tapping Edit closes message selection, keeps the original bubble visible, loads the exact authored text into the composer, places the cursor at the end, and opens the keyboard.
- Do not show an empty quote container, side line, divider, or edit icon.
- Composer state:

  `Edit message                                            ×`  
  `[ editable message text…                         ]  Send`

- `Edit message` uses the brand color; × is muted. Both align to the text-field edges.
- Hide the media action while editing. Keep the same Send arrow; tapping it saves the edit to the existing message.
- Only Send or × ends Edit.
- Opening profile, settings, full-screen settings, or switching Normal/Practice preserves the edit draft. Returning restores the exact draft, cursor, edit state, and keyboard focus.
- The saved message keeps `edited` permanently. Show `edited · time · receipt` in the metadata row, using the same 10 px muted color as the timestamp. Keep it visible on grouped messages.

### Translation after Edit

- Emoji-only additions/removals and whitespace-only changes reuse the existing translation and update immediately.
- Any changed letter, number, or punctuation invalidates the old result and translates/corrects the full edited message again.
- Never present the old translation as if it belongs to the edited text.
- If retranslation fails, show the edited authored text plus `Couldn’t translate · Retry`; the `edited` label remains.

## 11. Delivery, read receipts, and failures

### Outgoing receipt states

- Clock: still sending or queued.
- Single gray check: server accepted. Keep the same single gray check after the friend’s device receives it.
- Double gray check: read.
- If either person has Read receipts OFF, the sender’s message stays at a single gray check.
- When a person’s Read receipts toggle is OFF, their phone sends no read event; the server must not keep a hidden read record.
- Incoming messages never show receipt icons.

### Delivery failure

- Copy: `Not sent · Tap to try again`.
- Color: `#C62828`.
- Place the row directly on the chat canvas below the bubble, left-aligned to that bubble’s content block.
- Use a 160 px minimum status width for short messages; for wider messages, follow the bubble width.
- Tapping the row retries. No error or Retry icon appears.

### Translation failure

- Copy: `Couldn’t translate · Retry`.
- Use the same `#C62828` and status-row geometry as delivery failure.
- Keep delivery and translation failure as separate states; one must not mask the other.

### Reactions and errors

- If a message has both a reaction and an error: bubble → overlapping reaction badge → error row.
- Use 8 px between the reaction badge and error row; use 6 px between bubble and error row when no reaction exists.
- Starting Reply never hides or replaces either error row.

## 12. Delete

- Delete is available only for the sender’s own outgoing message and has no time limit.
- Confirmation:
  - title: `Delete message?`
  - body: `Are you sure you want to delete this message? It will also be deleted for {name}.`
  - actions: `Cancel` · `Delete`
- Cancel returns to the chat without changing the message.
- Confirmed Delete removes the message completely for both people.
- Show no tombstone, Delete-for-me choice, or Undo.

## Priority

- **P0 / launch:** sections 1–12 and every acceptance criterion below.
- **P1:** none; do not delay launch by adding adjacent polish.
- **P2 / after launch:** the items in Deferred after launch.

## 13. Acceptance criteria

### Gestures and selection

- [ ] Word tap opens only the word description; word long press opens only message selection.
- [ ] Empty bubble padding does nothing on tap.
- [ ] Long press shows reactions and actions without a scrim or bubble movement; reactions sit below by default, above when needed, and overlap only a viewport-filling message.
- [ ] Practice long press reveals the primary-known-language second line; Normal offers conditional Original instead.
- [ ] Tap outside and scroll dismiss temporary selection UI.
- [ ] A successful swipe-to-reply closes selection UI; a cancelled swipe preserves it.

### Actions and localization

- [ ] Every Normal/Practice, outgoing/incoming, text/caption/photo-only action matrix matches this spec.
- [ ] Copy and Reply use the primary text the person is reading and never concatenate the temporary second line.
- [ ] Five actions fit at default text size in English, German, Spanish, and Ukrainian with 16 px icons and 11 px labels.
- [ ] At 200% text, labels wrap without clipping and all tap targets remain at least 44 × 44 px.
- [ ] Practice Listen skips emoji names and is absent for emoji-only/photo-only messages.
- [ ] Normal Original uses open/closed eye states and is absent when authored and displayed text match.

### Reply, Edit, Delete

- [ ] Reply preview uses only `You` or the display name, approved accent rules, no divider, and automatic keyboard focus.
- [ ] Text and photo replies use the same visual system; quote fills match `#FAB894` / `#F5F0E8`.
- [ ] Edit preserves the original bubble, opens the keyboard, uses the approved composer state, and survives navigation until Send or ×.
- [ ] Emoji/whitespace-only edits reuse translation; letters/numbers/punctuation trigger fresh language help without stale output.
- [ ] `edited` remains in the timestamp color and order `edited · time · receipt`.
- [ ] Delete confirms with approved copy, removes for both, and shows neither tombstone nor Undo.

### Receipts and failures

- [ ] Sending → clock; accepted/device-received → single gray check; read → double gray check.
- [ ] Read receipts OFF leaves a single check and emits no read event from the reader’s phone.
- [ ] Delivery and translation failures use approved red text, no icon, and remain visible beneath reactions and during Reply.
- [ ] Short-message error rows keep a 160 px minimum width; wider rows follow the bubble.

## Success measures

- A person can long press a message and find the intended action in under two seconds.
- No action copies or quotes a hidden/stale language variant.
- No five-action label clips at default size in the four launch interface languages.
- Editing, deleting, replying, retrying, and read receipts pass on two real accounts without temporary UI hiding persistent message state.

## Dependencies

- Approved Figma Normal, Practice, and long-press frames.
- Supplied 16 px and 20 px chat icon assets.
- Existing reactions, on-device TTS, message translation cache, edit window, and privacy toggles.

## Open questions

- None blocking. The product behavior is approved; implementation planning owns any internal migration or state-model detail without changing this contract.

## Timeline

- Ship sections 1–13 in the Android launch version and complete the real-device matrix before marking Step 2.13 done.
- Design the vertical action list only after launch; it must not expand this milestone.

## Deferred after launch

- Vertical message-action list and its final visual design.
- Fancy selected-message position, scrim, and transition animation.
- Edit history.
- Audio messages.
- A separate visual state for device-received delivery.
