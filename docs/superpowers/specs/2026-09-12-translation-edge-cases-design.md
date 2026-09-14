# Translation Edge Cases Design

## Goal

Fix the four translation problems found during the Alice browser and Bob Android acceptance test without slowing normal translations or reloading completed chat history.

This follow-up supersedes the tone-refresh decision in `2026-09-12-translation-reliability-design.md`. The other reliability decisions remain unchanged.

## 1. Ambiguous short messages

Every message is treated as a complete utterance, even when it contains one word.

For automatic source-language detection, the target language is never evidence for the source language. When a short message is ambiguous, the translator resolves it in this order:

1. the current message's spelling and meaning;
2. recent messages from the same sender;
3. the sender's primary known language, but only when it is a plausible language for the text.

The backend must supply the message author's primary known language as private request context. It is a weak tie-breaker, not a command, and must not turn clearly unsupported text into a supported language.

If a provider claims that a short message is already in the target language, leaves it unchanged, and that result conflicts with the available evidence, the result is rejected and the existing single retry runs with explicit source-classification guidance. No extra request is added to the normal success path.

Expected acceptance case: after English messages from Alice, Bob's German view translates `No` to `Nein`.

## 2. Abbreviations combined with names

Participant display names are treated deterministically as names, not language evidence. A recognized abbreviation is also strong source-language evidence when the remaining text contains only compatible Latin-script words or likely names. This covers names outside the current chat, such as `Nastia`, without treating capitalization alone as proof of a name.

Meaning-bearing abbreviations such as `OMG` are expanded conceptually and translated into a natural target-language expression. Names keep their identity and are transliterated when the target script differs. If the provider returns `sourceLang=other` for a supported-looking abbreviation-plus-participant-name message, the result is rejected and the existing single retry runs with explicit guidance.

This guard applies only when a recognized abbreviation is present and all remaining meaningful text is compatible with that supported language. Genuinely unsupported messages, including Chinese while Chinese remains unsupported, still return the unsupported-language state.

Expected examples:

- Ukrainian: `OMG Nastia` -> `Боже мій, Настя!`
- Hindi: `OMG Nastia` -> `हे भगवान, नास्त्या!`
- German: `OMG Nastia` -> `Oh mein Gott, Nastia!`

The exact natural wording may vary, but it must preserve meaning and identity rather than preserve the letters `OMG` by default.

## 3. Conversation tone changes

Changing between informal and respectful tone affects only translations first created after the preference is saved.

- Completed translations remain unchanged.
- Visible and off-screen history are not invalidated or regenerated.
- No historical loading placeholders or background translation requests appear.
- New translations use the current saved tone.
- No tone-specific historical cache variants are added.

This differs from gender selection. Gender can switch the one active correction target using alternatives already returned with that translation. Tone has no precomputed alternatives and no correction window, so it does not modify an existing message.

The global translation-refresh signal currently emitted after saving tone must be removed. Saving and reloading the preference itself remains unchanged.

## 4. Unsupported-language guidance

Unsupported-language copy depends on who authored the message:

- Incoming message: `Blab can't translate this language yet. Showing the original.`
- Outgoing message: `Blab can't translate this language yet. Try <learning language>.`

The original message remains visible in both cases. Only the author can act on writing in a supported language, so incoming guidance must never tell the viewer to change languages.

## Failure and retry rules

- Normal successful translations keep the current single-request path.
- Only suspicious short-message or abbreviation-plus-name classifications may use the existing second attempt.
- At most one automatic retry is added for a provider result.
- If the retry also fails, Blab uses its existing readable failure/Retry behavior.
- Unsupported-language guidance is not presented as a provider or network error.

## Verification

Automated coverage must prove:

- source detection can use same-sender context for ambiguous short utterances;
- the sender's primary known language is only a plausible-language tie-breaker;
- unchanged target-language claims that conflict with context are retried;
- common ambiguous short replies are exercised across all eleven supported languages;
- abbreviation-plus-participant-name messages translate naturally into all eleven target languages;
- genuinely unsupported scripts remain unsupported;
- incoming and outgoing unsupported-language copy differs correctly;
- saving tone does not invalidate completed translations;
- translations first created after a tone change receive the new tone;
- gender's existing active-correction behavior remains unchanged.

Acceptance testing must then repeat the real Alice-in-browser and Bob-on-Android flow for `No`, `OMG Nastia`, tone changes, and incoming/outgoing Chinese guidance. Completion requires screenshots and a plain-language pass/fail report from the actual clients, not test-log images alone.
