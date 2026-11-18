> CURRENT2026-11-18: genuine140SQL/security/concurrency and bothfullCIs44276716830/44284311490 ALL3PASS. Staging140/3guards deployed; one realbase generated. Word admission reserved but wrong provider/model refused BEFORE network. Fix83ff094 canonical provider dark-deployedv9. Both flags false/runclosed/2newidentitiesdisabled/all24secretsrestored. No retries authorized/no successful Deep/native cache proof. Historical preparation boundary below is superseded by tasks/progress.md and qa-artifacts/bounded20693/RESULT.md.

# Bounded synthetic QA guard 20693

Local implementation only. No hosted changes, paid requests or DB mutations performed.
No UI/policy prompt/cache contract changes. Viewer A retains its independent learning/known-language preferences; B aids-off is not admitted. Non-QA translation retries/quota semantics remain unchanged; hosted Deep is QA-only even with no open run.

## Operator configuration (privileged SQL only)
Apply migration140 only after disposable PostgreSQL/security/concurrency proof. Deploy exactly prepare-message-jobs, translate-message, deep-dive after verification; no other bundles/secrets.
Bind actual UUIDs using psql variables run,a,b,chat,message,source (source is SHA256 of trimmed authored text). Register actors BEFORE any send. No actor deletion on rollback: tombstones are fail-closed scope.

```sql
begin;
insert into blab_qa.actors values (:'a'::uuid),(:'b'::uuid);
insert into blab_qa.runs(id,project,state) values (:'run'::uuid,'tpfksdljkfnenjfdbane','open');
insert into blab_qa.subjects(actor,run_id,chat_id,message_id,source_hash,base_viewer)
values (:'a',:'run',:'chat',:'message',:'source',true),(:'b',:'run',:'chat',:'message',:'source',false);
insert into blab_qa.slots(run_id,kind,reservation_nano) values
(:'run','base',12000000),(:'run','vocabulary',10000000),(:'run','correction',10000000);
commit;
```

After genuine base ready/eligibility, calculate exact vocabulary/correction enrichmentKey using shipping serializer and actual accepted metadata. Set vocabulary_key and correction_key on A subject only. Never invent accepted data. Deep reservation is called by the canonical claim in the SAME transaction as existing quota/cache claim; reservation exception rolls everything back. Cached/pending responses never consume slots. B cannot reserve. Worker slot binds exact job/lease/source under row locks; dispatch CAS never returns a second grant. Failures close run; no retries/refunds/reallocation. A crash leaves consumed slot forever. Operator must close run on interrupted process (no autonomous watchdog installed).

Final provider JSON includes model/schema/provider fields and is measured in UTF8; QA model must be gpt-6-luna; base2500, Deep1600. No global provider override. Price recheck is an operator preflight, not a live pricing scraper.

Close: UPDATE blab_qa.runs SET state='closed' WHERE id=:'run'; retain every ledger row. Restore false/false flags and all preserved secret fingerprints; revoke only created synthetic sessions. No downmigration/quota reset.
Inspect: SELECT * FROM blab_qa.runs; SELECT * FROM blab_qa.slots ORDER BY kind; compare translation_usage before/after (base0, Deep<=2/+44chars).

## Mandatory remaining verification / known limitations
336 offline Deno tests pass; three entrypoints typecheck. This does NOT prove PostgreSQL execution/concurrency.
Disposable SQL must verify migration compiles with canonical139, ACLs, triggers, parallel same-kind/all-kind CAS, stale lease/nonce/restart, cached/pending quota parity, wrong actor/source/message, closed publication and unchanged unrelated-user behavior. Coordinate lifecycle owner794; no uncoordinated local DB writes.
Review needed before deployment: worker selects only authorized A and terminally denies B; SQL must verify this coupled flow. Reservation happens before request-bound validation and consumes conservatively. Failure triggers close only the admitted base viewer’s run. Expired crashed Deep currently normalizes to failure and closes run. No hosted/paid execution authorized until SQL proof and these workflow details are resolved.

## Local parity and strict hosted entrypoint
Canonical claim preserves original canonical139 quota/cache/retry semantics for unscoped local actors only; registered actors and QA-scoped messages stay budgeted. HostedEnrichment exclusively calls service-only `claim_hosted_qa_deep_dive_enrichment`, which checks the exact open run, subject, source, message, kind and context before the nested atomic canonical claim. Empty policy never admits hosted calls. No fixture GUC bypass exists. Ready-publication fencing applies only to QA-scoped messages. Both hosted/provider activation flags remain false until policy is seeded and verified.

Base dispatch locks the shared run and exact processing job, requiring slot job ID, lease, actor, message and source to match before its one-shot CAS. A different live job or renewed lease cannot spend an old nonce. All caps remain unchanged. SQL role coverage includes every new RPC, revoked unbudgeted helper and trigger helper; genuine fresh PostgreSQL execution remains the parent-owned CI gate. No SQL, Docker or hosted execution performed for this correction.
