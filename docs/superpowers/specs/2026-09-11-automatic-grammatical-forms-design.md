# Automatic grammatical forms — approved simplification

Owner direction, 11 September 2026. Replaces the mandatory chooser and the immediate next-message cutoff from the previous design.

## Product rule

- Always render the complete natural translation. No empty/numbered markers, foreign-word choice pills, neutral paraphrasing to avoid choosing, question-mark control or new bottom sheet.
- Use the person’s saved form first. Otherwise suggest from their name; if unclear, use feminine. A suggestion is a translation preference, never a confirmed profile identity. Do not overwrite an explicit saved preference.
- One consistent localized note: `Using feminine forms for Alice · Change` / `Using masculine forms for Alice · Change`. For the viewer use their display name too. No separate uncertain-name copy.
- Show this quiet, unboxed note once per person per chat, attached to the first relevant message the viewer encounters. Retain it on that message; do not repeat under subsequent messages.
- Change opens the existing chat Translation preferences page. Changing the matching preference updates this annotated message and future messages; other completed history stays fixed. The note does not expire on the next message. Not set falls back to the suggested form/feminine, never to an empty sentence.
- Identify the person independently of name guessing: direct I concerns the author; direct you concerns the other participant. Provider context/audit resolves less direct references. Store a stable author/recipient role so shared results are not rebound to the wrong viewer.
- This task does not claim to repair the separate false-success/source-language Retry bug or certify the whole supported-language matrix.

## Engineering

Preserve both grammatical renderings internally and add optional suggested-form and author/recipient-role metadata to the existing JSON field. Audit returned alternatives too, not only missing ones. Normalize direct first/second-person ownership conservatively and derive display names from trusted participant context. Keep existing translations feminine as the canonical alternate payload required by database validation; client resolves the selected/suggested display.

Extend the account/device ledger with one persistent note target per chat/person and per-message frozen renderings. Existing old correction windows remain readable for migration, but the new note is persistent and future preferences only revise the annotated target. Existing Settings navigation and form rows remain.
