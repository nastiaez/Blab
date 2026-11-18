# One-time continuation 20737 (migration141)

No hosted writes, provider calls, activation, main integration or release are part of this implementation. Main remains eb2b7f7. Existing dependency branch is cdeff8f. Read the private original20693 RESULT/ACTIVATION-DECISION before operating.

Operator-only SQL, with original private identifiers and approval20737 evidence supplied as psql variables (never publish identifiers or the receipt):

~~~sql
begin;
select blab_qa.authorize_resume(
 :'run'::uuid, :'actor'::uuid, :'message'::uuid,
 :'source_hash', :'original_vocabulary_context', :'original_unused_word_nonce'::uuid,
 '20737', :'private_approval_receipt');
commit;
~~~

This atomically reopens only an existing closed22m run and inserts one receipt. Requires exact actor/message/chat/source/context/nonce, failed vocabulary cache, dispatched base and ready original job/package, untouched correction. No new base, quota refund/reset, reservation change or nonce allocation. All client/service roles lack authorizer/table access. Repeated authorization fails even after subsequent closure.

Service canonical claim consumes receipt and leases failed word row atomically before normal failed-cache handling. Same unused qaNonce, fresh lease, no quota charge. Parallel claim: one claimed, seven pending. Receipt remains consumed after committed claim even if caller crashes; expiration/failure cannot resume again. Original dispatcher CAS/body limits unchanged. Original cache paths remain uncharged; correction uses original unused grant and normal quota charge. Max additional32m, cumulative79,504,985 nanoUSD.

CI contract: fresh disposable canonical141 backend through existing workflow; existing unscoped integration tests plus synthetic_qa_budget.sql and synthetic_qa_resume.sql, then extended scripts/test_synthetic_qa_budget.py. Keep PASS.json and RESUME-PASS.json plus individual stdout/stderr. Separate df fixture models pre-dispatch failure; existing de fixture already dispatched and is never resumed. All inserted ready packages/payloads are explicitly offline SQL mocks, not provider proof. Snapshots must show22m /1 request/22chars before and after resumed lease; final correction32m /2/44. Parallel word dispatch exactly one true. New failure closes run and denies authorization/retry. Parent owns push/CI dispatch and evidence collection; no PostgreSQL execution claimed locally.
