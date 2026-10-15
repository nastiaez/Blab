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


## Hosted recovery and signed candidate (15 October, after owner release approval)

Owner12978 approved the revised UI;12986 requested exact launcher name Blab-test;12990 authorized release to all existing testers. Source bf52c17 is integrated/pushed and CI38760697624 passed. Browser restored existing staging tpfksdljkfnenjfdbane; obsolete Keychain request cancelled. Restored30 migrations through July; remaining68 applied atomically through the authenticated Management SQL endpoint after preserving a private pre-upgrade snapshot. All4 existing staging messages preserved. All12 current functions deployed with expected JWT flags. Explicit staging-only worker URL/authority and provider key overrides configured; live synthetic QA pair authenticated, created/claimed test-prefixed invite, sent message and obtained2 ready results,1 attempt each.

Auth site URL now blab-test://auth/callback; reset and email-change allowlist configured; email confirmation disabled to match PRD. Google native audiences added from dedicated Firebase staging project after registering release SHA1/SHA256. Ignored env/staging.json and Firebase config validate. Existing OAuth web-client/secret pair retained as first audience; dedicated native web/Android audiences added.

Signed candidate1.0.0(22), package blab.nastia.ez.test, sourcebf52c17: SHA25631a05536da8afa75f38d84817bbf610d54a163ce004db37fb37cde5d1e38e4cd. Approved signing cert unchanged. Installed fresh on task-owned read-only emulator5560 without replacing public app. Email login succeeds intermittently, but access checks then timed out; direct REST503 and Management connection timeout544 independently reproduce hosted instability. Not a passing signed acceptance result. Staging-only restart initiated through dashboard; recheck required.

Landing source2f11154 pushed to actual nastiaez/blab-landing main and local main synchronized. Five site checks pass. Vercel deployment EPrTgAF6qAdwVAGvrHFMBJ9FoWAs blocked; owner browser login reached required authenticator/passkey prompt. Owner asked to complete it; no workaround or privacy/account change attempted. Live domain association and normal Android link opening not yet verified.

No Firebase upload/distribution. Existing approved roster verified from public release:2 testers, unchanged. Neither has an existing matching staging account; independent signup plus explicit server membership approval still required (do not auto-admit arbitrary signup emails). Only2 short-lived synthetic QA memberships currently enabled. Public backend and installed public app untouched.
