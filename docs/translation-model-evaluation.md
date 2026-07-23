# Translation model evaluation

Last reviewed: 2026-07-21

## Decision status

Production remains on `openai/gpt-4o-mini` while the candidates below are
evaluated. Blab no longer pins OpenRouter to Azure, but every request still
requires Zero Data Retention, denied data collection, fallback routing, and
support for every requested parameter.

OpenRouter's live ZDR catalog currently offers `openai/gpt-4o-mini` only
through Azure. Removing the provider allowlist therefore improves future
routing flexibility but does not currently provide cross-provider redundancy.

## Shortlist

| Candidate | Why test it | Current ZDR route | OpenRouter list price per 1M input/output tokens |
| --- | --- | --- | --- |
| `openai/gpt-4o-mini` | Production baseline and lowest migration risk | Azure | $0.15 / $0.60 |
| `google/gemini-3.1-flash-lite` | Google documents it for high-volume translation; structured output; different provider | Google Vertex | $0.25 / $1.50 |
| `openai/gpt-4.1-mini` | Stronger instruction following than the current baseline | Azure | $0.40 / $1.60 |
| `qwen/qwen3.5-27b` | Several independent ZDR providers give genuine failover | Multiple | about $0.26 / $2.60 |

Do not choose a model from public leaderboards alone. Blab combines language
detection, translation, grammar correction, interface-language rendering, and
strict JSON in one call. The winner must be measured on that exact contract.

## Evaluation set

Build a versioned, anonymized set of at least 200 messages, balanced across
English, Ukrainian, German, and Spanish. Include:

- Correct messages written in the learner's target language.
- Clear grammar errors that should receive a minimal correction.
- Informal but valid chat language that must not be corrected.
- Messages written in the interface language or an unexpected third language.
- Names, emoji, URLs, abbreviations, slang, punctuation, and code switching.
- Keyboard-adjacent typos and very short ambiguous messages.
- Long messages up to Blab's 2,000-character limit.

Use human-reviewed expected behavior for source language, mode, meaning, and
whether a correction is justified. Keep real production message text out of
the evaluation unless the user explicitly consented and it is anonymized.

## Scoring

Treat these as release gates rather than one blended benchmark score:

1. Contract success: at least 99.5% valid responses after the existing retry.
2. Meaning preservation: bilingual reviewers rate translations blind to model.
3. False corrections: under 1% for valid informal target-language messages.
4. Correction quality: minimal, grammatical, and meaning-preserving changes.
5. Language detection: correct mode and source-language handling.
6. Reliability: provider error rate plus p50 and p95 end-to-end latency.
7. Cost: actual prompt, completion, retry, and repair-call cost per 1,000
   uncached messages.
8. Privacy and resilience: eligible ZDR endpoints, regions, and independent
   providers available for the exact model.

Contract checks can be automated. Translation and correction quality require
blind bilingual human review; an LLM judge may assist but must not be the only
grader.

## Rollout rule

Promote a candidate only if it passes every quality gate, improves either p95
latency, provider resilience, or total cost, and introduces no privacy-policy
gap. Pin a dated model version where OpenRouter exposes one, include the model
and prompt version in the translation cache identity, then canary the model on
5% of uncached requests before increasing traffic. Cached translations should
not be regenerated merely because the default model changes.

Re-run the evaluation before changing a model or prompt and quarterly because
OpenRouter endpoint availability and model aliases can change.

## Sources

- [OpenRouter provider routing](https://openrouter.ai/docs/guides/routing/provider-selection)
- [OpenRouter Zero Data Retention](https://openrouter.ai/docs/guides/features/zdr)
- [OpenRouter data collection](https://openrouter.ai/docs/guides/privacy/data-collection)
- [Gemini 3.1 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite)
- [GPT-4.1 mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini)
- [OpenAI model-version guidance](https://platform.openai.com/docs/api-reference/backward-compatibility)
