# Reusable personal invitation review

Base: fe2cbca, dedicated fix/reusable-personal-invites-20261016 worktree.
Owner requests unlimited recipients per unique personal link, explicit regeneration.

- Backend: create returns stable token. Legacy unclaimed links reusable; claimed legacy links not reactivated. Regeneration revokes every owner link under advisory lock; retries with original revoked token return current link. Claim uses same lock, retains pair uniqueness, memberships/preferences/blocks. Test/public namespace and tester access unchanged.
- UI: no automatic rotation on sharing. Inline Regenerate below explanatory helper, offline/in-flight disabled. Failed rotation disables sharing pending authoritative refresh. Four interface locales translated.
- Automated:13 focused tests;959 full passed/15 skipped; analyze clean. Rollback database test script passes, including two recipients, repeated claims, nonowner/self rejection, old-link rejection, same-token regeneration retries, block and language retention.
- Native: emulator5564 actual Flutter NewChatScreen with a fake invite service (synthetic token replacement), not a live backend call. Screenshots use realistic32-character random-ID-shaped values. Database behavior is independently verified in a local rollback transaction; hosted migration and live two-client journey not yet verified.
- Not merged/released. Owner approval required for new UI and exact production migration scope. Version27 from preceding task is already distributed independently.

Final owner preview:01-personal-link.png and02-regenerated.png visually inspected. Final native test passed with realistic32-character IDs. Final analyzer result retained in/tmp/blab-invite-analyze-final2.log.
