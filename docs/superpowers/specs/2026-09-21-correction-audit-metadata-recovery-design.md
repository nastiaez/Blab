# Correction Audit Metadata Recovery Design

## Problem

A same-language correction audit can return a correct repaired sentence while
returning stale word-help tokens from the learner's original sentence. The L09
Tamil case returned the correct plural verb `இருக்கிறார்கள்` in
`correctedText`, but the token list still ended with the original singular verb
`இருக்கிறது`. Blab correctly rejected the package because concatenating the
token text did not reproduce the corrected sentence, leaving both viewers with
`translation_unavailable`.

## Decision

Keep strict sentence/token validation. When the correction audit's semantic
fields are valid but only its token list fails exact reproduction, preserve the
accepted corrected sentence, explanation, and confidence, then run the existing
focused word-metadata repair for that immutable corrected sentence. Accept the
audit only when the replacement tokens reproduce the corrected sentence
exactly and contain valid known-language glosses and required romanization.

This recovery is generic. It does not contain Tamil words, grammar rules, or a
sentence dictionary. It runs only on the rare malformed-token path; valid
correction audits still use one audit request.

## Rejected approaches

1. **Retry the complete correction audit.** The exact Tamil case repeated the
   same mismatch through four job attempts. A full retry can also rewrite a
   correction that is already correct.
2. **Accept the mismatched tokens.** This would let the visible correction,
   word popup, and audio disagree.
3. **Hardcode the Tamil singular/plural pair.** This would fix one example and
   create an unbounded language-specific dictionary.

## Data flow

1. Parse and validate the correction audit's semantic fields.
2. Validate that tokens reproduce `correctedText` exactly.
3. If they do, return the audit unchanged.
4. If only token reproduction fails, call the existing metadata-only repair
   with `correctedText` as immutable input.
5. Accept only a fully validated replacement token list; otherwise keep the
   existing controlled failure.

## Verification

- A regression fixture reproduces the real Tamil response: plural corrected
  text plus a stale singular token.
- The parser preserves the valid correction while marking only metadata for
  recovery; the strict public parser still rejects the incomplete package.
- The service flow invokes metadata-only recovery and never reruns or rewrites
  the corrected sentence.
- The exact Alice/Bob Tamil chat produces the plural correction for both
  viewers, with French explanation, French word meanings, useful romanization,
  and Tamil audio.
- The full language-engine, Flutter, analysis, formatting, and Android build
  gates remain green before the repaired packet is offered for approval.
