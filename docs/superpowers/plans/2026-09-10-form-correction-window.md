# Form Correction Window Implementation Plan

**Goal:** Implement the owner-approved bounded correction window without rewriting completed history.
**Architecture:** A small account-scoped persistent ledger controls resolved forms and the active message; UI and message events consume it. Existing server preferences keep ownership.
**Tech Stack:** Flutter/Dart, Riverpod, SharedPreferences, existing Supabase services.

- [x] Add failing ledger tests for stable message identity, old-message eligibility, transfer, settings change, expiration, persistence and isolation.
- [x] Implement `lib/features/chat/state/form_correction_state.dart`; ledger updates serialize and persist before success.
- [x] Promote chooser and history diagnostic regressions to test coverage, confirm RED, then preserve prepared form metadata and repair controlled chooser selection/Change/save-error behavior.
- [x] Wire ledger into chat rendering, capture resolved forms per message, save explicit choices, and apply settings edits only to active matching messages.
- [x] Close windows on queued outgoing messages and observed new incoming messages; retain them across navigation, history paging and metadata updates.
- [x] Verify focused tests and analysis, package browser/Android, run the approved interaction on local Alice/Bob, capture screenshots.
- [x] Update PRD, tech decisions, progress/backlog/dashboard, and record remaining upstream defects without marking them complete.

Execute inline in the current feature checkout to preserve the running QA environment. Existing investigation evidence is retained. Review changes directly; final code-review skill additionally requested one bounded read-only reviewer.

Verified 11 September; owner acceptance remains a separate unchecked gate. Device investigation additionally fixed MessageArrival subtree remount on accessibility changes. See QA record for remaining translator defects.
