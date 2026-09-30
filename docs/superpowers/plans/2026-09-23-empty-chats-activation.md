# Empty Chats Activation Implementation Plan

**Goal:** Improve Blab's existing empty Chats state without adding a new onboarding route.

**Architecture:** Keep `ChatsScreen` as the single destination. Its confirmed empty data state hides the floating action and renders the approved illustration, localized value copy, and existing invite CTA. Existing invite continuation remains the authority for direct chat opening.

**Tech Stack:** Flutter, Riverpod, generated ARB localization, Flutter widget tests.

### Task 1: Lock the empty-state contract

- Add widget coverage for the value copy, invite CTA, hidden empty-list FAB, and retained non-empty FAB.
- Update the localized-copy contract.

### Task 2: Integrate the approved visual and behavior

- Add the transparent pixel illustration as a Flutter asset.
- Render it above the title.
- Hide the FAB only for a confirmed empty list.
- Update all four launch locales and regenerate localization output.

### Task 3: Verify the journey

- Run focused and full Flutter checks.
- Confirm existing invite-link tests still open the resulting chat directly.
- Review the empty state at compact and standard phone sizes and capture the final screen.
