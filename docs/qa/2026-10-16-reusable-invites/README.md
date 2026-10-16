# Reusable personal invitation review

Base: fe2cbca, dedicated fix/reusable-personal-invites-20261016 worktree.
Owner requests unlimited recipients per unique personal link, explicit regeneration.

- Backend: create returns stable token. Legacy unclaimed links reusable; claimed legacy links not reactivated. Regeneration revokes every owner link under advisory lock; retries with original revoked token return current link. Claim uses same lock, retains pair uniqueness, memberships/preferences/blocks. Test/public namespace and tester access unchanged.
- UI: no automatic rotation on sharing. Inline Regenerate below explanatory helper, offline/in-flight disabled. Failed rotation disables sharing pending authoritative refresh. Four interface locales translated.
- Automated:13 focused tests;959 full passed/15 skipped; analyze clean. Rollback database test script passes, including two recipients, repeated claims, nonowner/self rejection, old-link rejection, same-token regeneration retries, block and language retention.
- Native: emulator5564 actual Flutter NewChatScreen with a fake invite service (synthetic token replacement), not a live backend call. Screenshots use realistic32-character random-ID-shaped values. Database behavior is independently verified in a local rollback transaction; hosted migration and live two-client journey not yet verified.
- Not merged/released. Owner approval required for new UI and exact production migration scope. Version27 from preceding task is already distributed independently.

Final owner preview:01-personal-link.png and02-regenerated.png visually inspected. Final native test passed with realistic32-character IDs. Final analyzer result retained in/tmp/blab-invite-analyze-final2.log.


## Approved release verification (28)

Owner13441 approved the shown screenshots and exact Android/iOS test+production scope. UI integrated at9189e8c. Signed Android27→28 upgrades preserve German settings on reconstructed signed-out emulator baselines; Firebase download-back hashes match. Both iOS28 archives uploaded and Apple processing is VALID. Distribution remains pending final gates.

The first clean backend run caught missing invite-claimed outbox events because reusable links no longer update used_at. Corrected atca9f8a3: explicit event keyed by link plus recipient, so multiple recipients notify independently and repeated claims deduplicate. Rollback SQL now asserts two events after Bob/Carol/repeated-Bob claims. Corrected migration dry-runs pass on both hosted environments without committing. Client/platform sources unchanged from9189e8c, so signed app artifacts remain valid for this backend-only correction.

Evidence boundaries: native owner interaction uses a fake invite service; SQL and clean client-service integration separately cover backend behavior. Physical-device recipient-to-owner messaging and actual push delivery are not claimed verified. Receipts/artifact hashes:../releases/20261016-invites-28/ (workspace project parent).


Final release: all three CI gates pass atca9f8a3 ([run38887856140](https://github.com/nastiaez/Blab/actions/runs/38887856140)); backend integration11 passed/3 provider-dependent tests skipped. Migration20261016000003 applied to test and production,103 ledger entries each; all four installed function bodies exactly match the migration. Test channel remains test; production remains public. Android28 distributed to9 test and2 public existing testers; release IDs6e5o0mc98do58/44f9vpnq7oifo and download-back SHA proofs retained. iOS28 test Owner testing+Invited friends IN_BETA_TESTING, production Owner testing IN_BETA_TESTING. No public App Store/Play submission. Final receipt at /Users/aswin/clawd/projects/blab/releases/20261016-invites-28/release-receipt.json.
