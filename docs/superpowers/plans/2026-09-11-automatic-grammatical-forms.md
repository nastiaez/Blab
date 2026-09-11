# Automatic grammatical forms implementation plan

Goal: implement approved complete-message, once-per-person note flow and correct participant attribution.

- [x] Add failing contract tests for outgoing/incoming I/you role mapping and audit of existing alternatives; add optional suggestion/role metadata and remove contradictory no-name-suggestion instructions.
- [x] Add ledger tests for once-per-person persistent notes, feminine fallback, saved-form precedence and bounded history changes.
- [x] Replace the chooser/markers in ChatScreen with a complete rendering plus localized note. Change routes to existing Translation preferences.
- [x] Update governing specs/tracker in this turn; preserve previous work/evidence and owner gates.
- [x] Run focused server/Flutter tests and analysis, package Android/web, verify local Alice/Bob and capture screenshots. Record remaining upstream defects honestly.

Execute in the current feature checkout; do not discard previous changes. No new external services or paid setup.

Local evidence and explicitly unverified checks: `docs/qa/2026-09-11-automatic-forms/README.md`. Owner launch gates remain unchecked.
