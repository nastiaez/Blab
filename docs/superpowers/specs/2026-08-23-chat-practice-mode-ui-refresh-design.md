# Chat visual refresh: Normal and Practice modes

**Status:** approved, ready for implementation  
**Figma reference:** `Blab app` → `Ready for build` → `Chat / Normal mode / Default` and `Chat / Practice mode/ Default`  
**Related:** US-013, US-015, US-016, US-018, FR-11, FR-13, FR-14, FR-24, Step 2.10  
**Supersedes:** the earlier chat-only bubble and surface colors where they conflict with this document. It does not change the language, correction, or message-lifecycle rules.

## Problem

The current chat works, but its mode control, colors, and icons do not match the approved Figma direction. Normal and Practice are also too easy to read as two equal buttons instead of one current mode and one available mode.

The refresh must make the active mode obvious, give Practice a distinct but restrained visual character, and update the visible chat artwork without changing established chat behavior.

## Goals

- Make the active mode identifiable from both icon and label in one glance.
- Keep the switch visible in the header without competing with the partner identity or menu.
- Give Normal and Practice distinct outgoing-bubble treatments while keeping the chat recognizably the same conversation.
- Match the approved Figma surfaces, spacing, and icon set closely enough for a side-by-side device review.
- Preserve existing word taps, mode behavior, message actions, audio behavior, and accessibility.

## Non-goals

- No new long-press screen, scrim animation, lifted-message animation, or action-menu redesign. Reaction behavior is unchanged; owner feedback moves the compact reaction badge to the bubble edge nearest the conversation center.
- No whole-sentence audio action in long press.
- No decision about using the single `check` icon for delivery/read states. The approved screens still show `double-check`; `check` stays unused until its state and placement are approved.
- No change to Normal/Practice translation, correction, Known Languages, caching, or failure rules.
- No change to message sending, editing, copying, deleting, or reaction behavior. Reply keeps its existing result and visual feedback, but its swipe target expands to the full horizontal message row.
- No redesign of the word-description popup. Only its speaker artwork changes.

## User stories

- As a person chatting normally, I want the header to clearly say Normal so that I understand messages are being shown without Practice treatment.
- As a learner, I want Practice to feel visibly active so that I know the chat is helping me practise the selected language.
- As either participant, I want mode switching to stay compact and predictable so that it does not crowd the partner name or chat menu.
- As a person using message actions, I want Reply, Edit, and Delete to use the same icon family as the refreshed chat so that the existing long-press interaction feels visually consistent.
- As a learner using word lookup, I want the speaker icon to match the new icon family without changing how pronunciation works.

## Approved design

### 1. Header hierarchy and switch position

- Keep the header at 56 px high below the system status area.
- Keep the partner identity on the left: back action, 36 px avatar, and name. Back icon → avatar and avatar → name are both 10 px.
- Use the refreshed deterministic avatar palette: `#46281C`, `#917869`, `#BC6C4E`, `#788C73`, `#AF787D`, `#5F3C4B`; remove the former avatar colors. The header avatar shadow is `#231208` at 13%, x 0, y 2, blur 4.
- Set the partner name to 15 px heavy, 18 px line height, `#46281C`. Keep it vertically centered whenever the partner is not typing; the existing `typing…` state temporarily becomes its second line. Do not show online or last-seen status.
- Place the mode switch on the right side of the partner identity, immediately before the overflow menu.
- Keep a fixed 10 px gap between the partner-name area and the switch so they read as separate groups without truncating ordinary two-word names on 360 px-wide devices.
- Keep a 12 px visual gap between the switch and the 20 px overflow icon.
- Keep the overflow icon 16 px from the right screen edge.
- The switch is right-anchored. Its left edge may move by the small width difference between states; the overflow menu must not move.
- If the partner name is too long for the header, truncate it with an ellipsis before it reaches the switch. This truncation applies only to the chat header; the chats overview retains the full conversation name.
- Do not let the name, subtitle, or system text scaling push the switch or overflow action off-screen.

### 2. Mode-switch anatomy

| Property | Normal active | Practice active |
|---|---:|---:|
| Whole switch | 129 × 34 px | 135 × 34 px |
| Outer treatment | Transparent fill, 1 px `#E1DAD2` outline, capsule radius | Same |
| Active pill | 83 × 28 px | 89 × 28 px |
| Inactive segment | 36 × 28 px | 36 × 28 px |
| Inner inset | 3 px | 3 px |
| Active fill | `#CDC0B6` | `#F88C5A` |
| Active-pill outline | None | None |
| Active icon + label | `#231208` | `#231208` |
| Inactive icon | `#8C735F` | `#8C735F` |
| Icon size | 16 × 16 px | 16 × 16 px |
| Label | 12 px semibold | 12 px semibold |
| Active-pill shadow | None | `#231208` at 10%, x 0, y 2, blur 6, spread −2 |

The Practice pill shadow deliberately matches the subtle Practice outgoing-bubble shadow. It must not be darker or more distinct.

### 3. Active and inactive states

- When Normal is active, show the Normal chat-bubble icon plus `Normal` inside the filled pill. Practice becomes its flash icon only.
- When Practice is active, show the Practice flash icon plus `Practice` inside the filled pill. Normal becomes its chat-bubble icon only.
- The active pill has no separate border; the only outline belongs to the whole switch.
- The active label and active icon use `#231208` in both modes.
- The whole switch is one toggle target: tapping either icon, the active label, either pill area, the inset, or the outer capsule flips to the other mode. Preserve the existing animated transition and reset behavior for open learning UI.
- Mode switching is tap-only through the header control; swiping open chat background never changes mode.
- Swipe-to-reply covers the full horizontal row aligned with a message, including empty canvas beside its bubble. Open canvas outside a message row does nothing.
- Reply activates only after a deliberate horizontal drag: at least 64 px after horizontal recognition, with horizontal movement at least 1.5× the vertical movement. Short drags and diagonal up/down scrolling reset without opening Reply.
- The visual control is 34 px high but retains an accessibility-sized tap target and exposes the current mode to screen readers.

### 4. Chat surfaces

These colors are identical in both modes unless noted:

| Surface | Treatment |
|---|---|
| Chat canvas | `#FAF7F2` |
| Header | `#FFFCF8` |
| Composer surface | `#FFFCF8` |
| Header/composer divider | `#E1DAD2`, 1 px |
| Input field | `#FFFCF8`, 1 px `#E1DAD2`, 24 px radius |
| Send button | `#46281C`, 44 × 44 px with a solid-white arrow in every state. When empty, only the circle fill dims to 40%; the arrow remains crisp. No shadow in Normal; Practice shadow is `#231208` at 18%, x 0, y 3, blur 8, spread 0 and remains at full strength. |

- The header and composer do not cast a shadow; their separation comes from the divider.
- Date labels such as `Today`, `Yesterday`, and weekday names are plain text directly on the chat canvas, with no pill fill or background.
- Normal composer placeholder: `Message`.
- Practice composer placeholder: `Type in [learning language] or [primary known language]`, localized, set at the same 15 px type size as Normal, and naturally truncated at the end of one line when necessary. Do not add an authored ellipsis.

### 5. Message-bubble colors

| Bubble | Fill | Outline | Shadow |
|---|---|---|---|
| Incoming, both modes | `#FFFCF8` | `#EBE1DA`, 1 px | None |
| Outgoing, Normal | `#D7C8BE` | `#C8B9AF`, 1 px | None |
| Outgoing, Practice | `#F88C5A` | `#F07D4B`, 1 px | `#231208` at 10%, x 0, y 2, blur 6, spread −2 |

- Preserve the current bubble geometry: 18 px main corners and a 4 px directional corner.
- Preserve left/right alignment, edge spacing, grouping, timestamps, and receipt placement. Place reaction badges on the inner edge of each bubble: right for incoming and left for outgoing. Every reaction circle uses `#FFFCF8` fill with a `#DCD2C8` outline; Practice adds the same restrained `#231208` shadow family while Normal remains flat.
- Do not add a shadow to incoming or Normal outgoing bubbles.
- In both modes, bubbles hug short-message content and grow only as the text needs, up to the existing incoming/outgoing maximum width; longer text wraps inside that maximum. Practice must not impose a mode-specific minimum width.
- This section changes visual treatment only. It does not change which message text appears in either mode.

### 6. Approved icon replacements

Use the supplied assets without redrawing or substituting platform icons:

| Chat location | Asset | Visual size |
|---|---|---:|
| Normal mode | `chat-bubble-empty - 16.svg` | 16 px |
| Practice mode | `flash - 16.svg` | 16 px |
| Back | `nav-arrow-left - 20.svg` | 20 px |
| Overflow | `more-vert - 20.svg` | 20 px |
| Add media | `media-image - 20.svg` | 20 px |
| Send | `arrow-up - 20.svg` | 20 px |
| Current delivered/read receipt | `double-check - 16.svg` | 16 px |
| Long press — Reply | `long-arrow-up-left - 20.svg` | 20 px |
| Swipe to reply | `long-arrow-up-left - 20.svg` | 20 px |
| Long press — Edit | `edit-pencil - 20.svg` | 20 px |
| Long press — Copy | `copy - 20.svg` | 20 px |
| Long press — Delete | `trash - 20.svg` | 20 px |
| Long press — Report | `white-flag - 20.svg` | 20 px |
| Future View original | `eye - 20.svg` | 20 px |
| Reaction row — more reactions | `plus-circle - 20.svg` | 20 px |
| Failed message — Retry | `refresh - 16.svg` | 16 px |

- The presence of `check - 16.svg` and `check - 20.svg` does not authorize a receipt-state change. Single-check behavior and placement belong to the next spec.
- Reply, Edit, Copy, Delete, Report, swipe to reply, and the reaction-row add action keep their current labels, eligibility, placement, and behavior. Swipe-to-reply alone expands its tap target to the full horizontal message row; the other actions keep their current tap targets.
- The long-press action bar matches the collapsed composer height, keeping the message viewport fixed when the bar replaces the composer.
- Delete retains its destructive color treatment.
- View original is not currently present in the long-press interaction. Its `eye` artwork is now approved, but its placement and restoration remain a separate decision.
- The message-level Translate, sentence-audio, and collapse controls are deliberately not replaced in this pass because their interaction will be redesigned in the next spec.

### 7. Sending and failure status

- The current Close icons are the × actions used to dismiss the notification reminder and to cancel the Reply or Edit bar. Keep these unchanged; they are not part of this icon pass.
- The current Pending icon is the small clock beside an outgoing message while it is still sending. Keep the pending treatment unchanged in this spec.
- Remove the standalone failed/error icon from a failed outgoing message.
- Show the localized failure message as red text instead, with `refresh - 16.svg` as the Retry action.
- The Refresh icon triggers the existing retry behavior; it does not replace or resend any other message.
- A language-aid failure also shows no standalone error icon and uses `refresh - 16.svg` for its existing Retry action; its muted failure-row treatment otherwise remains unchanged for the later translation-lifecycle spec.

### 8. Word-description popup speaker

- Replace the previous speaker drawing with the supplied `sound-base.svg`, `sound-wave-1.svg`, and `sound-wave-2.svg` layers.
- The three layers occupy the same bounds and tint together as one icon.
- Preserve the current word-popup layout, audio tap behavior, on-device pronunciation, disabled 40% state, and existing wave sequence.
- Preserve all three word-popup text lines: the learning-language word, Latin-script transliteration, and primary-known-language translation. A learning line containing words must not be permanently cached without this metadata; incomplete cached entries are regenerated.
- During playback, animate the two wave layers independently: the inner wave appears first and the outer wave follows. The base remains visible.
- Do not add a new label, tooltip, background, or layout change to the speaker action.

## Interaction and state rules

- New chats still default to Practice mode.
- Mode choice remains private per person and per chat.
- Switching modes keeps the existing behavior: close word/explanation popups and reaction UI, and collapse any expanded learning content.
- Normal mode and Practice mode continue to follow the existing message-display rules; this refresh does not change message content.
- Word taps still open the word-description popup and must not open the message menu.
- Existing simple tap-padding/long-press message actions remain unchanged until the separate long-press spec is approved.

## Acceptance criteria

### Header and switch

- [ ] Normal and Practice screens match their named Figma frames at 390 × 844 before adapting to other screen sizes.
- [ ] Switch sits before the overflow action and the overflow action does not move between states.
- [ ] Back icon → avatar, avatar → name, and name area → switch are each 10 px.
- [ ] Header avatar is 36 px, uses only the refreshed palette, and casts the approved 13% shadow.
- [ ] Partner name is 15 px heavy on an 18 px line in `#46281C`, centered when `typing…` is absent; no online or last-seen status appears.
- [ ] Long partner names truncate in the header without hiding or moving the switch; the full name remains available in chats overview.
- [ ] Normal active shows icon + `Normal`; Practice is icon-only.
- [ ] Practice active shows icon + `Practice`; Normal is icon-only.
- [ ] Both labels are 12 px semibold and `#231208`; both active icons are `#231208`.
- [ ] Whole switch has the `#E1DAD2` outline; neither active pill has an outline.
- [ ] Practice pill and Practice outgoing bubble use the same subtle shadow.
- [ ] A tap anywhere inside the switch flips to the other mode, including the active icon and label.
- [ ] Mode changes only through the header switch; swiping open chat background does not change it.
- [ ] Swipe-to-reply works across the full horizontal message row, including the empty canvas beside incoming and outgoing bubbles.
- [ ] Short or diagonal/vertical gestures on a message row never open Reply; an intentional horizontal swipe still does.

### Surfaces and bubbles

- [ ] Canvas, header, composer, input, and dividers use the approved colors above in both modes.
- [ ] Date labels sit directly on the chat canvas without a pill fill or background.
- [ ] Incoming bubbles are unchanged between modes.
- [ ] Normal outgoing bubbles use the stone treatment with no shadow.
- [ ] Practice outgoing bubbles use the orange treatment and subtle shadow.
- [ ] Existing bubble alignment, grouping, timestamp, and receipt geometry do not move unexpectedly; reaction badges overlap the bubble edge nearest the conversation center and use the approved neutral treatment with a Practice-only shadow.

### Icons and audio

- [ ] Every mapped header, switch, composer, and receipt icon uses the supplied asset at the approved visual size.
- [ ] Existing long press shows the supplied Reply, Edit, Copy, and Delete assets wherever each action is eligible, without changing the action layout or behavior.
- [ ] Incoming-message Report uses `white-flag`; swipe to reply reuses `long-arrow-up-left`.
- [ ] The reaction row uses the supplied `plus-circle` asset for its more-reactions action without changing the picker behavior.
- [ ] View original is mapped to `eye`, but the action is not restored until its placement is approved.
- [ ] A failed outgoing message shows red failure text plus the `refresh` Retry action and no standalone error icon.
- [ ] A language-aid failure shows its existing text plus the `refresh` Retry action and no standalone error icon.
- [ ] Close and Pending keep their current treatments.
- [ ] Translate, sentence-audio, collapse, and single-check are not changed by this spec.
- [ ] The word-popup speaker is composed from the new base and two wave assets.
- [ ] Word audio still plays; the inner and outer waves animate in sequence; unavailable audio remains dimmed and inert.
- [ ] Word taps and message long press remain distinct gestures.

### Responsive and accessibility

- [ ] No header overlap at supported phone widths or 200% system text scaling.
- [ ] Both mode options have accessibility-sized tap targets despite the 34 px visual height.
- [ ] Screen readers announce `Normal, selected` or `Practice, selected` and expose the other mode as an action.
- [ ] Text/icon contrast meets WCAG AA in both modes.
- [ ] Reduced motion keeps the mode state change understandable without decorative movement.

## Success measures

- A side-by-side device review passes every visual value and state above with no unexplained deviation from Figma.
- In manual testing, the active mode is correctly identified in both states without opening another control.
- Existing mode switching, word lookup, message actions, sending, reactions, and receipts complete with no interaction regressions.
- No clipped or overlapping header content at the minimum supported phone width or 200% text scaling.

## Dependencies

- Approved Figma default frames on `Ready for build`.
- Supplied SVG assets under the shared chat icon set.
- Existing Normal/Practice state and word-audio behavior.

## Deferred decisions

- Single-check receipt behavior and placement, to be defined in the next spec.
- View original placement and restoration; its `eye` artwork is already approved.
- Fancy long-press scrim, selected-bubble position, motion, reaction row, action layout, and menu icons.
- Translate, sentence-audio, and collapse behavior and artwork, to be defined in the next spec.

None of these deferred decisions block this visual refresh.
