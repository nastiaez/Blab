# Semantic Translation Fidelity Design

## Problem

The provider translated French `librairie` (bookstore) as Ukrainian
`бібліотеку` (library). The sentence, token segmentation, romanization, and
French token gloss were structurally valid, so Blab's deterministic validators
could not identify the semantic false-friend error.

## Rejected prompt-only repair

Strengthen both translation prompts with one language-independent semantic
fidelity rule:

1. Resolve each source word's meaning in context before selecting target words.
2. Never select a target word only because its spelling resembles the source;
   explicitly guard against cross-language false friends.
3. Back-translate the completed target sentence mentally and compare every
   content word and relationship with the source before returning it.

The exact real Ukrainian fixture still produced `бібліотеку`, so prompt
guidance alone is not an adequate safeguard.

## Decision

Run one narrow semantic audit for every cross-language translation. The audit
must independently render both the source and candidate meanings in the
Primary Known Language and return an explicit equivalence verdict. When they
match, the accepted sentence and all existing metadata remain untouched. When
they differ, the audit returns only the smallest corrected Learning Language
sentence, and Blab regenerates word metadata for that corrected sentence.

The audit response cannot rewrite an equivalent candidate, cannot claim a
meaning mismatch without a correction, and cannot return the unchanged
candidate as its correction. This adds one focused provider request per
cross-language translation, but it is the only language-independent way to
check semantics without a hardcoded dictionary.

## Validation

- Contract tests require the rule in both translation prompts and enforce the
  narrow two-meaning audit schema and parser invariants.
- The exact Alice/Bob Ukrainian fixture must produce `книгарню`, with French
  `librairie` and useful Latin romanization.
- The complete app, language-engine, analysis, formatting, and Android build
  gates must remain green.
