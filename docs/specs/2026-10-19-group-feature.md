# Blab groups and member-to-member messaging

Date: 19 October 2026. Ticket: BLA-14.
Status: implementation authorized in topic7420 requests14489 and14578. Candidate work and review are in progress; implementation screenshots and final device/live-service checks remain unapproved/incomplete. No merge or release authorized.

## 1. Authority and design references

This specification captures the decisions in Blab Dev 2 through the request to write a spec, not build. Latest decisions override earlier proposals: 100 rather than 30 members; Accept / Block rather than View-to-accept or Accept / Reject; normal unread styling rather than a Message request label; aggregate group read ticks included, detailed reader lists deferred.

- Group screens: https://app.paper.design/file/01M54K6J9EQ56GP909AWJHEKPQ/p-3-0
- Request screens: https://app.paper.design/file/01M54K6J9EQ56GP909AWJHEKPQ/p-4-0
- Ticket: https://linear.app/blabchat/issue/BLA-14

The links identify the design references recorded in this conversation, not a fresh visual audit. Before implementation, inventory the exact current artboards and screenshots, preserving their copy, spacing, states, icons and navigation. Superseded screens must not be implemented.

## 2. Scope

Create, invite, join, group chat, group information, full member list, owner actions, shared photos, private contact from a member, pending-message preview, acceptance, blocking and unblocking. Maximum 100 members. No separate blocked-people directory. No detailed Seen by menu. No implementation is part of this deliverable.

Latest approved defaults14560/14566/14578 supersede earlier proposals: any current member may share the invite; new and returning members can read earlier original messages/media, but translations and corrections begin only at the latest join. Removed members need a newer invitation. Existing1:1 settings apply unless a group-specific rule is explicit. A private stranger request remains one text until Accept. Read the membership/cost design and completion QA record for implementation status; approval of rules is not approval of unseen implementation.

## 3. Group journeys

### Create → invite → join

1. Follow the current Paper entry and creation screens; do not invent fields or replace controls.
2. Creating a group makes its creator the owner.
3. Share the group invitation using the designed invite surface.
4. Opening an invite shows the appropriate join flow. Authentication must return to the intended invite, not lose it.
5. Successful join creates one membership, updates counts and opens the group. Reopening an invite as an existing member opens the existing group without duplication.
6. Enforce the 100-member cap on the server, including simultaneous joins. Recommended counting rule: owner included.
7. Invalid/unavailable invitation, full group and failed join must have recoverable states. A failed action must not falsely show membership or consume capacity.

### Group information and members

- Use profile names as entered by users, never phone numbers as member labels.
- Preserve the roomier member-row spacing from Paper.
- Show the member total and limited preview. See all opens a separate scrollable full list with the same row design; the full list has no settings control or collapse action.
- Top-left Back returns to group information. Preserve scroll/navigation state where practical.
- The 30-member mockup demonstrates overflow, not the group limit. Verify 1, 30 and 100-member layouts, long names and missing avatars.
- SHARED MEDIA displays the total number of accessible photos, not just preview thumbnails. History restrictions must also apply to photo counts and previews.
- Tapping a member exposes Message, or Unblock and message if the viewer blocked that person. Owner menus additionally retain Make owner and Remove from group from the design.
- Ownership/removal actions require current authorization on the server, not merely hidden controls. Failures retain accurate member/owner state.

### Group conversation

- Messages identify the author and preserve the existing chat visual language.
- Each viewer's practice and translation preferences remain independent; joining must not overwrite other members' settings.
- Correction annotations for a person's own messages are visible only to that person. Do not show other members' corrections or expose them in shared responses, previews or notifications.
- Preserve the existing per-viewer translation rules, learning-aid settings and historical language behavior. This spec does not authorize a new translation policy.
- Blocking private contact does not remove either person from the shared group or hide their group participation.

## 4. Private contact from a member

### Entry and pending state

1. Tap a member → Message.
2. If an active private conversation already exists, open it without creating a duplicate or resetting preferences.
3. Otherwise compose/send the initial request message. Working default: one text only until accepted; no additional texts, photos or replies while pending.
4. Recipient receives a notification subject to their existing notification settings.
5. The conversation appears in the normal Chats list with a one-line message preview and normal unread styling. Do not add a Message request label or separate inbox.
6. Open the row → select a practice language → view the full message. Back/cancel leaves the request pending and does not accept it.
7. Show “Accept to reply to {name}” and Accept / Block. Replying is unavailable before acceptance.

### Viewing is not accepting

List previews, opening the request and choosing a practice language never accept it or emit a sender-visible read receipt. Acceptance requires the explicit Accept action. The sender must not infer reading from preview events. Recipient-local unread clearing is a separate decision, noted below.

### Accept

Accept transitions pending → active and enables normal replies. Keep the selected practice language and initial message. Subsequent reading follows normal one-to-one receipt behavior. Repeated taps, retries or another device accepting must not create duplicate conversations.

### Block

Use the existing localized Block confirmation visual/copy pattern; verify it against the current app before implementation. Do not invent a conflicting confirmation text.

On confirmation, delete the unaccepted request and its message from both participants' chat surfaces and prevent further private contact from the blocked person. There is no separate Reject action. Cancellation changes nothing. This request-specific deletion does not authorize deleting an established conversation for both people; established-chat blocking remains governed by the existing PRD.

Blocking must be enforced across group-member entry, personal invite links, direct sends, retries and other devices. Shared group participation remains unaffected.

### Unblock and message

The person who applied a block sees Unblock and message in the group-member popup instead of Message. Explicitly taking this action removes their own block and opens private contact; sending a fresh message follows the normal request flow if no active chat exists. Deleted requests do not return. The other person's independent block, if any, remains effective. A blocked person cannot unblock themselves.

Recovery when there is no shared group, and no surviving blocked conversation, is out of this version's scope. No blocked-people directory is added.

## 5. Read receipts

Conversation reference for the current one-to-one behavior: one tick means delivered; two ticks mean read; colour does not change. Reverify the implementation before reusing it.

For groups, two ticks appear only when everyone else has read the message. No extra bottom-menu item or named reader list. Pending private requests never become read through previewing.

Recommended membership rule, pending product confirmation: snapshot recipients at send time, excluding the sender; later joiners cannot delay old messages' read status. Keep departed recipients in that snapshot so departure is not falsely counted as reading. A message with no other recipients must not appear read by everyone through an empty-set calculation. Define the single-tick delivery threshold before implementation.

## 6. State and access contracts

- Group membership and ownership are authoritative server state. Membership count, join boundary and ownership changes must be atomic.
- Pending, active and blocked contact states are distinct. Opening a screen is never a state transition to active.
- Revalidate membership, blocks and pending limits when committing sends; do not trust stale client state.
- Retry create, join, first-send and Accept without duplicate effects. Restore the actual state after reconnect/restart.
- New-member history boundaries apply to messages, search, replies/quotes, media and notifications, not only visible chat rows.
- Removal ends future group send/read access; retained historical access requires the product decision below.
- Corrections are private data, not just hidden decorations.
- Do not change deployed data or services as part of specification work.

## 7. Remaining decisions / design checks

The main journey is specified; these edge cases must not be silently invented during implementation:

1. Confirm the three working defaults in section 2 and whether the owner counts toward 100 (recommended yes).
2. Confirm send-time recipients for group receipts, departure behavior and when one delivery tick appears.
3. Owner exit uses manual transfer first (approved 20 October,14432): tapping Leave group while other members remain shows the dismissible notice in section 11. Existing Make owner is separate; no combined transfer-and-leave journey. Last-member exit remains separate from this notice slice.
4. Define group invite revocation and whether removed members may rejoin using an old invite.
5. Define history after leaving/removal and rejoining, consistent with the new-member history boundary.
6. Decide whether recipient-local unread styling clears after preview, while always suppressing the sender's read receipt until acceptance.
7. Confirm group practice-language setup and how existing preference rules map to multiple members; do not apply the two-person shared-correction rule to group corrections.
8. Verify the latest Paper create/join, owner, leave and failure states, plus the existing Block confirmation copy. Missing states need design review, not generic substitutes.

## 8. Acceptance checklist for future implementation

- [ ] Create, share and join works for a new and an existing account; repeat joins are idempotent.
- [ ] At 99 members, concurrent join attempts cannot produce 101; capacity errors are recoverable.
- [ ] History and media visibility honor the chosen membership boundary.
- [ ] Group info and full list match approved artboards at the same viewport/text scale; names only; media totals correct.
- [ ] Member and owner menus expose only permitted actions; stale permissions cannot bypass server checks.
- [ ] A stranger's first message appears as a normal unread chat preview with no request label.
- [ ] Language choice and preview do not accept or send read receipts; cancelling preserves pending state.
- [ ] Accept enables replies exactly once; pending limits survive restart, retries and multiple devices.
- [ ] Block removes only the pending request from both sides, blocks private contact and preserves group participation.
- [ ] Unblock and message cannot resurrect deleted requests or remove the other person's block.
- [ ] Author-only corrections remain private with different languages/preferences across at least three members.
- [ ] Partial group reads keep the unread tick state; all eligible readers produce two ticks; no detailed reader menu.
- [ ] Offline/retry, push-entry, full-group, invalid-invite and removed-member states are covered.
- [ ] Existing one-to-one messaging, block, invite and leave/delete behavior regresses neither functionally nor visually.

## 9. Delivery sequence, only after implementation authorization

One reviewed slice at a time: (1) create/invite/join; (2) group conversation and author-only corrections/aggregate receipts; (3) info, members, media and owner actions; (4) private requests and blocking recovery.

Each slice requires actual screenshot walkthroughs and motion recordings where relevant, comparison against the frozen prototype, explicit visual/journey approval, and target Android verification. Specification approval is not implementation, merge or release approval. Keep the release queue accurate; batch releases only when separately authorized.

## 10. Design review supplement · 20 October 2026

Latest request is to design manual owner handover in Paper using Signal's rule
and Blab UI. Proposal: Leave stays tappable; owner receives an explanation,
chooses another member, and confirms the named transfer and departure together.
Cancel/Back preserve membership and ownership. Sole member confirms close/leave;
failed transfer retains the choice for retry. No automatic successor is selected.
Six static review states: https://app.paper.design/file/01M54K6J9EQ56GP909AWJHEKPQ/p-5-0
This is a proposal awaiting visual approval, not authorization to implement it.

Latest invitation correction rejects group-authored pseudo-messages. The G02
invitation retains its group header and Join/Reject footer, without a fabricated
chat bubble or date. Only real person-authored messages belong in chat bubbles.

## 11. Approved owner-exit notice · 20 October 2026

14432 explicitly approves implementation of the single alert from Paper
https://app.paper.design/file/01M54K6J9EQ56GP909AWJHEKPQ/p-6-0 .
This supersedes section 10's six-state proposal, not unrelated group features.

- Leave group remains tappable for an owner with other members.
- Title: Choose a new owner first
- Body: Before you leave, go to Members and make someone else the group owner.
- Only action: Got it. It dismisses to unchanged Group info; Back and tapping
  the scrim also dismiss without changing membership/ownership or scroll position.
- Existing member menu → Make owner performs the separate ownership change.
  No new picker screen or combined transfer/leave confirmation.
- Use the exact warm Paper alert geometry, copy, typography and 48px action
  target; localize all copy through Interface Language. Large-text adaptation
  must preserve hierarchy and keep the action reachable.
- This slice implements the blocked-owner explanation only. Actual non-owner
  departure, sole-member closure and the other unfinished group actions remain
  separate work; never route group exit to the two-person leave_chat RPC.
- Design approval is not approval of unseen native implementation or release.

## Remaining implementation request14489 ·20 October

User authorized implementation and verification of all remaining agreed group
journeys. This does not authorize merge/distribution of unseen implementation.
See `../qa/2026-10-20-group-recovery/completion-14489.md` for completed evidence
and unresolved acceptance. Historical access after leave/removal is an explicit
open product choice; do not silently choose retention or revocation semantics.
Notifications/media and private-request UI evidence are separate from successful
live learning, device push delivery and completed lifecycle behavior.
