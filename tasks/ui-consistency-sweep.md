# UI Consistency Sweep

Durable source of truth for the `codex/ui-consistency-sweep` branch and the Blab Dev 1 review topic.

## Working rules

- Review and ship one small screen packet at a time.
- Capture the current app state before changing production UI.
- Add focused regression coverage before each fix.
- Send one real-app screenshot set for owner review.
- Commit, push, and merge only after explicit owner approval.
- Update this checklist immediately after each packet changes status.
- First-time onboarding and localization/language-engine QA belong to separate branches and are excluded here.

## Completed packets

- [x] Shared UI kit and approved palette (`bb00391` and follow-up commits)
- [x] Chats and Invite primary screens
- [x] Authentication screens (`40b69e9`)
- [x] Account, Settings, and Profile language settings (`5b34eba`)
- [x] Chat actions and failure states (`5448a96`)

## Packet 5A: Chat actions and failure states — complete

- [x] Capture current failed, pending, and retry message states.
- [x] Review reply, edit, delete, report, block, reaction, and emoji actions/sheets.
- [x] Review word help and translation/correction failure states.
- [x] Verify orange controls use warm ink (`#46281C`) for text, icons, and loaders, including Start practicing.
- [x] Add focused regressions for confirmed inconsistencies.
- [x] Implement only confirmed consistency fixes.
- [x] Run focused tests, full QA, static checks, UI detector, and production build.
- [x] Send one real-app screenshot review set.
- [x] Owner approved the real-app screenshot set.
- [x] Commit, push, merge, and mark this packet complete.

Review gate: 691 tests passed, 15 skipped; analysis, formatting, UI detector,
production web build, GitHub Quality, Android release compile, and local Supabase
integration passed. Owner screenshot approval received.

## Packet 5B: Media, secondary sheets, and remaining system states — in progress

- [x] Review Gallery, photo preview, and Share image.
- [x] Review learning-language and translation-preference sheets.
- [x] Review the Auth language picker and remaining success/loading/disabled states.
- [x] Review Chats loading, error, and offline states not already covered.
- [x] Review Invite loading, preparation, and share errors not already covered.
- [x] Run focused regressions, full QA, static checks, UI review, and production build.
- [x] Send the real-app screenshot set and receive owner approval.
- [ ] Commit, push, merge, confirm remote CI, and mark this packet complete.

## Packet 6: Final full-screen consistency review

- [ ] Review every production route with Alice and Bob.
- [ ] Review long German and Ukrainian copy.
- [ ] Review at 200% text scaling.
- [ ] Fix only confirmed visual inconsistencies.
- [ ] Run final QA, screenshot review, approval, and merge.
