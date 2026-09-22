# Profile Language Settings Implementation Plan

**Goal:** Replace the unexplained primary-language star with a compact Profile summary and two clear full-screen language editors.

**Architecture:** Keep the existing `known_languages` and `primary_known_language` profile fields. Treat `primary_known_language` as the user-facing Translation language. Both editors use one shared screen structure and the existing `LanguageCard`; saves remain one atomic profile update.

**Spec:** `docs/superpowers/specs/2026-09-22-profile-language-settings-design.md`

## Task 1: Lock the behavior with regression tests

- [x] Add tests for canonical copy, selected-row behavior, inactive unchanged Save, no stars, Profile summary, and error recovery.
- [x] Add Translation language tests for current selection, all-language access, automatic understood-language addition, Back discard, and failed save.
- [x] Run the focused tests and confirm they fail for the old flow.

## Task 2: Build the two editors and Profile summary

- [x] Add the shared full-screen language settings structure.
- [x] Convert Known Languages to the approved multi-select editor.
- [x] Add the single-select Translation language editor and route.
- [x] Remove chip stars and add the compact Profile row.
- [x] Add all launch-locale copy and regenerate localization bindings.

## Task 3: Verify and review

- [ ] Run focused tests, full Flutter tests, static analysis, formatting, UI detector, and production builds.
- [ ] Verify the complete interaction on the real app: current selections, Back discard, successful save, automatic understood-language addition, and persistence after reopen.
- [ ] Capture the final Profile and both editor states from the app for owner review.
- [ ] After owner approval only, commit, push, and merge the full Account & Settings packet.
