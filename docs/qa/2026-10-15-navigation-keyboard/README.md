# Android navigation, keyboard and pending translation

Unmerged candidate on fix/practice-language-context-20261014, base45c1ea4. Includes the previously reviewed but unapproved language-integrity work; no production deployment.

## Findings and changes

- Theme already used PredictiveBackPageTransitionsBuilder. Two chat routes bypassed it via NoTransitionPage; new-chat and settings used standard Material routing. Both chat routes now use MaterialPage. Root/list/profile tab destinations remain no-transition. Modal dialogs, sheets and inline reaction fades are not page transitions and remain unchanged. Full code search retained in route-audit.txt.
- Installed Flutter3.44.8 native Android fallback is FadeForwards450ms, supporting predictive Back through existing manifest and PopScope. Reference: https://docs.flutter.dev/release/breaking-changes/default-android-page-transition and https://api.flutter.dev/flutter/material/FadeForwardsPageTransitionsBuilder/kTransitionMilliseconds-constant.html . Flutter documents this as an approximation of Android spring motion, not identical native timing.
- Chats/Profile incorrectly inherited keyboard resizing despite having no inputs. Injected300px keyboard inset moved the FAB before the change. Both now opt out of Scaffold keyboard resizing; editable screens retain it. Header Back unfocuses the composer before navigation without clearing draft text.
- Pending Practice keeps existing shimmer rather than a separate Translating label. Reduced-motion still suppresses animation. True terminal errors still preserve original plus Retry. Backup polling and server attempt budget unchanged.
- Read-only production query found the same Es war ein Mal für dein Satz error for both viewers after four attempts: openrouter_incomplete_correction. No newer failed job in the scoped chat at inspection. Candidate exact four-message context replay completed all8 viewer jobs on first attempt; problematic sentence readable3.509–4.068s. Some ready outcomes were obtained from full cache rather than readable table; no result omitted.

## Verification

902 Flutter tests passed,15 intentional skips; static analysis clean; Android debug build passed. Regression assertions cover stable Chats FAB, full Profile viewport under keyboard inset, shimmer after9s and late-result replacement. Existing backend candidate197 tests and44-result language sweep retained; no backend changes in this increment.

Android emulator5558 in-place update retained test session. Baseline captured keyboard over returning Chats with elevated FAB. Candidate: open chat, focus composer, type unsent draft, header Back, inspect Chats and Profile, open + and Back. Screens inspected. Actual27.041s screen recording sampled during transition and later state. No keyboard blank area remains in these candidate captures. Production phone-specific reproduction and predictive gesture cancellation remain unverified; standard Back was exercised. Separate ready-but-faded user incident is not established/reproduced by this replay.

## Review

1. chats-after-back.png — + anchored above navigation after keyboard-open Back.
2. profile-after-back.png — full scroll viewport, no empty keyboard-height band.
3. corrected-messages.png — exact reported sentence sequence settles.
4. navigation.mp4 — actual native route/keyboard sequence.

Owner review needed before merge/release. Existing bad production translations have not been repaired. Next: preference-asymmetric checker acceptance and approval of updated motion/pending behavior; preserve existing scope and no new release until accepted.
