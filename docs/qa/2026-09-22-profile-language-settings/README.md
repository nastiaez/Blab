# Profile language settings QA

## Device

- Bob Local on the Android 16 / API 36 emulator
- 1080 x 2400 physical viewport at the normal system font scale
- Local Supabase backend

## Captured flow

1. `after/01-profile-spanish.png` - Profile with Spanish as the only understood and translation language.
2. `after/02-translation-language-spanish.png` - Translation language editor with the approved copy and Spanish selected.
3. `after/03-languages-understood.png` - Languages you understand editor with Spanish and Ukrainian selected.
4. `after/04-profile-ukrainian-added.png` - Profile after choosing Ukrainian as the translation language; Ukrainian is appended to the understood-language chips and Spanish remains.

## Verification

- 685 tests passed; 15 skipped.
- `flutter analyze` passed with no issues.
- Dart formatting check passed with no changes.
- `git diff --check` passed.
- Production web build passed. Its existing `flutter_tts_web` WebAssembly dry-run warnings remain dependency-owned and do not affect the JavaScript build.
- Real-device semantics confirmed the selected rows, disabled unchanged Save state, Profile translation row, and add-language control.

## UI review

- Hierarchy: 9/10
- Interaction clarity: 9/10
- Consistency with the approved language-list treatment: 9/10
- Accessibility and touch targets: 8.5/10
- Owner approval: pending
