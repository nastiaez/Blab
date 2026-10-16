# Google return / silent sign-in handoff — 16 October 2026

Owner13339 requested root-cause diagnosis/fix for test and production; corrected
address supplied in the same topic. Follow-up confirms iPhone, no error, returned
to sign-in after Google. Source: dedicated current-main worktree at34b2f67.

## Evidence and boundary

Read-only test SQL confirms the reported account was created07:26:34 UTC,
last signed in07:26:48 UTC, verified and approved for distribution access. Its
profile remains onboarding intro/version0. No account or access mutation made.
This establishes successful authentication, not complete app onboarding.

TestAccessGate replaced its entire child (the MaterialApp router) whenever
access was rechecked, including on native app resume and authentication identity
change. That disposes the sign-in route while its async provider callback is
pending. The continuation either finds an unmounted context or uses a disposed
WidgetRef; returning to the remounted auth page has no automatic signed-in
redirect. Restart enters bootstrap with the persisted valid session instead.

A deterministic lifecycle regression fails on original code: the active sign-in
owner is unmounted during a pending resume access request. Fixed code preserves
it. Access checks still hide the app while unresolved, denied, revoked or offline;
focus, pointer interaction and accessibility for hidden content are excluded.
Server authorization remains unchanged.

## Scope

Only the test access gate changes. Production does not instantiate this gate;
there is no evidence this exact bug affects the public channel. The shared
Google→Supabase→onboarding acknowledgement→Confirm name route passes in both
compile-time channels using synthetic provider/HTTP transport. No provider
configuration, auth/session weakening, access bypass or layout/copy change.
Interface Language and profile setup preferences remain unchanged.

## Verification

- Original gate: resume-preserves-owner regression fails; existing6 checks pass.
- Candidate:8 focused test-channel checks pass (gate7 and real app/router handoff1).
- Public-channel real app/router handoff:1 passes.
- Analyzer: clean.
- Full Flutter suite:953 passed,15 existing skips; no failures.
- Native iPhone simulator injected Google-return journey passes for both staging/test and production/public configurations. Both final screenshots inspected. Staging screenshot delivered in topic message13353; production shows the same Confirm name destination. This is not hosted OAuth or physical Google-picker proof.
- Native simulator first attempt failed due ENOSPC, before app launch. Removed
  only this attempt's generated iOS output; retried with copy-on-write cached
  dependencies. No personal files, archives or signed release artifacts removed.
- Synthetic Google return is injected at the social-action boundary; actual
  Supabase SDK token exchange/events and real app router run. This is not proof
  of a physical Google account picker, actual Google credentials or hosted OAuth.

Owner screenshots/review, main integration and test/public delivery pending.
The previously approved retry-client release13332 remains separate and pending;
its test backend protection is already deployed. No production changes deployed.

Production preparation initially lacked its ignored plist in main; stopped that run and prepared from the existing iOS signing worktree configuration. No provider or hosted configuration was changed. Final production native run passes.

## Integrated release verification, 16 October

Owner13370 authorized launch. Integrated runtime7b36dab passes native Android
Google return in staging/public configurations and the retry-ownership journey.
955 Flutter checks pass,15 skips; analyzer clean.71dba94 changes only integration
test fixtures (manual completion must not compete with background queued jobs).
Signed Android26 test/public and iOS26 test/public artifacts are retained under
../releases/20261016-recovery-26 relative to the project container. Exact
artifact hashes and limits are in its artifacts.json and receipt.json.
iOS generated Swift package reset its platform to13.0; corrected the generated
manifest to the existing project minimum15.0 before native archive. Both native
identity guards pass and both Apple uploads process as VALID. No tracked iOS
configuration change or minimum-platform increase was introduced.
Android staged download-back matches both signed files. Test25→26 preserves
German on reconstructed signed-out baseline; public21→26 preserves German but
uses the newer onboarding introduced after21. No authenticated-history or
physical-device Google picker acceptance claimed. Final CI/distribution pending.

- Final fixture-only revision cafe860 uses the disposable local database test
  connection for queue cleanup; application table permissions remain unchanged.
  Focused translation-security and message-replies integration checks pass on
  the recovered local service. Local test-boundary Carol fixture needed test
  membership; first cold realtime attempt timed out, warm rerun passed. Final
  clean CI: https://github.com/nastiaez/Blab/actions/runs/38875756223 (pending).

## Release completed — 16 October 2026

Owner13370 authorizes launch; screenshots13353 and retry13327/13328 reviewed.
Clean CI cafe860 passes all three jobs (quality, Android release compilation,
local backend integration): https://github.com/nastiaez/Blab/actions/runs/38875756223.
Version26 distributed through existing Firebase channels: test8 / public2 testers,
release-specific invited counts verified; both download-back hashes match.
iOS26 assigned to existing groups. Test internal and external IN_BETA_TESTING;
Apple beta review APPROVED. Public existing internal Owner testing IN_BETA_TESTING.
No App Store publication or replacement/expiration of prior TestFlight builds.
Test translation backend deployed and both incident messages recovered for both
viewers with one controlled extra attempt each. Production backend unchanged.
Physical-device Google sign-in and owner manual acceptance remain unverified;
manual tracker checkboxes remain unchecked. Receipt and hashes:
projects/blab/releases/20261016-recovery-26/receipt.json and artifacts.json.
