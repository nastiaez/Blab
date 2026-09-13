# Translation Failure Recovery Design

## Goal

Fix the remaining failures found in the Alice-browser/Bob-Android translation QA: preserve valid translations when the optional grammatical-form audit is unavailable, make local delivery preparation run after every reset, replace stale client errors with later server results, and use one concise unsupported-language message.

This follow-up supersedes the unsupported-language copy in `2026-09-12-translation-edge-cases-design.md`. The previously approved short-message, abbreviation/name, and future-only tone behavior remains unchanged.

## Valid translation versus optional form audit

The base translation is the primary result. A grammatical-form audit may enrich it with feminine/masculine alternatives, but an unavailable audit must not turn a valid translation into `Couldn’t translate`.

- A valid audit that finds a real form choice still supplies the alternatives.
- A valid audit that finds no choice keeps the base translation.
- A provider/network/parse failure in the audit keeps the base translation without alternatives.
- A malformed audit that claims a choice but cannot produce a valid complete alternative remains rejected, because applying it could corrupt the sentence.

This lets ordinary German sentences such as `Can you please help me?` and `Are you ready?` remain readable even when the secondary audit is unavailable.

## Delivery preparation worker

The local reset helper must configure the existing worker endpoint and local service credential in the local Vault every time it rebuilds the database. The operation is idempotent and uses values derived from the active local Supabase instance. No provider key, hosted credential, or production secret is written to the repository.

The existing insert trigger and one-minute recovery schedule remain the delivery mechanism. After a reset, a queued preparation job must advance to at least one attempt when the local functions runtime is available.

## Unsupported-language recovery

Deterministic unsupported-script detection remains before provider selection. Clearly unsupported text such as Chinese plus a Latin-script name resolves to `sourceLang=other` without asking the model to guess.

If a bubble already contains a translation error and the server later stores a valid result, a later visibility/rebuild pass rechecks the server cache before keeping the error. A stored result replaces loading or error state, including an unsupported result. This cache repair never launches another provider request by itself, so permanent errors cannot loop.

## Unsupported-language copy

Incoming and outgoing unsupported messages use the same English interface copy:

`Blab doesn’t speak this one yet.`

Nothing follows it. The authored message remains visible, and Retry, Listen, Original, and word-description actions remain unavailable. Other interface locales use concise localized equivalents with the same meaning and no suggested language.

## Verification

Automated coverage must prove:

- audit unavailability preserves a valid base translation;
- valid form-choice audits still apply and malformed required-choice audits still fail;
- a local reset installs both worker Vault entries idempotently;
- a stored unsupported result replaces a prior client error without another provider call;
- both message directions show only `Blab doesn’t speak this one yet.`;
- clearly unsupported scripts continue to bypass provider guessing.

Acceptance testing uses Alice in the browser and Bob on Android. It must show Bob receiving German for both English questions and Chinese-plus-name messages showing the new unsupported copy with no red error or Retry. Screenshots must come from the real clients.
