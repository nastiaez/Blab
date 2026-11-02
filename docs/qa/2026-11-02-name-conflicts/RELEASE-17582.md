# Combined name fidelity and terminal tag retry verification — 17582

## Scope
Nastia17582 requests finishing existing name/tag fixes for deployment and release. Names/chooser implementation is recovered, not rebuilt. Terminal retry implementation is ported from preserved17316 without its superseded name-based prompt. Mixed-language experiments remain excluded per17575. Existing main header/links remain intact.

## Evidence
- Combined backend:243 passed,0failed (`/tmp/blab17582-backend.log`).
- Focused Flutter:67 passed (`/tmp/blab17582-focused.log`); analysis clean.
- Existing actual Android chooser screenshots17560–17563/video17564 remain the reviewed candidate; no UI changes in this combination.
- Recovered stopped Docker engine without deleting volumes, databases or images. Existing restart-policy services resumed; other task resources preserved.
- Transactional SQL check against existing BlabMentions16592 database passes atomic grouping, stale fencing, both readable outputs, terminal failure persistence, no automatic reclaim, explicit per-viewer Retry, and retained completed history. Transaction rolled back all fixtures and queue changes. Test initially referred to nonexistent translation_text; corrected assertion to result.translation before passing. Existing database lacks latest language migration; clean current-schema CI remains required.

## Outstanding
Full exact-source CI, live current-provider/two-viewer verification, explicit chooser acceptance/main integration, exact-scope hosted rollout approval, signed integrated Android verification and tester delivery. No commit/deployment/release completion implied by this report. Local SQL is real database evidence, not full live app/two-account evidence. No public-store or iOS delivery inferred.
