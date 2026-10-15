# Test invite boundary — investigation

Authorization: topic7420 message12963. Base852987a. No hosted mutations or release.

## Existing boundary

- create_invite requires authenticated active account, not tester membership.
- claim_invite checks active inviter/claimant, used/self/unknown token and serialized pair uniqueness; no test-channel restriction.
- Client shares loveblab.com/i/{token}, handles that path plus legacy blab scheme; pending continuation stores token only.
- Android has one applicationId, custom scheme and verified invite path.
- staging configuration already rejects the approved production project, but current distributed v21 uses production.

## Proposed acceptance matrix, identity decision pending

1. Test build clearly labelled at entry and when sharing; shared copy explicitly identifies a test invitation.
2. Test-to-test valid invite succeeds only for authorized testing participants.
3. Public-to-public path retains existing behavior.
4. Wrong-channel open shows clear correct-app guidance; never creates a connection or consumes invite.
5. Auth/cold start/reconnect retains correct channel and cannot reinterpret a token as another environment.
6. Direct API calls cannot turn display labels or client-supplied channel values into authorization.
7. Ending tester access is server-enforced; existing public accounts and paid access must not be silently disabled.
8. Existing tester history disposition must be explicit, not silently migrated/deleted.

## Pending product decision

Separate Blab Test app with separate accounts/chats versus shared identity with isolated test channel. Asked owner; architecture and migration work paused pending answer. No screen or enforcement implementation claimed.

## Decision and candidate

Owner explicitly chose separate Blab Test accounts/chats and `-test` URLs. Earlier pending choice is resolved. Public source remains852987a; dedicated candidate only. Local runtime /tmp/blab-test-boundary-20261015 owns project Blab_Test_Boundary_20261015, API54721 (54522 was occupied; no existing container stopped). Local seed identities Alice/Bob/Carol only. SQL tests transaction-rolled back. Android5556 was started read-only for this task after adb confirmed no devices.

Backend tests: public unaffected; unapproved Carol cannot claim; Alice creates server-prefixed invite, Bob claims/sends; clients cannot alter policy or self-enrol/bypass namespace wrapper; kill blocks reads/sends/invites; individual expiry works. Run supabase/tests/test_app_boundary.sql with ON_ERROR_STOP. No hosted or physical device proof yet.

## Final verification and owner visual revision

Before visual revision:949 Flutter checks passed (15 existing skips),188 backend checks passed, analysis/format clean. Clean rebuild of task-owned54721 backend applied final migration including all11 restrictive policies; boundary SQL passed and rolled back. Actual two-account cold test invite authenticated/claimed; wrong-direction explicit Android intents rejected; master kill and recovery without restart verified. Recovery caught a retained empty chat-list subscription and fixed it by invalidating when access becomes active. Earlier screenshots12971–12974 are superseded by owner feedback.

Owner then required production-identical normal UI, with only `-test` URL difference. Removed all persistent test chrome, normal-flow test copy and different launcher label. Active gate returns the unchanged child; NewChatScreen differs from main only in URL construction/import. Production titles, helper, share message, sizing and spacing retained. Separate identity/backend and exceptional blocked/mismatch states remain.

Post-revision:31 focused checks pass, analysis clean, Android candidate compiled and installed on5556. Actual invite screen inspected at1080×2400: screenshots/06-invite-production-parity.png. No test banner/extra copy. Source of invite controls exactly matches production. Task-local DB reset cleared prior QA chat only; regenerated approved Alice test invite verified through actual UI. Public services untouched.

Pending: owner approval of revised screenshot; hosted isolated backend/Firebase/auth provisioning, verified domain links/browser landing and integrated signed distribution. No iOS target exists. Explicit activity intent tests are not hosted app-link proof. See operator-runbook.md. Uncommitted candidate on base852987a; not merged or released.
