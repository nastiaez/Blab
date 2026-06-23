# UX Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement all [quick], [medium], and [large] UX audit fixes screen by screen, skipping [research] items.

**Architecture:** Screen-by-screen fixes, quick → medium → large within each screen. Shared changes (language picker card style, non-latin labels) implemented once as shared widgets then reused. Interactive: confirm before each screen, brainstorm before medium/large items.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, Material 3

---

## File map

| Screen | Primary file(s) |
|---|---|
| Screen 6 — Invite landing | `lib/features/invite/invite_landing_screen.dart` |
| Screen 6b — Language picker | `lib/features/invite/invite_pick_language_screen.dart`, `lib/features/profile/interface_language_screen.dart`, `lib/features/invite/new_chat_screen.dart` |
| Screen 12 — Forgot password | `lib/features/auth/forgot_password_screen.dart` |
| Screen 1b/1 — Auth | `lib/features/auth/auth_screen.dart` |
| Screen 2 — Chat list | `lib/features/chats/chats_screen.dart`, `lib/features/chats/widgets/chat_list_tile.dart` |
| Screen 3 — New chat | `lib/features/invite/new_chat_screen.dart`, `lib/features/invite/invite_owner_screen.dart` |
| Screen 4 — Chat view | `lib/features/chat/chat_screen.dart` |
| Screen 8 — Edit profile | `lib/features/profile/edit_profile_screen.dart` |
| Screen 9 — Change password | `lib/features/profile/change_password_screen.dart` |
| Screen 10 — Change email | `lib/features/profile/change_email_screen.dart` |
| Screen 11 — Privacy | `lib/features/profile/privacy_screen.dart` |
| Screen 13 — Interface language | `lib/features/profile/interface_language_screen.dart` |
| Screen 14 — Delete account | `lib/features/profile/delete_account_screen.dart` |
| Shared | `lib/shared/data/languages.dart`, `lib/shared/widgets/language_card.dart` (new) |

---

## Task 1: Screen 6 — Invite landing [quick]

**Files:** `lib/features/invite/invite_landing_screen.dart`

- [ ] Remove `_TopBarWithLogo` widget and all references to it. Replace the top-level `Column` children with just the `Expanded(child: switch(...))` — no top bar at all.
- [ ] Fix period: `'invited you to chat.'` → `'invited you to chat'`
- [ ] Fix `_UsedBody` copy: `'Ask for a fresh link.'` → `'Ask [inviterName] for a fresh link.'` — requires passing `inviterName` to `_UsedBody`.
  - Change `const _UsedBody()` → `_UsedBody(inviterName: inviterName)`
  - Add `final String inviterName;` field + constructor to `_UsedBody`
  - Update subtitle text to `'Ask $inviterName for a fresh link.'`
- [ ] Run `flutter analyze` — expect 0 issues.
- [ ] Commit: `fix(invite): remove logo/lang switcher, fix period, unify expired/used copy`

---

## Task 2: Screen 6 — Invite landing [medium] — dead-end CTAs

**Brainstorm before building.** Questions to resolve:
- "Go to chats" → `/chats` route
- "Send [name] an invite instead" → `/invite/new` with pre-filled language? Or just go to new chat flow?

- [ ] After brainstorm approval: add two `OutlinedButton` CTAs below the icon+text on both `_ExpiredBody` and `_UsedBody`:
  - Primary: `FilledButton` "Go to chats →" → `context.go('/chats')`
  - Secondary: `OutlinedButton` "Send $inviterName an invite →" → `context.go('/invite/new')`
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `feat(invite): add CTAs to expired and used invite states`

---

## Task 3: Screen 6b — Language picker [quick] — non-latin labels + tap animation

**Files:** `lib/features/invite/invite_pick_language_screen.dart`, `lib/shared/data/languages.dart`

Non-latin languages (codes where `nativeName ≠` latin script): `hi`, `ta`, `uk`. These need `"${lang.nativeName} (${lang.name})"` as display label. Latin languages show `lang.nativeName` only.

- [ ] Add helper to `languages.dart`:
  ```dart
  const _kNonLatinCodes = {'hi', 'ta', 'uk'};

  extension BlabLanguageDisplay on BlabLanguage {
    String get displayLabel => _kNonLatinCodes.contains(code)
        ? '$nativeName ($name)'
        : nativeName;
  }
  ```
- [ ] In `invite_pick_language_screen.dart` `_LanguageRow`, change `lang.nativeName` → `lang.displayLabel`.
- [ ] Fix tap animation: `_LanguageRow` uses `AnimatedContainer` + `Material/InkWell`. The gray flash is the InkWell ripple before the `AnimatedContainer` color updates. Fix: set `splashColor: BlabColors.brand.withOpacity(0.12)` and `highlightColor: Colors.transparent` on `InkWell`.
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `fix(lang-picker): non-latin labels + tap goes directly to brand colour`

---

## Task 4: Screen 6b — Language picker [medium] — shared card widget + apply to all pickers

**Brainstorm before building.** Questions:
- Should the shared widget be a `LanguageCard` stateless widget in `lib/shared/widgets/`?
- Interface language picker (`interface_language_screen.dart`) currently uses a list inside one Card — full replace or wrap?

- [ ] After brainstorm approval: create `lib/shared/widgets/language_card.dart`:
  ```dart
  class LanguageCard extends StatelessWidget {
    const LanguageCard({
      super.key,
      required this.lang,
      required this.selected,
      required this.onTap,
    });
    final BlabLanguage lang;
    final bool selected;
    final VoidCallback onTap;
    // build: same AnimatedContainer + Material/InkWell as current _LanguageRow
    // uses lang.displayLabel (from extension above)
    // splashColor fix from Task 3
  }
  ```
- [ ] Replace `_LanguageRow` in `invite_pick_language_screen.dart` with `LanguageCard`.
- [ ] Update `interface_language_screen.dart` to use `LanguageCard` list (card-per-language, full width, replaces compact list-in-card).
- [ ] Update `new_chat_screen.dart` language picker to use `LanguageCard` list.
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `feat(lang-picker): shared LanguageCard widget, apply to all 3 pickers`

---

## Task 5: Screen 12 — Forgot password [quick]

**Files:** `lib/features/auth/forgot_password_screen.dart`

- [ ] Read `forgot_password_screen.dart` to locate CTA and subtitle.
- [ ] Change CTA copy: `'Send reset link'` → `'Email me a reset link →'`
- [ ] Remove subtitle text widget (the one saying "Enter the email you signed up with…").
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `fix(forgot-pw): CTA copy + remove redundant subtitle`

---

## Task 6: Screen 1b/1 — Auth [quick]

**Files:** `lib/features/auth/auth_screen.dart`

- [ ] Read `auth_screen.dart` fully to understand current layout.
- [ ] Log-in mode: find and remove tagline widget when in log-in tab.
- [ ] Move mode-switch link ("Log in" / "Sign up") from top-right → bottom of screen (below CTA).
- [ ] Move "Forgot password?" from below CTA → directly below the password field.
- [ ] Add caption below email field in log-in mode: `'Use the email you signed up with.'` in `BlabColors.textMuted`, fontSize 12.
- [ ] Sign-up CTA: `'Create account →'` → `'Join Blab →'`
- [ ] Consent copy: `'By creating an account you agree to our…'` → `'By continuing, you agree to our…'`
- [ ] Error messages: ensure backend error renders above the CTA button, not below form.
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `fix(auth): quick copy + layout fixes (mode switch, forgot pw, tagline, consent)`

---

## Task 7: Screen 1 — Sign up [medium] — Terms on language picker

**Brainstorm before building.** The language picker for SSO users (shown after Google/Apple sign-in before entering chats) needs a "By continuing, you agree to…" consent line. Where does this picker live currently?

- [ ] After brainstorm: locate SSO post-auth language picker screen/sheet.
- [ ] Add consent line above or below the CTA: `'By continuing, you agree to our Terms and Privacy Policy.'` with tappable links (reuse `openExternalUrl` + `legal_links.dart`).
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `feat(auth): add Terms/Privacy consent to SSO language picker`

---

## Task 8: Screen 1 — Sign up [large] — email form on separate screen

**Brainstorm before building.** This is a routing change:
- Current: SSO buttons + "or" divider + email form all on one screen
- Target: SSO buttons first, "Continue with email →" button opens new screen with name+email+password only

Requires: new route `/auth/email-signup`, new screen widget, router update.

- [ ] After brainstorm + design approval: implement new `EmailSignUpScreen` widget.
- [ ] Add route to `router.dart`.
- [ ] Update `auth_screen.dart` login mode similarly (SSO first, "Continue with email →" → email+password screen).
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `feat(auth): SSO-first layout, email form on separate screen`

---

## Task 9: Screen 2 — Chat list [quick]

**Files:** `lib/features/chats/chats_screen.dart`

- [ ] Empty state copy: find empty state widget, change text to `'Invite a friend and start chatting.'`
- [ ] Unread preview: in `chat_list_tile.dart`, find where `fontWeight: FontWeight.bold` (or `w700`) is applied to preview text for unread. Remove it — weight stays regular, badge count is the unread signal.
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `fix(chat-list): empty state copy + remove bold unread preview`

---

## Task 10: Screen 2 — Chat list [medium] — icon, sort, dedupe, FAB

**Brainstorm before building.** Items:
- Empty state icon: swap generic bubble → `BlabIcon` / Blab mark. Which asset?
- FAB: bottom-right, `FloatingActionButton`, navigates to `/invite/new`. Confirm position doesn't clash with bottom nav.
- Sort order: verify `chat_list_state.dart` orders by `last_at desc`.
- Deduplicate: locate deduplicate logic (Step 2.9 referenced in audit).

- [ ] After brainstorm: implement each item above.
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `feat(chat-list): Blab icon empty state, FAB, verify sort, fix dedupe`

---

## Task 11: Screen 3 — New chat [medium]

**Brainstorm before building.** Items:
- Language picker: already fixed by Task 4 (LanguageCard). Verify it's applied.
- Dead space below invite URL: what visual element? Illustration? Decorative pattern?
- Copy review on "Send the invite" screen: read current copy, propose new copy.

- [ ] After brainstorm: implement visual element + copy.
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `fix(new-chat): invite screen visual + copy refresh`

---

## Task 12: Screen 4 — Chat view [quick]

**Files:** `lib/features/chat/chat_screen.dart`

- [ ] Name capitalisation: find where partner name renders in header. Wrap with `.capitalize()` or `name.isEmpty ? '' : name[0].toUpperCase() + name.substring(1)`.
- [ ] Remove Online indicator: find `'● Online'` text and presence dot widget, remove both.
- [ ] Menu icon: find `Icons.more_horiz` (horizontal ···), change to `Icons.more_vert` (vertical ⋮).
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `fix(chat): name caps, remove Online, vertical menu icon`

---

## Task 13: Screen 4 — Chat view [medium]

**Brainstorm before building.** Items:
- Incoming bubble width: cap at 75% — use `ConstrainedBox(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75))`.
- Timestamp inside bubble: move from outside → bottom-right inside bubble, muted colour.
- Attachment picker: expand "+" to emoji / photo / camera sheet.
- Auto-open keyboard: `autofocus: true` on `TextField` when chat is empty for the first time.
- Tamil script toggle: add toggle in chat settings sheet (per-chat preference).

- [ ] After brainstorm: implement each item.
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `feat(chat): bubble width cap, timestamp inside, attachment picker, auto-keyboard, script toggle`

---

## Task 14: Screen 4 — Chat view [large]

**Design-first. Brainstorm each separately before building:**
- Empty chat info card
- Word tap discoverability + message action icons
- ··· menu expansion

These are separate brainstorms → each gets its own implementation task.

---

## Task 15: Screen 8 — Edit profile [quick + medium]

**Files:** `lib/features/profile/edit_profile_screen.dart`

**[quick]**
- [ ] Avatar initials colour: find where avatar background colour is set, change from purple/muted → `BlabColors.brand`.

**[medium — brainstorm first]**
- Camera badge on avatar
- Two name fields (First + Last)
- Bio/About field
- Floating Save button

---

## Task 16: Screen 9 — Change password [quick + medium]

**Files:** `lib/features/profile/change_password_screen.dart`

**[quick]**
- [ ] "Forgot your password?" link: move from below Save → directly below Current password field.
- [ ] Strength bar: show faint empty bar on focus (not only while typing) — set initial `_strength = 0.0` and show bar whenever field has focus.

**[medium — brainstorm first]**
- Blur validation on Confirm password field.

---

## Task 17: Screen 10 — Change email [quick + medium]

**Files:** `lib/features/profile/change_email_screen.dart`

**[quick]**
- [ ] Current email field: style as read-only — gray background (`Colors.grey.shade100`), no border, `enabled: false` or `readOnly: true`.
- [ ] Helper text: shorten to `'We\'ll send a confirmation link. Your old email stays active until you confirm.'`

**[medium — brainstorm first]**
- Floating CTA button in body (in addition to nav bar "Send").

---

## Task 18: Screen 11 — Privacy [quick]

**Files:** `lib/features/profile/privacy_screen.dart`

- [ ] Fix last-line copy: find `'These two toggles control what your phone shares with our servers'`, replace with `'These settings control what other people can see about you.'`
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: (batch with next screen)

---

## Task 19: Screen 13 — Interface language [quick]

**Files:** `lib/features/profile/interface_language_screen.dart`

- [ ] Non-latin labels: already handled by `lang.displayLabel` extension (Task 3). Verify it's used here after Task 4.
- [ ] Card style: handled by Task 4 (LanguageCard). Verify.
- [ ] Run `flutter analyze` — 0 issues.
- [ ] Commit: `fix(settings): privacy copy, interface language uses shared card`

---

## Task 20: Screen 14 — Delete account [quick + medium]

**Files:** `lib/features/profile/delete_account_screen.dart`

**[quick]**
- [ ] Warning icon colour: `Icons.warning_amber_rounded` color `BlabColors.brand` → `Colors.red.shade600`.
- [ ] "This is permanent" text: increase `fontSize` or add `fontWeight: FontWeight.w800`.
- [ ] Copy: `'Your settings and language picks'` → `'Your settings and preferences.'`

**[medium — brainstorm first]**
- SSO user confirmation flow (no password → type "DELETE" or re-auth Google).
- Partner impact copy: add `'Your partners will no longer be able to message you.'`

---

## Task 21: Global — arrow convention [medium]

**Files:** all screens

- [ ] Audit every primary `FilledButton` CTA across all screens. Any that are primary actions and don't end with ` →` should be updated.
- [ ] Known cases from tasks above: already handled inline.
- [ ] Run grep: `grep -r "FilledButton" lib/` to catch any remaining.
- [ ] Commit: `fix(global): →  on all primary CTAs`

---

## Self-review

**Spec coverage:**
- Screen 6 quick ✓ (Task 1), medium ✓ (Task 2)
- Screen 6b quick ✓ (Task 3), medium ✓ (Task 4)
- Screen 12 quick ✓ (Task 5)
- Screen 1b/1 quick ✓ (Task 6), medium ✓ (Task 7), large ✓ (Task 8)
- Screen 2 quick ✓ (Task 9), medium ✓ (Task 10)
- Screen 3 medium ✓ (Task 11)
- Screen 4 quick ✓ (Task 12), medium ✓ (Task 13), large → design-first (Task 14)
- Screen 8 ✓ (Task 15)
- Screen 9 ✓ (Task 16)
- Screen 10 ✓ (Task 17)
- Screen 11 quick ✓ (Task 18)
- Screen 13 ✓ (Task 19) — covered by Tasks 3+4
- Screen 14 ✓ (Task 20)
- Global arrow ✓ (Task 21)
- Screen 5 (Profile redesign) — excluded, design-first
- Global large items — excluded, design-first

**Placeholders:** none.

**Type consistency:** `BlabLanguageDisplay.displayLabel` defined once in Task 3 and referenced in Tasks 4, 19. `LanguageCard` defined in Task 4, used in Tasks 4, 19.
