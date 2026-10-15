# Shared page motion — 15 October 2026

Candidate: fix/practice-language-context-20261014, base/current fetched origin/main 45c1ea4. Continues the same unapproved review worktree; preserves existing checker, shimmer, late-result and keyboard fixes. Not merged, deployed or distributed.

## Owner request and implementation

Replaced the rejected platform-default 450ms proposal with the supplied PageRouteBuilder behavior: 150ms both directions, cubic 1-(1-t)^3, fixed positive 48 logical-pixel translation, matching opacity. Previous route ignores secondary animation and stays stationary. Reverse uses the same reversed curve, not exact Telegram closing easing. Reduced motion skips the decorative transform/fade.

Reusable `telegramRoute` / `TelegramPage` lives in lib/app/telegram_route.dart. `_blabRoute` centrally wraps declarative pages. AGENTS.md and tech-spec require this pattern for future pushes. No new package. Root Chats/Profile tabs remain NoTransitionPage; sheets/dialogs retain their own semantics. OS settings, system share UI and external websites remain platform-owned surfaces.

## Complete source inventory

- Both Chats + entry points (populated and empty list) -> /chats/new.
- Every chat row -> /chat/:id; legacy /chat also covered.
- All ten Profile detail options: known languages (+), translation language, interface language, translation preferences, edit profile, email, password (where available), privacy, notifications, delete account.
- Chat-specific translation preferences, share image, onboarding/auth/recovery and invite resolver all use central route factory.
- The two imperative MaterialPageRoute bypasses (partner profile and full-screen photo) now call telegramRoute.
- Logout remains a confirmation dialog; root tab changes are not page pushes.
- Registry regression walks every GoRoute and requires TelegramPage except the three explicit root/tab pages and redirect-only routes. Future unwrapped route definitions fail this test.

## Verification

- Full Flutter run: 904 passing, 15 intentional skips. Four focused route tests subsequently pass (two new registry/reduced-motion cases plus the two width cases included in full run). Static analysis and git diff --check clean.
- Width tests at 360/720 logical pixels verify initial 48px travel, halfway 6px offset / .875 opacity, 150ms settled state, reverse behavior, and stationary preceding page.
- Exact candidate APK installed in place on emulator-5558 without clearing the existing Bob Local session. Local Stream backend port 54441; production untouched. A first local build used incomplete runtime defines and failed config validation; replaced it with the established stream Android defines before all retained UI evidence.
- Actual Android: all ten Profile detail destinations opened and returned, without saving or performing destructive actions. profile-audit.json records visible destination text; profile-motion.mp4 is 55.44s unaccelerated recording. Screens retained per option. Forms' keyboard behavior remains standard; header Back was used (first system Back dismisses their keyboard).
- Actual Android: three distinct chat rows, keyboard-open composer -> header Back, +/invite and Profile. chats-motion.mp4 is 29.64s unaccelerated recording. Keyboard and return screenshots inspected: + anchored, Profile full viewport. Sampled motion frames show fade/short right-to-left travel over stationary Profile. Automated duration/geometry assertions complement recordings; not frame-time performance certification.
- All ten Profile destinations exercised natively; partner/photo transitions verified by shared wiring and existing tests, not a fresh native interaction in this packet. Predictive-gesture scrubbing/cancellation is not claimed for custom PageRouteBuilder; standard header/system Back works, with curve reversed.

## Other requested fixes / boundaries

No new language logic changes in this increment: previous candidate removes lexical correction rejection, verifies target language and meaning, repairs copied foreign known-language lanes, restores secondary reveal, keeps one pending shimmer and prevents non-editing pages from resizing around departing keyboards.

Fresh live-provider replay with isolated local QA users verifies asymmetric ownership: A learning de / primary-known en / interface es; B learning fr / primary-known uk / interface de. Three messages produce six ready viewer jobs on attempt 1: negation/quantity/time sentence, mixed learner fragment, and reported Es war ein Mal sentence. Actual outputs retain not/two/tomorrow and selected target/help languages. Snapshot in asymmetric-results.json. Runtime index/contract/readable_delivery sources byte-match this worktree. Existing exact same-language correction and prior 44-result sweep evidence retained in preceding QA packets. 94 focused backend checks rerun and pass, including rejecting wrong language, inconsistent meaning verdicts and invalid repairs. These are bounded tests, not a guarantee an AI checker never errs.

Original completed-but-faded phone incident remains un-reproduced; existing missed-response, cache hydration, retry and late-result regressions pass. Do not call that specific incident fixed without reproduction. Production stale translations remain pending targeted repair with deployment; do not invalidate unrelated history. Physical phone/live FCM proof remains outstanding.

## Review gate

Send actual Chats/+ and all-Profile recordings plus inspected return screenshot. Await explicit approval of revised motion before merge/integrated Android verification/Firebase delivery. Owner instruction to fix the rest authorizes work, not acceptance of unseen visuals.

Delivered in this topic: Telegram12714 Chats/+ recording,12715 all-ten-Profile recording,12716 keyboard-return screenshot; all send receipts succeeded. Revised visual acceptance remains pending.

Owner approval: Telegram12720 on 15 October2026, “Yes approved merge and release”. Release integration authorized.
