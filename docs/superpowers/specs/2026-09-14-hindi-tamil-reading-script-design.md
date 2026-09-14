# Hindi and Tamil reading script — approved design

Owner direction, 14 September 2026.

## Goal

Let Hindi and Tamil learners read Blab-generated sentences either in the language's native script or in English letters, without turning script into a writing rule or adding another translation request.

## Preference model

- Store one account-wide `Reading script` preference with two values: `native` and `english_letters`.
- Default to `native`, preserving today's behavior for existing and new accounts.
- The same choice applies to both Hindi and Tamil. Native mode uses Devanagari for Hindi and Tamil script for Tamil.
- Do not expose this preference for Ukrainian or any other language in this version.
- Preserve the saved choice while the row is hidden.

## Settings placement and copy

Reuse the existing Translation preferences card, row, divider, arrow, and checkmarked bottom-sheet treatment used by Gender form.

### Chat → Translation preferences

- Show one `Reading script` row only when that chat's learning language is Hindi or Tamil.
- For Hindi, the current value and native option read `Hindi script`; for Tamil, they read `Tamil script`.
- The alternative reads `English letters`.
- If the chat changes to another language, remove the row immediately. If it changes back, restore the row with the saved account-wide choice.
- Keep the redesigned language-selection sheet focused on language selection; do not add script controls to it.

### Profile → Translation preferences

- Show one `Reading script` row only while the account has at least one current Hindi or Tamil learning conversation.
- If only one eligible language is present, use its contextual native label: `Hindi script` or `Tamil script`.
- In the uncommon case that both are present, use `Native scripts` as the native label and make the bottom sheet clear that the single choice affects both languages.
- If the last eligible conversation changes away from Hindi or Tamil, hide the row without deleting the saved choice.

Both entry points edit the same account-wide preference and update each other immediately.

## Sentence behavior

- Apply the preference only to Blab-generated Hindi or Tamil learning text: Practice sentences, generated corrections, generated Normal-mode fallback translations, and the matching primary text in reply previews.
- Keep authored messages and `Original` exactly as the sender typed them, whether they used native script or English letters.
- Do not alter Chats-list previews in this version.
- When the preference changes, immediately re-render eligible past and current messages from cached data in both directions. Do not request translation, correction, or AI work again.
- Use English letters only when every content word required for the displayed sentence has usable Romanization metadata. Otherwise render the whole sentence in native script; never mix scripts because of partial metadata.
- Preserve punctuation, whitespace, emoji, links, mentions, numbers, and other protected content while assembling the English-letter sentence.

## Word descriptions and audio

- Native mode: native word is primary, English-letter Romanization is secondary, then the meaning.
- English-letters mode: Romanization is primary, native word is secondary, then the meaning.
- The speaker always pronounces the native-language word. The display preference does not change the audio source or locale.
- If sentence Romanization falls back to native script, word descriptions keep the native-mode hierarchy for that sentence.

## Writing and correction

- Script choice controls reading only. It never restricts what a user may type.
- A valid native-script Hindi or Tamil message must not be corrected merely because the preference is `English letters`.
- A valid Romanized Hindi or Tamil message must not be corrected merely because the preference is `native`.
- Store, send, edit, copy as Original, and show the author's own authored bubble exactly as typed. Only genuine language mistakes use the existing correction behavior.

## Data and rendering

- Add one constrained account preference with `native` as the database default and `english_letters` as the only alternative.
- Load and update it through the existing account-profile preference flow.
- Reuse cached native sentences and per-word Romanization already returned by the translation contract. Do not add script variants to translation requests, prepared-package identities, or cache keys.
- Keep native token text available alongside Romanization so word lookup and TTS remain correct when the visible sentence uses English letters.
- A preference update invalidates presentation state only, causing loaded eligible history and both settings entry points to rebuild without a loading state.

## Failure behavior

- If saving fails, keep the previous selected value and show the existing `Couldn’t save. Try again.` settings feedback.
- If a message lacks complete Romanization, use the native sentence silently. This is a safe display fallback, not a translation failure.

## Accessibility and localization

- Keep existing 44-point minimum tap targets, semantic row labels, focus order, text scaling, and contrast.
- Localize `Reading script`, `Hindi script`, `Tamil script`, `Native scripts`, and `English letters` in every launch interface language.
- The selected bottom-sheet option remains exposed to assistive technology and uses the existing visual checkmark.

## Verification

- Cover the preference default, valid values, persistence, account isolation, and synchronization between Profile and Chat entry points.
- Cover row visibility for Hindi, Tamil, other languages, language changes, and the both-languages Profile edge case.
- Cover Hindi and Tamil sentence rendering in both modes, punctuation preservation, complete-metadata gating, whole-sentence fallback, past-message switching without a new translation request, and the unchanged authored/Original paths.
- Cover word-description hierarchy and native-language audio in both modes.
- Cover valid native-script and Romanized input without script-only correction.
- Run the complete automated suite and static analysis.
- Manually test Alice in the browser and Bob in the Android emulator across Hindi and Tamil, both directions, both script choices, past-message switching, settings synchronization, word descriptions, audio, and authored input. Save and send screenshots of the final verified states.

## Out of scope

- Per-chat script choices.
- Showing both scripts together in a sentence.
- Script preferences for Ukrainian or other languages.
- Transliteration editing, style choices, or multiple Romanization standards.
- Reprocessing historical messages, changing AI prompts solely for display, or changing the language-selection sheet.
