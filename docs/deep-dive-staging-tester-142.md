# Staging tester142: default CLOSED

Engineering only. No activation, hosted writes, inference, audience additions, quota grants, production, iOS delivery or main integration performed.

Scope: existing Android Blab-test Firebase audience and matching tpfksdljkfnenjfdbane backend only. Attach ownerAuthorization20637/mainIntegration20687/stagingDeployment20737 plus synthetic cleanup, functional and integrated Android evidence. Previously approved unchanged client inputs require no duplicate approval.

## Gates and test plan

Parent reviews, pushes, owns fresh disposable PostgreSQL rebuild through142 and CI. Existing canonical unscoped quota/cache/retry tests,140 three-slot concurrency and141 original-nonce resume must stay green. New staging_tester_deep_dive.sql is OFFLINE MOCK, not provider proof: distinct e2 UUID/email namespace; transactional external dispatch suppression/rollback; ACL/default closure/exact revision/test policy/pending zero extra charge/revoked eligibility/stale lease/CAS1/QA precedence/deactivation checks. Deno tests verify SQL class routing, no tester QA nonce, no QA operational bypass and unknown-class refusal. SQL execution remains PENDING CI; local Docker/shared794 DB prohibited and untouched.

After fresh CI, synthetic closure and functional/integrated gates, parent deploys matching code/migration and verifies default closure. No agent invokes real-tester inference. Future existing testers self-initiate under existing quotas only.

## Operator SQL (NOT executed)

Privileged PostgreSQL connection to verified tpf only. Substitute actual integrated-release40hex SHA and full proof references:

    BEGIN;
    SELECT blab_staging.activate(
      '<actual-integrated-release-40hex-sha>',
      'ownerAuthorization20637;mainIntegration20687;stagingDeployment20737;QAclosure=<receipt>;functional=<proof>;integratedAndroid=<proof>;CI142=<run>'
    ) AS rollout_id;
    COMMIT;

Record returned rollout_id. Endpoint requires additive NONCREDENTIAL deployment binding BLAB_DEEP_DIVE_RELEASE_REVISION equal to that SHA. Preserve provider/model/key configuration and existing flags. Do NOT change any runtime configuration while current QA cache proof is active. Binding is not a client input or inference allowance.

Deactivate, retaining all audit/quota/cache/QA rows:

    BEGIN;
    SELECT blab_staging.deactivate('<recorded-rollout-uuid>', '<reason and verification receipt, at least16 characters>');
    COMMIT;

Service/client roles cannot authorize/read/CRUD private receipts. Migration seeds no activation. Activation refuses any open QA run.

## Invariants

SQL derives QA FIRST from actor/subject tombstones OR QA message/chat scope. Closed QA never falls through. Original141 nonce/slot CAS unchanged. Non-QA needs active exact staging revision, existing test-channel cohort eligibility and canonical account/context checks. Canonical quota/cache/retry forwarding unchanged:60/min,200/day,100k chars,cache/pending zero charge,failed calls charged,30s explicit retry cooldown,two inflight. No allowance/reset/refund. Ordinary dispatch independently revalidates rollout/current eligibility/full context/processing lease/expiry and unique private audit CAS per lease. Deactivation blocks future authorization, not an already-authorized HTTP request.1600 output/model/provider/key contract unchanged; production mode excluded.
