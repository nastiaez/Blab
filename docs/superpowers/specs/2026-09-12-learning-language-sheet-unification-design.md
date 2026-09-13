# Learning-language sheet unification — design spec

**Status:** Approved design direction — implementation in progress; owner review pending
**Scope:** The required first-time practice-language choice in a new chat and the later in-chat change-language sheet.
**Supersedes:** The required-sheet visual-refinement subsection in `2026-09-07-invite-flow-redesign-design.md` and the conflicting language-sheet details in US-022, US-027, FR-20, FR-22, and tech-spec Decision #31.

## Problem

The first-time language sheet and the later Settings sheet currently look like two unrelated experiences. Their hierarchy, row treatment, selection feedback, and confirmation pattern differ even though both ask for the same decision.

Blab should use one calm language-picker design. The first-time version must remain a required step; Settings must remain safely dismissible.

## Goals

- Make both entry points feel like one recognisable language-selection pattern.
- Make the selected language obvious without using heavy cards or visual depth.
- Keep the required first-time choice impossible to accidentally skip.
- Let someone review a Settings change before it takes effect.
- Keep the primary action fixed and visible while a long language list scrolls.

## Non-goals

- No 3D, glass, blur, or added elevation treatment.
- No change to the available languages or their alphabetical ordering.
- No language flags in this picker.
- No separate retry or error button if saving fails.
- No change to the chat header, mode switch, or message area behind the sheet.

## Shared visual system

This is a bottom-anchored warm-white sheet on top of the chat. It is a flat surface, not a floating card.

| Element | Decision |
| --- | --- |
| Reference viewport | 390 × 844 logical px |
| Sheet height | 567 logical px at the reference viewport (about 67% of viewport height), including the bottom safe area. On shorter viewports, reduce the sheet by up to 32 px so the action starts after a complete visible row rather than beside a partial next language. The language list is the only scrolling region. |
| Surface | Keep the existing warm-white sheet surface and warm outline; remove the drop shadow. |
| Top corners | 16 px radius. |
| Background dim | `#231208` at 30% opacity, with no blur. It covers the full chat behind the sheet. |
| Horizontal alignment | Header and primary button: 16 px from both sides. Language-row containers: 16 px from the left, 24 px from the right. |
| Sheet header | Title begins 20 px below the top on the required sheet. Title-to-helper gap: 6 px. Helper-to-list gap: 20 px. |
| Title | `Choose a language to practice`, 18 px bold. |
| Helper | `You can change it later in Settings.`, 14 px regular. |
| Language rows | Separate tappable containers, 48 px high, 8 px apart, no dividers or borders. |
| Row content | 16 px horizontal inner padding and 14 px vertical padding. Label: 15 px / 18 px line height. |
| Unselected row | Transparent on the sheet surface; regular label weight. |
| Selected row | `#F7EFE5` fill; bold label; 18 px `#231208` check, vertically centred at the row’s trailing inset. |
| Scrollbar | Keep the current proportional, slim scrollbar treatment. Centre it in the 16 px right gutter so it does not crowd the language rows. |
| Primary button | 50 px high, 16 px radius, `#F88C5A` fill, white 15 px bold label, 16 px from the bottom safe edge. |
| Disabled first-time button | `#E1DAD2` fill with `#8C735F` text. |
| Saving state | Lock the sheet and replace the button label with a centred white 18 px spinner only while the save is visibly pending. Do not show `Saving…`. |

## Variant A — required first-time choice

This version appears for each person in a newly created chat until that person has selected a practice language.

```
Choose a language to practice
You can change it later in Settings.

  Dutch
  English
  French
  ...

[             Start practicing             ]
```

- There is no drag handle.
- It cannot close by tapping the backdrop or swiping down.
- Back leaves the chat for Chats; reopening the chat presents the required sheet again.
- The chat’s composer, messages, and mode switch remain inactive behind it.
- A new chat begins with no selected language. **Start practicing** uses the disabled treatment until a row is selected.
- The empty-chat copy remains hidden while the required choice is open. The 567 px sheet also visually covers its usual position.
- Choosing a language updates only the row’s local selected state. Tapping **Start practicing** commits the choice. On success, the sheet closes and the first-time Practice tip may appear under its existing rules.
- If saving fails, show no error copy. Restore the selected state and the normal **Start practicing** button so the same action can be tried again.

## Variant B — Settings change

This version opens from the in-chat learning-language entry.

```
                 ━━━
Choose a language to practice
You can change it later in Settings.

  French                                      ✓
  Dutch
  English
  ...

[                   Done                    ]
```

- Show a centred `#E1DAD2` drag handle, 32 × 4 px, 12 px from the sheet top.
- Leave 16 px between the handle and title.
- The currently saved language is selected when the sheet opens; **Done** is active.
- Tapping a different row previews that choice only. It does not alter the chat yet.
- **Done** commits the visible selection. Its save state and silent retry behaviour match Variant A.
- Tapping the dimmed backdrop or swiping the sheet down closes it.
- Closing without **Done** discards the preview. Reopening shows the previously saved language.

## Accessibility and motion

- Every language row remains a 48 px minimum-height target; the primary action remains 50 px high.
- Screen-reader labels identify each row as a language choice and announce its selected state.
- The Settings sheet exposes an accessible Close action in addition to its gesture dismissal. The required sheet exposes no dismiss action.
- The spinner respects reduced-motion preferences; it may render as a static white progress indicator when motion is reduced.
- Labels must continue to reflow without clipping at the app’s supported text scaling. If text scaling requires it, a row may grow taller; it must not compress its label or check.

## Acceptance checklist

- [ ] On a 390 × 844 reference screen, the bottom sheet is about 567 px tall and obscures the empty-chat text behind it; on a shorter screen it ends cleanly after a whole visible language row.
- [ ] Both entry points use the same surface, dim layer, typography, row design, selected state, scrollbar placement, and primary-button design.
- [ ] The required sheet has no drag handle, cannot be dismissed by backdrop tap or swipe, and starts with a disabled **Start practicing** action.
- [ ] The Settings sheet has the approved handle, may be dismissed by backdrop tap or swipe, and opens with the saved language selected.
- [ ] A Settings language choice does not take effect until **Done**; dismissal discards it.
- [ ] A successful save shows a centred button spinner only when there is visible wait, then closes the sheet.
- [ ] A failed save shows no error copy or separate retry action; the same primary button becomes available again.
- [ ] The required language choice remains independent for the two people in the chat.

## Documentation follow-through

- US-022 and US-027 define the two interaction variants.
- FR-20 and FR-22 retain the per-chat and required-choice guarantees.
- Tech-spec Decision #31 records responsive sizing and the shared-component boundary.
- The Play Store tracker remains open until the owner manually confirms the implemented journey.
