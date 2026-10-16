# Stationary translation and Connecting loading state

Owner13402: remove horizontal translation-complete motion. Follow-up: replace test access loading copy with Connecting. No access-policy change. Dedicated worktree from origin/main1297044.

Before implementation: MessageBubble resolves each viewer's target and primary-known-language cache key before passing authored/final content into TranslatingMessageContent. Practice uses historical learning language, Normal preserves known authored text or primary-known-language translation; interface locale only controls chrome; aids-off, unsupported language, history, form choice and retry branches stay untouched. Only presentation wrapper changes; no provider/prompt/cache edits. AnimatedSize currently interpolates old/new width for150ms, shifting right-anchored outgoing text horizontally. New arrival motion is independent and retained.

TestAccessGate checks server membership initially, on resume, and every15s. Loading sets status null, hides but retains routed child, and currently shows Logout for signed-in users. Change only loading copy and loading Logout visibility; denied/error recovery and six-second timeout remain.

Verification: 958 tests passed, 15 skipped; focused checks63 passed; Flutter analyze clean. Android emulator5564 journey passed for incoming/outgoing final geometry over12 frames and pending Connecting/no Logout. Screenshots and recording inspected. Synthetic chat/access fixtures; the No connection banner reflects the fixture, not a live network test. No new live model calls. Actual Google sign-in and iOS unverified for this slice.

Android packaging initially blocked by wrong ignored Firebase config, then host disk exhaustion. Copied existing staging config and cleared only main build/app/intermediates (regenerable); release outputs/data retained. Debug test runner replaced the emulator test installation because installed26 was newer than debug1; no physical device affected.

Evidence: blab-01 through05 PNGs and review.mp4 (raw recording retained separately). Owner visual approval, merge, integrated verification and test distribution pending. Production requires separate explicit approval.

## Owner revision13414
Previous full-screen Connecting evidence is rejected/superseded. Pending access now retains visible interactive routed child; ConnectionStatusScope feeds existing OfflineBanner slots, replacing (not stacking with) No connection while pending. Orange brand fill and warm ink text,40px existing slot. Explicit denied/error still hides child; server RLS unchanged. Auth resume test now verifies retained screen visible.46 focused tests pass; analyze clean. Revised native chat screenshot uses synthetic connectivity/access signal, not live server authorization.

Revised Android5564 journey passed, including one Connecting banner replacing offline text, chat visible and incoming/outgoing result geometry stationary. Actual screenshots and recording inspected; banner-review.mp4 and blab-banner-02-received-ready.png delivered for review. Owner approval pending; not merged or released.
