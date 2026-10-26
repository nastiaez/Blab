# Approved database compatibility integration — 2026-10-26

Approval: owner reply16229 explicitly approved committing and merging the reviewed legacy-chat compatibility and RLS resolver-binding fixes. SQL-only scope; no UI, deployment, distribution or notifications authorized by this step.

Integration base: e3766a24102c1e4296a7ef59466e5d3ee63fed5a (fresh origin/main). Dedicated branch integrate/legacy-rls-16229. Reviewed tracked patch applies byte-identically; no overlapping main database/test changes except a newly integrated iOS migration. Its existing version20261026000002 is preserved: the unchanged policy-rebinding migration is renamed20261026000003. Final migration count is127, not126. This is ordering reconciliation only, not a policy change.

Only approved constraint correction, two follow-up migrations, eight fixture/test corrections and the synthetic compatibility regression are included. The original dirty candidate and all raw QA remain intact. Older group worktree overlaps are preserved, not imported; main already owns its committed group schema. Shared release queue was read only.

Local replay uses only the task-owned Blab_Legacy_Compat_20261026 disposable backend. Raw logs remain untracked alongside this note; no private dumps are committed. No production or staging writes, releases or messages. Four-app rollout and iOS display/auth/notification acceptance remain separate.

## Fresh final-source gates
- Clean127 reset and populated105→127 migration upgrade:55/55 SQL suites each (110/110 total), including current-main iOS contract suite. Both ledgers127/latest20261026000003.
- Legacy both-null row, membership, invite reference and zero-message baseline preserved before/after suites and rollback security checks. Member history readable; outsider/anonymous denied; direct client chat/membership inserts denied; lifecycle update rollback passes.
- Authenticated and service_role private resolver EXECUTE both false; policy binds public group-aware wrapper with all existing predicates retained.
- Synthetic compatibility regression24/24; translation/worker Deno tests211/211; shell syntax and git diff --check pass.
- First runner attempt had a quoting error in baseline assertion after clean55/55; corrected runner repeated both complete paths successfully. No failed run counted as proof.
- Raw receipts retained locally in this directory; only this summary and suite matrices are versioned. No UI/live-provider acceptance claimed.
