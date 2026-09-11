# Immediate grammatical-form correction window

Approved: owner asked to define and build this rule, 10 September 2026. US-042 / FR-35.

## Exact product rule

- The active message is the message on which this viewer most recently **successfully selected** a grammatical form in this chat. It is identified by message identity, not screen position, recency of sending, or visibility. A month-old unanswered message can be the active message.
- At most one message per chat has this window. Selecting a form on another message transfers the window; the former completed message becomes fixed.
- The window begins only after a successful explicit selection, not when a message is displayed or automatically resolved from an existing preference.
- Until the viewer sends or receives the next new message in that chat, both inline Change and the matching form row in Chat/Profile Translation preferences update the active message and its confirmation. Existing older completed messages stay fixed. Other unanswered choices may resolve under the existing rule but do not become the active message.
- Scrolling, navigation, opening Settings, backgrounding and reopening the app do not themselves close the window. On reload, new messages received since the boundary close it before further correction. Another chat's activity, reactions, read receipts, delivery updates and pagination do not close it.
- A send closes the window as soon as its new message is queued, including an offline send. A failed send does not reopen it. Received text and photos both close it. Editing/deleting the active message invalidates that source-specific window; editing some other message does not.
- When the window closes, Change/confirmation disappear. Settings thereafter affect future translations and unanswered choices only, not completed messages.
- Clearing the matching form to Not set while the window is open reopens the active message's choice. Changing a different person's form or conversation tone does not revise that message.
- Save errors keep the existing message/choice and expose a retryable save error; no successful window is created for a failed selection.

## Implementation boundary

Use an account-scoped, device-persisted ledger of source/target-specific rendered form choices plus one active window per chat. It survives Settings routes and app restarts without changing shared translations for other viewers. Account-wide form preferences remain server-owned. The local immediate-correction interaction is not transferred between devices. Message stream/send events close windows; newer fetched messages cover missed realtime events. Store stable source text with each record to reject stale edited content. Preserve form alternatives from prepared packages. Replace duplicate local chooser selection state with controlled parent state and an editing flag. Remove global historical translation refresh on settings changes; update only eligible ledger entries and let future translation requests use the saved preferences.

Scope excludes the separate upstream wrong-person/language-detection bugs; do not claim those fixed. No mass history rewriting, no changes to authored message text.

## Verification

Tests cover historical/off-screen selection, settings round trip, Change, window transfer, same-chat new sends/receives, other-chat activity, reaction/read/update no-op, pagination, source edit, clearing, persistence/account isolation, save failure, preservation of completed records and prepared choice metadata. Browser/emulator proof must show feminine → Settings masculine updates the eligible sentence, then another message closes the window and another settings change leaves that completed sentence unchanged. Keep owner checkboxes open until owner approval.
