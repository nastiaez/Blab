# Names / terminal tag retries — released17616

This final receipt supersedes the historical candidate gates below.

## Authorization and integrated source
Nastia17616 explicitly requested backend deployment plus the reviewed chooser app update, after screenshots17560–17563/video17564. Mixed-language translation remains excluded per17575. Runtime04d2173fdac01aa7a66dfe3e5a26a091f34d7d2a fast-forward merged/pushed to main; existing header/links retained. Fresh integrated checkout ../blab-names-release-17616 used for Android verification/build. No unrelated runtime changes.

## Checks
- Exact-source CI41539031109 passed Quality, disposable Supabase integration and Android release compile: https://github.com/nastiaez/Blab/actions/runs/41539031109 . Combined243 backend and67 focused app checks pass; analysis clean.
- Real transactional SQL proves terminal failure persistence, no automatic reclaim, explicit per-viewer Retry and retained completed history. Initial test-column typo corrected before passing.
- Current worker + local database + live provider:4messages/8independent outputs pass; canonical authenticated cache reads stable, fixtures cleaned. Local fixture setup used SQL because existing service-role table writes are revoked; no permissions changed. Older local schema was not relied on as clean-build evidence; CI rebuilt current migrations.

## Backend rollout
translate-message and prepare-message-jobs deployed to staging, live checked, then production. Both pre/postflight manifests pass;17/17 downloaded source files in each match integrated runtime. Each hosted environment passed4synthetic messages/8independent viewer outputs for hi ashwin, selected @Alex, typed @aswinckr, and participant-form alternatives. German/Ukrainian learning and English/French known languages resolved independently. Fresh and repeated cached reads pass; all synthetic users/chats cleaned.50 preexisting production translation hashes unchanged; unauthorized calls return401. No migrations, history deletion, provider switch or mixed-language experiments deployed.

## Android delivery
- Integrated native own/partner choose→Change→clear journey and en/de/es/uk at100/200% pass in1m25s. All18 actual screenshots inspected; no material difference from accepted chooser. This is a synthetic fixture with in-memory form preferences, not native two-account/live-provider proof. Existing large-message typography is not a general accessibility audit.
- Signed Blab-test1.0.0(50), package blab.nastia.ez.test, exact runtime04d2173. Certificate SHA2561a18ccd503847eb3eda9f423405ef46740424bc32bb850f1795a9922b27c0ffb. APK SHA25683dd8a566fbb0f742c4cc758a02a45283c30cfe760624f1afc92c9d14bbc9b74.
- Existing emulator5584 replaced49→50 without uninstall/reset;5 settled preference hashes and firstInstallTime retained. Cold launch/PID/version and same existing English Welcome inspected. No signed-in account/history baseline existed; do not infer that stronger retention proof.
- Firebase Blab-test app1:1084218779858:android:82904f8d21106e4911250b, release031lq0q1hjov8 distributed to unchanged13 testers. Exact release reopened; audience matches49,4accepted/0tester downloads at readback. Admin download-back bytes match verified APK. No custom release notes or separate tester message.
- Only staging test/android notice49→50 activated/read back; destination and other3 rows unchanged.4 focused notice tests pass. Existing Firebase console used; initial upload outside allowed inbound directory rejected before upload, corrected staging path used. Clipboard link read timed out; no copied-link verification claimed.

## Boundaries and evidence
No public-store, public-flavor, iOS/TestFlight or physical-device delivery claimed. Mixed-language bug deferred. Earlier dirty worktrees preserved; no database/image/AVD deletion. Native temporary build configuration restored byte-for-byte; ignored configs/signing references retained. Runtime evidence ../qa-runtime/names-tags-17616/, private release receipt ../releases/20261102-names-tags-17616/delivery-receipt.json. Actual downloaded artifact retained; local/remote main synchronization and resource release recorded in shared queue.

---
## Historical candidate record (superseded)

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
