# Grammatical-form self labeling and targeted Change flow

**Date:** 2026-09-11  
**Status:** Approved interaction, awaiting implementation

## Problem

An incoming second-person sentence correctly uses the viewer's grammatical-form preference, but its note displays the viewer's profile name. Tapping **Change** opens the general Translation preferences page without identifying which of the two form rows controls the annotated sentence. Together, these make correct person ownership look incorrect.

## Interaction

- When the affected subject is the current viewer, the note says **Using feminine forms for you** or **Using masculine forms for you**.
- When the affected subject is the chat partner, the note keeps the partner's display name.
- Tapping **Change** routes with the affected subject (`viewer` or `partner`) and immediately opens that subject's existing grammatical-form picker.
- Saving or clearing the picker continues to use the existing preference services and correction ledger. The annotated sentence and note update together under the existing correction-window rules.
- Returning from the picker leaves the user on Translation preferences; Back returns to the chat.

## Architecture and data flow

1. `GrammaticalFormNote` selects self-specific localized copy from its existing `subjectIsViewer` input.
2. The chat route appends a subject query parameter when opening Translation preferences.
3. `TranslationPreferencesScreen` consumes the optional subject parameter once after the page is mounted and opens the matching existing picker.
4. Existing `setOwnForm` / `setPartnerForm` persistence and `changePreference` reconciliation remain the only mutation path.

Unknown or absent subject parameters preserve the current general settings behavior. No server, cache, schema, or translation-contract changes are required.

## Verification

- Widget test: viewer note uses **you**, never the viewer's display name.
- Widget test: partner note keeps the partner's name.
- Navigation test: viewer note opens the own-form picker.
- Navigation test: partner note opens the partner-form picker.
- Existing own/partner preference and correction-window tests stay green.
- Build and install the Android app, capture the viewer note, targeted picker, and updated masculine sentence.

## Out of scope

- Chat-list preview form rendering.
- The existing corrected-interface-text and reply-preview failures.
- Server-side grammatical-role detection, which is already covered separately.
