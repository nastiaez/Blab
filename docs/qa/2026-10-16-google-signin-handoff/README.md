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
