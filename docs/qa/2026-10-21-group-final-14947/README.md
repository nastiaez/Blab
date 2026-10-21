# Group feature finalization14947

User14947 explicitly authorized the full proposed sequence: complete journey review, fresh setup and Android verification, integration and Blab-test delivery. This follows actual conversation screenshot14923 and earlier group journey packets; no production rollout or new testers authorized. Existing owner-manual launch checkboxes remain unchecked.

## Candidate

feat/group-conversation-ui-20261021, starting origin/main0f38911 with preserved BLA14 dependency and approved Paper5A5-0 revision14894. Original BLA14 worktree remains preserved. No unrelated pending work is included.

## Verified before integration

- Independent fresh Postgres project Blab_Groups_Final_14947 on59322 applied all122 migration files and seed without ledger repair.15 rollback-only SQL suites pass, including100 members,500-message original-only join, private corrections/variant recovery, owner/lifecycle/media/push/account erasure. Ledger and logs retained locally.
-211 backend tests pass. Previous final client suite1025 passes/16 explicit environment skips, final49 focused checks/analysis clean. No application edits since those final UI checks.
- Combined-source Android setup/create/invite/explicit join, information/rename/owner enforcement/transfer, personal delete/leave/rejoin/removal/old-link fence/final-member closure pass. Setup runs actual authenticated local RPCs through an adapter with controlled invitation-list UI and a placeholder post-join route; actual conversation, roster and lifecycle use real ChatScreen and services in separate tests. Do not call the setup harness alone full signup-to-chat proof.
- Updated information harness mounts GroupInfo above a navigation parent, restoring the actual back affordance; earlier root-only screenshot is superseded.
- No new paid AI sweep: retained real-provider results from14826 demonstrate live translation/correction/privacy. Earlier upload/gallery/offline/private-request/push evidence remains retained for unchanged logic; those are not relabeled new paid/native end-to-end runs here.

## Walkthrough delivery

Inspected native screenshots delivered14962(create),14963(invite),14964(explicit join),14965(approved chat/rejoin translation),14966(information),14967(leave),14969(rejoined history). First/last scenes are separate local QA groups, not one continuous recording. The sample local invite is not usable against hosted data. No tester was contacted by these screenshots.

## Release boundary

Staging currently lacks the17 group migrations. These and the modified worker/translation functions must be promoted to staging before distributing a group-capable test APK. Test project tpfksdljkfnenjfdbane/Firebase blab-staging/package blab.nastia.ez.test only. Production bhzcexhebjszwyqvcsxs is excluded. Hosted SQL/Edge deployment, exact signed update32 from31, Firebase same-nine-tester delivery and artifact readback are not complete yet.


## Final group refinements ·21 October2026

Latest owner screenshot feedback supersedes the earlier two-row Paper header: remove the practicing-language caption and keep identity, mode toggle and menu in one toolbar row. Long titles ellipsize; enlarged text/narrow screens retain a compact icon control with full mode semantics and44px activation height. Group-only;1:1 remains unchanged. Hide the complete Shared media section after a confirmed empty result; retain loading/retry and show it once a photo exists.

Verified on Android5560 and390×867 Web: native conversation and information journeys pass; inspected replacements delivered15001 and15003. Full client1,026 passed/16 environment skips; analysis clean. Fresh122 migrations/15 SQL suites and211 worker checks passed previously on the same backend source. Main group integration68e22be pushed; final refinement integration/test32 delivery pending. Staging17 migrations and2 modified functions promoted without production changes. No new AI generation for these refinements.


## Final integrated test delivery

Source3ef97cf includes group implementation68e22be, reconciled approved practice-entry fix0ea8c7c, and final group refinements9264ca0. Main and origin/main synchronized.96 focused integrated checks pass; native integrated retained-message conversation passes after reconciliation. Final screenshots15001(compact header) and15003(hidden empty media) inspected; Web390×867 matches with no horizontal overflow.

Staging tpfksdljkfnenjfdbane:17 missing migrations promoted in one transaction through Management API after pooler CLI stalled; all122 ledger versions present. Pre-deployment function/policy metadata retained privately. translate-message11 and prepare-message-jobs7 active with JWT verification retained; all15 downloaded TS files match committed source. Hosted rollback-only create/invite/join and lifecycle/history/AI-cutoff suites pass using existing staging accounts; post-counts unchanged17chats/152messages/16profiles. No seed pushed, provider credentials changed, AI generated, or production action.

One combined Blab-test33 distributed through Firebase blab-staging to exact existing-nine audience (reopened/verified); no duplicate32 delivery. Release2fk1kqt3uhgoo. Tested and native-browser-downloaded APK SHA256570e493119feafa644bc3dffd244ccb0ec836a18c1515585f50e10da44799a4a matches byte-for-byte. Same release signer1a18ccd503847eb3eda9f423405ef46740424bc32bb850f1795a9922b27c0ffb.5560 signed install31→32→33 retains firstInstallTime and DE preference; cold launches pass. Three accepted/zero downloaded observed at distribution is not owner phone acceptance. Private artifact/receipt outsideGit: ../releases/20261021-groups-combined33/.

Production and in-app update notice unchanged. Group manual acceptance boxes remain open until the owners try this version on phones. Disposable122-migration QA database stopped with volume backup retained; original group data preserved.
