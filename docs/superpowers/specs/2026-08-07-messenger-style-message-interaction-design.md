# Messenger-style long-press interaction (reaction row + action row)

**Date:** 2026-08-07
**Phase:** 1 (static UI), building on top of the reaction feature shipped earlier today
**Status:** Approved, ready for plan
**Relates to:** `message_action_sheet.dart` (current bottom-sheet implementation, being replaced),
`chat_screen.dart` `_InputBar`/composer, reaction picker work from
`2026-08-07` (`message_reaction_bar.dart`, `showReactionPickerSheet`)

---

## Problem

Today, long-pressing a message opens a modal bottom sheet: a drag handle, an
emoji row, a "View original" block, then a vertical list of Reply / Edit /
Copy / Delete / Report rows — all behind a darkened scrim. The owner wants
this replaced with the interaction pattern Messenger uses: a small floating
emoji row appears directly above the pressed bubble, and the action buttons
appear where the message composer normally sits, both without dimming the
rest of the screen. The chat itself stays visibly "live" underneath — you
can keep scrolling — rather than being blocked by a modal.

"View original" is dropped from this flow for now. The capability (viewing
the untranslated authored text) stays in the codebase; where it resurfaces
is an explicit, separate future decision — not solved here.

---

## Behavior

1. Owner long-presses a message bubble (haptic feedback, as today).
2. Two things appear at once, no scrim, no background dimming:
   - A **floating reaction row** positioned relative to that specific
     bubble (see Positioning below): the six quick emoji
     (`kQuickMessageReactions`), each in a compact circular tap target,
     packed closer together than the current sheet's spacing, plus a "+"
     as the last item. If the viewer has already reacted to this message,
     that emoji shows a distinct (selected) background in the row.
   - An **action row** that replaces the message composer in place: icon +
     small label buttons for Reply / Edit / Copy / Delete / Report, using
     the exact same eligibility rules as today (`canReplyToMessage`,
     `canEditMessage`, `isOutgoing` for Delete vs. Report).
3. Tapping any quick emoji sends that reaction immediately (same
   `MessageReactionsNotifier.react` call as today) and closes both rows,
   restoring the composer.
4. Tapping "+" opens a new bottom sheet — half the screen height, rounded
   top, drag handle, standard drag-down-to-dismiss — containing a search
   field and the full emoji set (not just the current 12-item
   `kMoreMessageReactions`). Picking an emoji there sends the reaction and
   closes everything, same as step 3. This sheet is the one exception to
   "no modal/no scrim" in this feature — it's an explicit secondary sheet
   the owner asked for, not the primary interaction.
5. Tapping an action button in the action row runs that action exactly as
   today (reply pre-fills the reply bar, edit pre-fills the composer, copy
   copies text, delete/report open their existing confirmation flows) and
   closes both rows.
6. Dismissing without picking anything: tapping anywhere else in the chat
   (the existing tap-to-close-menu handler already wrapping the message
   list), or starting to scroll the message list, closes both rows and
   restores the composer. No explicit close button is needed for this case.
7. The badge-tap-to-reopen-picker flow shipped earlier today
   (`showReactionPickerSheet`) is superseded by this new "+" sheet — same
   underlying need (change an existing reaction), reusing the new
   search-and-full-set sheet instead of the old curated-list one.

---

## Positioning

The reaction row is positioned using the pressed bubble's actual on-screen
rectangle, captured at long-press time (via that message row's own
`BuildContext.findRenderObject()` — no extra `GlobalKey`s needed since each
message row already has its own context at the point `onLongPress` fires).

Default rule: the row's bottom edge sits flush against the bubble's top
edge (no gap) — "flush" meaning literally touching, not floating
disconnected above it. Horizontally, it's clamped to stay fully on-screen
with small side margins, roughly centered over the bubble.

The row is allowed to overlap the chat header (partner name/avatar bar) if
placing it flush against a bubble near the top of the viewport would
otherwise require going off-screen — it renders in an `Overlay` entry above
the header, so overlapping it visually is fine; the header is not touched
or altered by this feature.

For a bubble taller than roughly 3 lines of text, or a photo bubble: instead
of computing the flush position against the (potentially far-off-screen)
true top of that tall bubble, the row anchors near the Y coordinate of the
actual long-press touch point instead, allowed to overlap down into the top
portion of the bubble/photo. This keeps the row visually attached to where
the owner's thumb is, rather than drifting away or forcing a scroll.

Concretely: compute `flushY = bubbleRect.top`. Compute a `minY` (safe-area
top plus a small fixed padding). If `bubbleRect.height` is within the
"short" range, use `rowBottom = flushY`. Otherwise (tall bubble/photo), use
`rowBottom = max(minY + rowHeight, pressY + smallOffset)` — i.e. prefer
anchoring near the press point, but never let the row's top go above `minY`.

---

## Scroll and dismiss behavior

The message `ListView` is never locked or intercepted. No full-screen
transparent tap-catcher is added — the floating reaction row and action row
are the only new hit-testable surfaces; everything else passes through to
the list exactly as it does today. Dismissal is driven by two existing/simple
hooks, not by gesture interception:

- The message-list area already has a `GestureDetector(onTap: _closeMenu,
  behavior: HitTestBehavior.translucent)` wrapper (used today to close the
  "⋯" chat-menu dropdown). It's extended to also clear the selected message
  when active.
- A scroll listener on the existing `_scroll` `ScrollController` (or a
  `NotificationListener<ScrollStartNotification>`) clears the selected
  message the moment a user-initiated scroll begins.

Both simply set `_selectedMessage = null`, which removes the `Overlay`
entry and swaps the action row back to the normal composer — no special-case
animation is required beyond what `AnimatedSwitcher`/implicit widget removal
already gives for free.

---

## Components

- `chat_screen.dart`:
  - `_ChatScreenState` gains `Message? _selectedMessage` and the `Rect`
    captured at long-press time.
  - `onLongPress` in the message row no longer calls `showMessageActionSheet`;
    it captures the bubble's `Rect`, sets `_selectedMessage`, and inserts an
    `OverlayEntry` (via `Overlay.of(context)`) rendering the new
    `_FloatingReactionRow` positioned per the rule above.
  - The existing conditional composer slot swaps `_InputBar` for a new
    `_MessageActionRow` widget when `_selectedMessage != null`.
  - The existing `_closeMenu`-wired `GestureDetector` and the scroll
    listener both clear `_selectedMessage` (and remove the overlay entry).
- New `lib/features/chat/widgets/floating_reaction_row.dart`:
  - `_FloatingReactionRow` — the compact circular emoji row + "+", packed
    spacing, selected-state background for the viewer's existing reaction
    (reuses `kQuickMessageReactions`).
- New `lib/features/chat/widgets/message_action_row.dart`:
  - `_MessageActionRow` — icon + small label buttons, same
    eligibility/action logic `showMessageActionSheet` has today, laid out
    horizontally in the composer's slot.
- `message_action_sheet.dart`: the modal-sheet `showMessageActionSheet` and
  its `_ActionRow`/`_ReactionPicker` internals are removed once the new
  components cover the same behavior — `MessageAction` enum,
  `canReplyToMessage`/`canEditMessage`, and `kQuickMessageReactions`/
  `kMoreMessageReactions` constants are kept (still used by the new
  components) but relocated if `message_action_sheet.dart` itself goes away
  entirely. `showReactionPickerSheet` (added earlier today for badge-tap)
  is replaced by the new full-set-with-search sheet from step 4.
- New full-emoji-with-search sheet: half-screen height, drag-to-dismiss,
  search field. Needs a broader emoji dataset than the current hand-picked
  18. **Technical decision (mine, logged in tech-spec):** evaluate a small
  well-maintained emoji-data package (e.g. one exposing emoji + search
  keywords without pulling in a full IME-replacement widget) vs. a bundled
  static dataset; pick whichever keeps the addition lean, during
  implementation planning — not a product question.

---

## Error handling / edge cases

- Long-pressing a message with no eligible actions at all (shouldn't happen
  today — Copy is always available — but if the eligibility list is ever
  empty, the action row would render empty; not expected, no special
  handling beyond what already exists).
- Reacting via the row or the "+" sheet uses the exact same
  `MessageReactionsNotifier.react` path already fixed today (insert-first
  with conflict fallback) — no new backend/data-layer risk introduced by
  this UI change.
- If the device is rotated or the keyboard opens while the row is showing,
  the simplest correct behavior is to dismiss (same as a scroll-start) —
  avoids stale positioning math against a `Rect` captured before the
  layout change.

---

## Testing

Existing reaction-flow tests (`message_reaction_bar_test.dart`,
`message_reactions_state_test.dart`) are unaffected — they test the
badge/data layer, not the entry point. `chat_attachment_sheet_test.dart`-style
widget tests are added for the two new components
(`_FloatingReactionRow`, `_MessageActionRow`) covering: correct actions show
per message eligibility, tapping an emoji/action fires the right callback
and dismisses, and the selected-reaction background shows when the viewer
has already reacted. Positioning math (flush vs. press-anchored) is
exercised via a small pure function extracted for the Y-coordinate
calculation, unit-tested directly rather than through widget geometry.
