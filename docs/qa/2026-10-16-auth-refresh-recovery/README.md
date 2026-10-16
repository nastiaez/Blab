# Recoverable auth-refresh outage — 16 October 2026

## Scope / source

- Owner authorization: current development topic, message13259 (`Do it`).
- Fresh branch `fix/auth-refresh-recovery-20261016`, base remote main
  `5941bd43e967e5ad46c4f36adbb673adff9d355b`. Main was clean; existing
  worktrees and shared backends left untouched.
- No layout/copy/policy change, no hosted mutation, no release authorized before
  the standing screenshot/journey review gate.

## Incident evidence

Read through the authenticated Sentry UI:
https://blab-r3.sentry.io/issues/153884504/

- Issue FLUTTER-6, one event and one user at inspection.
- Event `e9279c12168f4d11bd47235285a73eb1`, 15 October 16:20:12 CEST.
- Production release 1.0.0 (19), Android17, Samsung SM-S948B.
- App foreground=false, lifecycle=paused; FlutterError mechanism,
  handled=false, fatal severity. This is not evidence of native process death.
- The failed request passed through Supabase `_getAccessToken` and GoTrue
  `refreshSession`, then `_refreshAccessToken` and `GotrueFetch._handleRequest`.
- That fetch.dart line catches transport exceptions. The original exception
  value is deliberately redacted; exact network cause is unavailable. Do not
  weaken privacy scrubbing to recover it.

## Confirmed implementation gap / fix

1. Root auth stream handler forwarded retryable refresh failures to
   `FlutterError.reportError`, misclassifying a recoverable condition as fatal.
2. The session provider propagated the same error instead of retaining its last
   successful session. Other session-driven providers could rebuild on failure.
3. Revocation classification used text matching without excluding typed
   retryable failures.

Ignore only `AuthRetryableFetchException` at the first two boundaries and exclude
it from text-based revocation. SDK retry and automatic token refresh remain the
owner of refresh scheduling. No global Sentry filter and no blanket error catch.

## Preference / state ownership

This changes authentication error handling only. Interface Language still owns
interface copy; Primary Known Language owns explanations/Normal fallback;
Learning Language owns Practice/audio. Neither participant's values, historical
results, mode, learning aids, tone/form/reading script nor server contracts change.
Current account remains authoritative; real sign-out and account-switch events
still flow and account-owned data must not survive as another user's identity.

## Verification

- Red: original code failed both session-preservation and root Flutter-error
  regression cases; unexpected-error reporting already passed.
- Green: initial three focused checks pass; initial full Flutter suite950 pass,
  15 pre-existing skips; analysis clean. A subsequent revocation guard adds one
  focused check; final results will be recorded below.
- Native Android proof uses a synthetic account/chat list and mocked HTTP
  transport with the real Supabase SDK, BlabApp, router and session provider.
  It forces a failed HTTP token refresh through SDK retries, then successful
  renewal. This is deterministic client-recovery evidence, not live production
  backend/real-user-device acceptance or a two-person messaging test.
- Dedicated read-only Android emulator5562; no shared emulator or database reset.
- Native client scenario PASS: actual HTTP refresh exhausts SDK retries during
  injected SocketException; session token/account remain unchanged, provider
  stays signed in, and no Flutter exception is reported. On transport recovery,
  one explicit SDK refresh succeeds, new token propagates, original account/chat
  row remains and the normal offline banner disappears. This does not separately
  prove production automatic-refresh timing or a physical handset.
- All three actual native screenshots opened and visually inspected. No UI
  redesign or motion change. Delivered as Telegram message13272, receipt
  thread8856. Files01–03 map to connected, failed refresh/session retained,
  reconnected/new token/same account.
- Initial native attempt failed because the synthetic fixture's asynchronous
  onboarding resolver displaced Chats. Corrected only test setup by fixing the
  completed-onboarding destination; second native run passes. No app routing
  change was made to hide this setup failure.
- Focused auth/cached-session/widget checks14 pass (includes revocation guard);
  backend policy checks188 pass; final analysis clean; formatting365 files,
  zero changes; shell syntax and whitespace pass.
- Owner screenshot/journey acceptance, integrated-main Android verification,
  hosted/live acceptance and release remain pending. Sentry issue left open.
- Final full Flutter suite:951 passed,15 existing skips; no failures. Main and
  origin/main both remain5941bd4, clean and unchanged. Candidate stays uncommitted
  in its dedicated worktree until owner review, per the Blab workflow.

## Approval / delivery

Owner message13274 explicitly approves merge to main and release of the reviewed recovery. Integration and signed production/test Android25 verification underway; no scope expansion or backend changes.

## Released Android25 — final receipt

- Approved13274; source a48919dd1d3425a9e692aa93ea76eeb55cc091fc merged/pushed to synchronized main. All three integrated CI jobs passed: Quality, Local Supabase integration, Android release compile (run38857777568).
- Repeated the deterministic HTTP-outage/session-retention/renewal journey from main on dedicated Android5562: pass; all three screenshots inspected. The initial main harness setup used staging Google configuration and stale release-only plugin registration; restored documented production configuration and regenerated dependencies, without any source change, then the complete test passed.
- Signed production/test25 compiled from integrated main. Both24→25 replacement installs on dedicated5564 succeed, matching the prior signing certificate and retaining German in the actual UI. No uninstall or data clear. Reconstructed signed-out emulator baseline only; retained signed-in history and physical-phone acceptance are not claimed.
- Firebase public release61j2ochfmi6no and test77jond3c0ri70 distributed to their exact existing2/8 recipients. Reopened each release-specific URL: public2 invited/2 accepted/0 downloaded; test8 invited/2 accepted/0 downloaded. These are availability receipts, not installation claims.
- Downloaded both Firebase binaries back; hashes match the exact verified signed APKs. Receipt in release/receipt.json records package/app/release/source/checksum mapping.
- No backend, website download or iOS/TestFlight changes; this is an Android App Tester release. Launch tracker remains unchecked pending the owner's physical-device manual confirmation. Sentry issue retained for monitoring rather than suppressing future failures.
