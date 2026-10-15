# v19 same-language persistence hotfix

Incident: Telegram12907 and follow-up LangSmith request.
Cause: cache trigger marked both matching language-pair processing jobs ready after the first viewer completion. Second viewer failed stale_batch; transaction rolled back. Local asymmetric-language checks missed this case.

Evidence: production LangSmith outputs existed; four messages/two viewers each failed four attempts with batch_commit_failed. One-viewer rollback replay succeeded, same-pair replay failed stale_batch. New local same-pair SQL regression red/green; candidate migration plus exact failed job/payload replay succeeded in a rollback-only production transaction.165 backend tests pass. SQL regression added to CI.

Fix: transaction-scoped trigger guard leaves processing leases to their own batch writer; ordinary legacy notifications unaffected. No translation rules, language preferences, interface, app signing or mobile version changed.

Released server-side migration20261015000002 from3e80314. Controlled repair requeued only the8 known failed jobs, granting one extra attempt by setting attempts4→3. Previous four failed attempts are recorded here; no request/character quota changed. Recovery succeeded:8 ready jobs,8 readable results. LangSmith4 completion records at12:58:17–19UTC with no errors, one per affected message. Not proof of the owners' current screen; request physical confirmation.
