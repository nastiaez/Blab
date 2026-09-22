# Clickable settings retry implementation plan

**Goal:** Make the complete localized “Couldn’t save. Try again.” line retry the exact rejected Settings change on Privacy and Translation Preferences.

## 1. Lock the behavior with failing tests

- Update Privacy recovery coverage to require the shared `couldNotSavePreference` copy in every supported locale.
- Prove the full error sentence is one semantic button with a minimum 48 dp hit target.
- Prove tapping it replays the exact failed value once, updates the control after success, and removes the error.
- Add the equivalent exact-value retry coverage for Translation Preferences.
- Run the focused tests and confirm they fail for the missing interaction.

## 2. Implement one shared retry control

- Extend `InlineSettingError` with an optional retry callback.
- Make the complete visible sentence one tappable, bold, accessible control while preserving the current quiet inline styling.
- Disable the callback during an in-flight retry to prevent duplicate saves.

## 3. Retain and replay failed changes

- Privacy stores the last failed setting and requested boolean, then reuses the existing save path when the error is tapped.
- Translation Preferences stores the last failed save action and reuses the existing save path when the error is tapped.
- Clear the retained action after success; retain it after another failure.

## 4. Verify and review

- Run focused recovery tests, formatting, analyzer, `git diff --check`, the full Flutter suite, and the UI detector.
- Build and install the exact Android revision.
- Recreate Privacy and Translation Preferences failures, confirm retry success, restore all temporary test conditions, and send both screenshots for approval before committing.
