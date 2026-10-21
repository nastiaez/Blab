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
