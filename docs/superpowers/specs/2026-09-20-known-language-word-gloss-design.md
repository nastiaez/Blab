# Primary Known Language Word Gloss Design

## Goal

Ensure every tappable Practice word shows its meaning in the viewer's Primary Known Language, including when neither the Learning Language nor Primary Known Language is English.

## Root cause

The translation prompt requests glosses in the Primary Known Language, but its concrete grammatical-form example contains hardcoded English gloss values. The focused retry prompt also requests token structure and Romanization without explicitly restating the gloss language. For French learning output with German as Primary Known Language, the provider followed the English example and returned English word meanings while correctly returning the full German sentence lane.

The cache identity and storage routing are already correct: prepared results are separated by message, Learning Language, and Primary Known Language. The defect is created before storage.

## Design

1. Remove concrete English gloss values from language-independent prompt examples. Keep the grammatical-form example focused on the changed text fragments and refer token metadata back to the language-aware token rules.
2. Make the standard prompt and focused retry prompt explicitly require every content-token gloss in the named Primary Known Language.
3. Keep the existing structural token validation and cache identity unchanged. Do not add word-specific mappings or a custom dictionary.
4. Add prompt-contract regressions for a French Learning Language and German Primary Known Language so no English gloss example can re-enter either provider path.
5. Re-run the exact L03 French/German message through the real provider. The repair is accepted only when `librairie` visibly shows `Buchhandlung` on Android and the stored package still identifies German as the Primary Known Language.

## Fallback

If the exact provider rerun still returns English word meanings, add one focused gloss-only repair call. That fallback must rewrite only token meanings, preserve the accepted sentence translation and correction result, and never introduce per-word hardcoding.

## Preserved behavior

- Sentence translation and corrections remain unchanged.
- Interface Language remains interface-only.
- Romanization remains per word and is hidden when identical to the displayed word.
- Existing language-pair cache separation remains unchanged.
- A valid sentence is not rejected solely because optional token metadata is malformed.

## Fallback activation — 2026-09-21

L08 Portuguese proved that prompt wording alone is insufficient. The provider
returned a correct Portuguese sentence and French sentence lane, but copied
every Portuguese token into its own `gloss`. The existing validator accepted
those values because they were non-empty and structurally valid.

Three repair approaches were considered:

1. Retry the whole translation. This is simple, but can change an already
   correct sentence and repeats the expensive part of the request.
2. Repair only the token metadata. This preserves the accepted sentence and
   correction result while making one small extra request only for a clearly
   suspicious result.
3. Maintain language-specific word mappings. This would grow into a brittle
   dictionary and is rejected.

Use option 2. When Learning Language and Primary Known Language differ, treat
multi-word metadata as suspicious only when every content-token gloss is a
normalized copy of that token or its romanization. A focused metadata request
must reproduce the accepted sentence exactly, use one content token per word,
put every meaning in the Primary Known Language, and retain required
romanization. If that focused repair cannot produce a valid token sequence,
do not save the suspicious metadata; let the normal provider retry/failure
path handle the job.

Because previously cached packages may contain structurally valid copied
glosses, advance the translation cache contract and regenerate them under the
stronger validator.
