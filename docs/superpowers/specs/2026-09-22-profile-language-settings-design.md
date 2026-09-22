# Profile language settings — approved design

Owner-approved from the interactive HTML prototype on 22 September 2026.

## Profile

- Rename the section to `Languages you understand (N)`.
- Keep selected languages as compact profile chips beside the circular add button.
- Remove the primary-language star from chips.
- Add one outlined settings row directly below the chips: `Translation language` | localized current language | chevron.
- Keep Profile compact; explanatory copy belongs inside the full-screen editors.

## Languages you understand editor

- Title: `Languages you understand`.
- English explanation: `Select every language you can read without translation. In Normal mode, messages in these languages stay as written.`
- Show every supported language as a multi-select list.
- Reuse the shared warm selected-row tint and trailing check.
- Require at least one language.
- Save is inactive until the selection changes.
- Removing the current Translation language assigns the first remaining understood language.
- Back discards the draft; save failure stays on the screen with existing recovery feedback.

## Translation language editor

- Title: `Translation language`.
- English explanation: `Choose the language you understand best. Blab uses it for translations and explanations.`
- Use the same list layout as the understood-language editor, but single-select.
- Show all supported languages, not only already-understood languages.
- The current Translation language begins selected.
- Choosing a new Translation language automatically adds it to Languages you understand; existing understood languages remain.
- Save is inactive until the choice changes.
- Back discards the draft; save failure stays on the screen with existing recovery feedback.

## Localization and accessibility

- Localize titles, explanations, and the add-language semantic label in English, German, Spanish, and Ukrainian.
- Keep Ukrainian copy in informal singular voice.
- Preserve 44–48 logical-pixel touch targets, text scaling, system Back, and the shared selected-row semantics.

## Scope

This packet changes Profile and signed-in Settings. The previously approved first-time onboarding sequence remains a separate implementation packet, but will reuse the same canonical titles and explanations.
