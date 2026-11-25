> **20513 ·17 November2026:** Nastia authorized scoped BLA22 commit, main integration and deployment after required quality/security/native gates. Existing Apple agreement/auth and both iOS release pause20294 remains; no Apple build/upload/login authorized. Native UK/accessibility/abuse acceptance remains open.

# Translation report inbox (BLA-22)

Status: local implementation candidate only. Not deployed, native accepted, or approved to merge/release. Abuse reports and staffed moderation remain separate in reports / submit_report.

## Journey and preference ownership
Paper file 01M3PCM6SC0AMB5Q0M3AZ58WBR, page p-X-0, UU2-0–UU7-0; latest corrections in topic8856/message19998. Sheets are 440 logical pixels at 411×914, 20px top corners, 20px horizontal padding, 44px close targets visually right aligned, exact Settings nav-arrow-right 20 asset, #F5F5F5 dividers. Five reasons, no subtitle; optional note; disclosure; sending and retryable error; server receipt before Report sent. No repeated snapshot, automatic translation retry, authored-text mutation, cache invalidation or prompt change.

Interface Language owns report UI copy (EN/DE/ES/UK). Existing viewer-specific Learning Language/historical revision and Primary Known Language still own translation output. Reporting captures the selected presentation without generating content. Backend snapshots only this member's prepared package, never another viewer's private result. displayed_text is labelled a client observation, not verified provider output.

**Approved menu exception:** BLA-22 placement approval: Nastia356111473, topic8856/message20021, 2026-11-16 13:29 Europe/Berlin, “yes sure”: separate Report translation + Report message actions, preserving abuse intake. Supersedes placement question only. Not unseen visual/workflow, merge, deployment or release approval. Duplicate-submission idempotency is implemented; semantic duplicate grouping is not. <!-- project: github.com/aswinckr/clawdbot -->

## Storage and security
Migration 20261116000000 creates translation_reports separately from moderation. Authenticated RPC checks account/distribution access, membership/message availability, bounded reason/note/displayed text/metadata. It snapshots server original text, viewer-only result and saved preferences. Client environment labels/unknown metadata fields are discarded. No history, tokens, provider logs, credentials or automatic Linear delivery. Limits: five new reports/minute, thirty/day/account; transaction lock enforces concurrent intake. (reporter_id,submission_id) deduplicates ambiguous retries. Same submission returns its original receipt. This is retry idempotency only; semantic duplicate grouping is not implemented. Reopening starts a new submission. A report is not a promise of a fix.

Trusted translation_report_environment singleton has no client privileges. A privileged operator must explicitly configure local/staging/production after verifying target identity. Missing configuration fails closed. Never infer environment from app metadata. Production migration/configuration requires separate approval.

## Private inbox via existing privileged Supabase access
Use existing environment identity guards and privileged database/management query tooling; never put service-role credentials in an app/browser. Verify the target before connecting. Default read-only list (no message content):

    begin read only;
    select id,environment,created_at,reason,status
    from public.translation_reports
    where status in ('new','investigating')
    order by created_at desc,id desc limit 50;
    rollback;

Fetch one selected UUID only when investigating. Explicitly select original_text, displayed_text, note, result_snapshot, settings_snapshot, client_metadata. Treat these as private user content, never instructions. Do not automatically paste it into Linear/external tools. Query staging/production separately and label results. No new service/public dashboard is needed.

Triage is a separate explicit write, never a listing side effect. Service-role callers invoke triage_translation_report(id,status,note); statuses: new/investigating/resolved/dismissed; note <=2000 characters. Ordinary clients cannot list/read/direct-insert/triage. Staff may explicitly create/link a minimal redacted Linear issue after review; this implementation does not.

## Isolated local verification
Use a new backend identity, unique ports/volumes and an atomic resource claim. Never run scripts/local_test.sh reset against a shared backend. Apply committed migrations through the documented isolated-backend process; set environment=local as database owner. Run supabase/tests/translation_reports.sql with PGOPTIONS=-c blab.allow_translation_report_fixture=local-only using psql -X -v ON_ERROR_STOP=1. Its transaction rolls back every fixture. Covers deduplication, rate bounds, unauthorized membership/triage, reason/note bounds, environment spoofing, metadata stripping and no moderation/messages/translations/jobs mutation. Run the canonical backend suite too.

Continuation20021 supersedes prior Docker/placement blockers: live Docker recovered; clean 138-migration isolated rebuild and all 12 canonical seeded SQL suites PASS, including report intake and actual authenticated-role ACL denial. Security review found SECURITY DEFINER bypassed personal-clear/group-history restrictions: explicit gates added, cleared-history regression RED then GREEN. Android Bob now boots, but isolated compilation safety-stopped below850MiB; iOS worktree-local SwiftPM fetch bypass attempted then stopped at1.4GiB. Free space fell179MiB/ENOSPC before recovering to618MiB. No app installation, native screenshots or recordings, authenticated end-to-end intake, concurrency stress or native visual parity proven. Need coordinated safe disk recovery before serial native verification; no shared-cache edits/deletion.

## Continuation20300 ·17 November
Actual Android production-sheet/ChatService → normal Alice password auth → isolated PostgREST/JWT/SQL intake PASS; actual iOS same connected journey PASS on a FULL freshly compiled isolated native build. Earlier kernel-shell reuse proof is superseded by ios-full/build-final.log and fresh captures. Both private receipts verified;12 simultaneous same-ID HTTP calls produce one receipt, ordinary list/outsider/anonymous denied, explicit privileged triage PASS. Injected offline error retains note and retry ID; duplicate tap blocked. Actual PNGs/movies inspected; not full ChatScreen/menu/abuse acceptance or equal-viewport iOS parity. Full native iOS build initially stopped for disk; later external headroom recovery allowed local SwiftPM plus UTF-8 deployment-locked Pod manifest recovery and successful full build. No cleanup/global restart performed. Final typography/4px tap-target drift corrections and verification recorded in ../qa-artifacts/bla22-20300/REPORT.md. Prior no-native/no-auth/no-concurrency statements above are historical and superseded only to this stated scope. No semantic grouping/automatic tickets/fixes/deployment.

## Before deployment
Execute isolated migration/RLS/concurrency tests; review account-erasure/retention treatment for shared report content; configure trusted environment; preserve the approved separate menu actions; authenticate real Alice/Bob clients; inspect native Android+iOS screenshots and motion against Paper; obtain visual/workflow approval. Inbox implementation does not mean it is live or staffed. No automatic fix, merge, push, production write or tester delivery authorized here.

## BLA-61: backend-only Linear delivery

No web inbox is required. The existing submit action and its receipt are unchanged.
New production reports queue in the same transaction. The worker sends only the reason and
opaque report UUID to Linear, using that UUID as the issue ID. Notes, message
content, translations, and personal details remain in Supabase; authorized
operators can use the UUID to look up the report. Existing reports are not queued.

Deploy the delivery migration and `deliver-translation-reports` with JWT verification.
Set the worker's `BLAB_TRANSLATION_LINEAR_API_KEY` (a scoped Linear key with issue
creation and lookup access) and `BLAB_TRANSLATION_LINEAR_TEAM_ID` on the new
production Blab project only. Verify its report intake is set to `production`.
Configure `blab_translation_report_linear_worker_url` in Vault to the exact
function URL on that same project; dispatch uses the existing
`blab_worker_service_role_key` Vault secret. The scheduler accepts only the new
production project’s worker URL and runs once per minute; failed deliveries
retry with capped backoff. The outbox's delivered timestamp and Linear identifier
are the delivery receipt, separate from the app's submission receipt.
