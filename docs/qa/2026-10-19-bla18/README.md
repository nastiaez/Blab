# BLA-18 · 20 October 2026 recovery

- Branch: `feat/bla18-get-started-20261019`, base/current origin/main `22157a3`; uncommitted candidate.
- Scope: only Welcome CTA becomes Get started / Los geht’s / Comenzar / Розпочати. Both responsive layouts use the dedicated localized key; subsequent Continue remains unchanged.
- Preference mapping: Interface Language owns CTA copy. No Known/Learning Language, translation, audio or server changes.
- Android emulator-5564: `get_started_native_test.dart`, 4 locales, button callback exactly once per locale; passed in `/tmp/bla18-resume-native2.log`.
- Screenshots: `android/welcome-{en,de,es,uk}.png`, all individually inspected after rerun. Reject the earlier English missing-illustration capture; corrected by awaiting asset decode in test only. No product asset change.
- English screenshot delivered to topic 8856 as 14332. Actual screenshot approval pending. No commit, merge, release or hosted modification.
- Focused onboarding regression packet: 11 passed in retained `/tmp/bla18-tests.log`.
- Analysis: no issues, `/tmp/bla18-analyze.log`.
- Full regression rerun: 971 passed / 16 skipped / one expected Welcome golden mismatch. Updated only the Welcome baseline for the requested CTA; other four baselines byte-identical. The 0.31% isolated pixel diff is confined to the action label. Golden update and subsequent comparison both pass (/tmp/bla18-golden-update.log, /tmp/bla18-golden-verify.log). First attempt stalled after819/16 and was canceled, not counted as a pass. This is a full packet plus targeted resolved golden check, not a claim of a single green full-suite invocation. Four locale catalogs have identical413-key sets.
- Original Android failure: no disk space; rerun passed after removing ignored reproducible caches. Native test device subsequently froze during BLA-21 startup, which is separate from BLA-18 evidence.

## Source fingerprint

- `lib/features/onboarding/welcome_screen.dart` SHA256 `7ba87b08b694fe8fc2894367926c5fd46bb3c719a1ff926a6569a8e5cacc6d49`
- `lib/l10n/app_en.arb` SHA256 `5aa5bc2a99a67d918cd8e79157e8a8f22e6c82c399d80ef2989eb884bfb51876`
- `lib/l10n/app_de.arb` SHA256 `1736aa1e2223308ed75c39ca979af96b456339fc59c7eb88abe764be6d846e3c`
- `lib/l10n/app_es.arb` SHA256 `52b473a850e1c843cbecd0efc39209fd70107073a509eea0ca1fe4a7c82df52b`
- `lib/l10n/app_uk.arb` SHA256 `1623a30a2a11f79964f2bcb6d4faf5a2160c2e333bc6a6058c51292353c3fefb`

- Approval14424 (Nastia, topic8856, 20 October): explicitly confirms actual opening-screen screenshot14406, including Get started text and appearance. BLA-18 visual approval recorded; not approval of BLA-16, manual all-flow acceptance or distribution.
