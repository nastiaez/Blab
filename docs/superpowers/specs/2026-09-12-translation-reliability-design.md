# Translation Reliability Design

## Goal

Close the five translation-reliability gaps confirmed by the 2026-09-12 audit without changing Blab's approved translation UX.

## Decisions

1. Every outbound provider request has a 20-second abort deadline. A timeout is reported as a controlled provider failure so the existing provider fallback and retry loop can continue.
2. Automatic reconnect/rebuild retry is limited to transport and temporary service failures. Authorization, validation, stale-request, malformed-result, and unsupported-state failures remain visible until the underlying state changes or the user explicitly retries.
3. Privacy choices are stored per account and re-enter the fail-closed loading state during an account switch. Ephemeral message translations, read queues, hidden-message state, reply/edit drafts, and grammatical-form refresh state also rebuild when the account identity changes.
4. Saving a different conversation tone increments the existing grammatical-preference revision. Open chats then bypass stale cached translations and request fresh results for visible messages.
5. Server completion validation accepts all eleven Blab languages as the primary-known-language lane: Dutch, English, French, German, Hindi, Italian, Portuguese, Spanish, Tamil, Turkish, and Ukrainian.

## Preserved behavior

- The existing single quiet retry, late cache recovery, manual Retry action, and quota retry timer stay unchanged.
- One-word translation, short-message source-classification retry, unsupported-language guidance, Chinese detection, expressive spelling, abbreviations, names, and independent saved variants keep their current contracts.
- No owner-facing tracker item is marked complete from automated checks alone.

## Verification

- Deno tests cover provider abort behavior and the translation contract.
- Flutter tests cover permanent/transient retry classification, account isolation, privacy fail-closed switching, and tone-triggered fresh translation.
- pgTAP covers completion with a non-interface primary known language.
- Full Flutter tests, analysis, Deno formatting/tests, SQL tests when the local stack is available, and repository diff checks run before commit and push.
