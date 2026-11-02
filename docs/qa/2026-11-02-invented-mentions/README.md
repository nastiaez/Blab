# Invented mentions · request17217

Status: implementation candidate, not integrated or deployed. Base current origin/main a7b0e29. No saved messages or hosted services changed.

## Authorized scope
Nastia approved the preceding diagnosis/proposed fix: conditional selected-mention instructions, all-output protection against invented @names (including zero selections), preservation of authored handles and names, mandatory sentence identity exception to permissive readable-output acceptance. No semantic-language checker or mixed-language fix included.

## Preference mapping / consumers
US-015/022/046, FR-23/33/40 retained. Client message_row resolves Practice to historical chat Learning Language, Normal to viewer Primary Known Language; interface language remains chrome-only. Server prepare_translation_viewers independently supplies targetLang/interfaceLang, source identity, revision, form/context/mentions. Aids-off/no_aid_needed and completed cached paths return before generation in both foreground index.ts and single_call_worker.ts. Both new-generation paths consume generateMessageOnce, which restores/validates before results can be committed. Existing correction eligibility, form suggestion, reading-script, per-viewer preference behavior and durable failure retries are unchanged.

## Changes
- Canonical generic policy: never create @handles from names/context; preserve authored handles. Internal selected-handle instructions are included only after source sidecars validate.
- Reused bounded identity-restoration/optional-enrichment handling from the preserved BLA37 candidate, extended to all @identifiers. No unrelated BLA37 language/gender changes ported.
- Validate mandatory learning and known-language sentences with zero or more selected mentions. Reject invented/duplicated/changed/deleted handles, restore selected IDs with trusted offsets; preserve same-name/different-account mentions, Tamil suffixes, ordinary name transliteration and authored email content.
- Invalid optional explanations/tokens/forms are omitted without rejecting valid primary sentences. No additional model check/call or new retry loop.
- PRD acceptance exception and canonical generated rulebook reconciled under request17217.

## Cache
No schema/migration, completed sentence cache invalidation, history rewrite or saved-incident repair. Existing database completion contract minimal-source-anchor-v11 remains intentionally unchanged: its SQL admission contract is not a prompt-version switch. Pending group artifact identity now explicitly includes authored-mentions-v2, in addition to its effective request hash; incompatible artifacts are bypassed without deletion. Existing completed packages remain immutable. No explicit provider cache exists here; stable prompt prefix changed, leaving provider implicit caching to the provider.

## Evidence
224 backend tests pass, 0 fail; full standard CI Deno translation/preparation packet. Exact two incident strings rejected in provider-response pipeline, one request each, with independent de/en and uk/fr viewer contracts. Selected/unselected effective prompt coverage; ordinary authored handles/emails/names; identity reorder, duplicate/lost identities; optional corruption; Tamil boundaries; pending artifact bypass and historical retention. git diff --check passes. Calls use test provider responses, not paid/live Gemini: zero live provider calls.

## Remaining gates
Live provider/staging/new-generation and cache-hit verification, real app acceptance, scoped main integration and explicit production approval. Deployable backend scope is translate-message + prepare-message-jobs, no database migration, client UI change, app distribution or audience change. No claim of a live fix or physical-device verification. Historical bad translations will remain until separately scoped repair is approved.
