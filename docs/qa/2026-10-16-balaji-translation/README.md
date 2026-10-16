# Balaji chat translation investigation — 16 October 2026

Owner13356: hold the pending Google handoff release; investigate the two failed
translations, then combine the fixes. Nothing released during this investigation.

## Observed incident

Test project tpfksdljkfnenjfdbane, requested chat55916ec3-a7b6-4cac-b237-3810f446c0d2.
- a05ed931-e06f-41fd-aa03-479307cee5fb,07:45:58 UTC: English typing-typo message.
- 90eaf76a-587b-4a3a-ba9e-614da0af5db7,07:46:45 UTC: German Duolingo message.
Each has two failed viewer jobs,4 attempts,phase sentence,last_error=batch_commit_failed.
Both viewers learn German; Primary Known Language is English for one and German
for the other. These are saved preferences, not product defaults. Interface
Language is not used for the translation output lane.

Worker accepts provider output then calls complete_translation_message_batch.
It collapsed every RPC error into batch_commit_failed. Batch writes are atomic:
one rejected viewer rolls back both results. Original responses were not retained.
Management logs APIs returned403 using the stored Management credential. Do not
claim an original exact rejected field was recovered.

## Reproduction

Fresh model calls for each reported sentence use the current deployed two-rule
parser and configured project provider. No conversation context supplied: this
is a fresh reproduction, NOT a recording of the original generation.

English response includes a German translation plus an optional English
explanation correcting tyoing to typing, while mode=translation. The old database
complete_message_translation_job rejects ANY explanation in translation mode.
Thus the supposedly removed strict acceptance policy still exists in SQL.

German fresh response is well-formed correction metadata. Do NOT attribute its
original failure to missing metadata without a recorded original response.

before/after-fresh-model-probe.log record actual fresh model responses submitted
to the hosted TEST save functions inside deliberately aborted transactions.
before/after-rollback-probe.log separately use SYNTHETIC payloads to demonstrate
both optional-explanation rejection and missing-correction-metadata rejection.
Synthetic failure cases are not evidence of the exact original German payload.
All transaction mutations, including temporary function replacements, rolled
back. Readback confirmed original4 jobs still failed/attempts4 and no chat repair
was silently committed.

## Candidate

Migration20261016000002 aligns readable publication, direct completion and worker
completion with loose structure/nonempty sentences. Optional malformed metadata
is normalized/omitted; no content-equality/source-mode/correction-detail rejection.
Membership, active account, selected target/known language, source hash, language
revision, cache contract, role and lease guards remain. No quota increase, no
retry reset and no broad cache flush.

Worker now records allowlisted rejecting stage or SQLSTATE without raw database
row text.12 focused Deno checks pass. Hosted rollback-only helper tests pass for
nonempty/type rejection, optional defaults and private helper permissions.
The isolated-fixture full SQL script did not pass on hosted test(stale_readable);
that test requires local seeded auth/test-access configuration and is NOT marked
passed. Docker/local DB tooling was unresponsive during this run. Full isolated
SQL regression and end-to-end UI proof remain outstanding. The test fixture
transaction aborted; no fixture rows were retained.

The root workspace diagnostic provider key returned402; the configured Blab
project key succeeded for both calls. This is not evidence the incident had a
billing cause. Do not change credentials/billing or expose keys.

## Release boundary

Candidate only, no merge/deploy. Combine with Google handoff and previously
approved retry journey after remaining integrated verification. Original German
failure's exact rejected field is unknown because original payload/error detail
was discarded. Live chat recovery and physical iPhone sign-in remain unverified.

## Owner13365 follow-up

Owner authorized the proposed durable fix and asked whether an app release is
required. Server-only changes do not require an Android/iOS binary; Google
handoff/explicit client Retry remain separate binary changes.

Combined candidate now includes the already approved two-rule parser from
5a85121, per-viewer partial output acceptance and independent per-viewer save
transactions. Shared generation still makes one provider call. Missing output
fails only its viewer; a failed save cannot roll back another completed viewer.
Existing bounded job retry limits remain. No new UI/copy/provider rules.
198 backend tests pass, including partial response survival, save failure
isolation, transport failure isolation and missing-result RPC exclusion. Current
local Docker probe still times out after8 seconds; full local database/integrated
verification remains outstanding. Nothing deployed in this follow-up.

Owner13370: restore local environment and launch Google sign-in too. Docker
backend stopped answering internal IPC around07:42 UTC; normal desktop restart
and quit/TERM did not finish the stuck backend. Restarted that process without
removing volumes. Docker responds again; both existing Blab database containers
are available. Removed only586MiB of this task's generated simulator output.
Disk pressure observed(~1GiB free) but not proven as the hang cause.
Candidate storage SQL test now PASSES on local Blab_Stream_Clean database:
lease fencing, optional metadata acceptance, structure/nonempty rejection,
normalization/helper permissions. Fixture transaction rolls back.
