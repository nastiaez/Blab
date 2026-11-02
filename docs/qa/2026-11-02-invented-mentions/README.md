# Invented mentions · request17217

Status: committed, merged into main and deployed to staging + production under explicit approval17234. Runtime revision b7c5983; base a7b0e29. Both translation functions deployed; no app distribution, schema change or existing-message repair.

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
224 backend tests pass, 0 fail; full standard CI Deno translation/preparation packet. Exact two incident strings rejected in provider-response pipeline, one request each, with independent de/en and uk/fr viewer contracts. Selected/unselected effective prompt coverage; ordinary authored handles/emails/names; identity reorder, duplicate/lost identities; optional corruption; Tamil boundaries; pending artifact bypass and historical retention. git diff --check passes. The initial 224-test packet uses mocked provider responses. Subsequent hosted live-generation verification is recorded below.

## Deployment and verification · approval17234
- Conflict review: fetched origin/main a7b0e29; no branch conflict. Before deployment all 17 downloaded source files in each environment matched that base, so no other hosted patch was overwritten.
- Runtime commit b7c5983 pushed, tested in staging, fast-forwarded to main and pushed; exact same runtime deployed to production. Scope: translate-message and prepare-message-jobs only. JWT verification retained on both functions.
- Clean disposable backend CI passed: https://github.com/nastiaez/Blab/actions/runs/41459086414 (backend-only dispatch; unrelated Flutter quality/Android compilation were skipped, not claimed passed).
- Hosted staging: Working ash, Was machst du, selected Hello @Alex, typed Hello @aswinckr. Each verified for independent German/English and Ukrainian/French viewer settings: 8 outputs plus repeat cache reads. No invented tags; selected/typed labels preserved. Temporary QA accounts/chat/messages cleaned up successfully. See staging-smoke.json. This is live backend/API verification, not physical-device UI review or a statistical guarantee about model quality.
- Before/after deployment manifests pass in both environments: region, migrations, functions, JWT and required secret names.
- Downloaded source after deployment: all 17 files byte-match integrated runtime in EACH environment. Hash receipt retained outside Git under shared releases/20261102-mentions-17234/deployed-source-hashes.json.
- Production read-only verification: 50 sampled historical translation rows retain identical hashes; both unauthenticated endpoints return401. No production messages generated or repaired for testing. Staging live behavior plus exact production source/config verification establishes deployed scope without modifying real chats.
- Existing application/deployment credentials consumed privately; no new credentials, audiences, tester sends, app packages or in-app notices.

Historical bad translations remain unchanged. Physical-device owner acceptance and the separate mixed-language issue are not claimed complete. No manual tracker checkbox changed.
