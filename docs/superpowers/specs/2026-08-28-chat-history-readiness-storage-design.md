# Chat history readiness, unread anchoring, language timeline, and offline photos

**Status:** Approved product design — ready for implementation planning
**Date:** 2026-08-28
**Related:** US-015, US-016, US-031, US-041, US-043–US-047; FR-13, FR-14, FR-25, FR-26, FR-36, FR-38–FR-41

## Problem statement

When one participant opens a burst of messages, Blab currently begins missing translations only after the chat opens. Up to three results then finish independently, so incoming bubbles appear slowly and out of order with no visible explanation. Pending one-pixel rows can also be counted as visible and marked read before the translated content appears, while later row expansion and Normal/Practice reflow can move the reader away from their place.

Photo originals are already stored privately in Supabase Storage, but the app retains only a temporary signed link and an in-memory image. A previously visible photo can therefore become a red broken-image state offline even though the stored original still exists.

The current single learning-language cutoff creates a separate history problem: changing German to Spanish makes earlier Practice history fall back to authored text. Completed messages should retain the learning language they used, while unseen pending work should follow the new choice behind a clear private timeline marker.

## Evidence

The 2026-08-28 Alice/Bob local-device review found:

- Translation misses are started on chat open and processed with three concurrent background requests.
- Incoming held rows have near-zero geometry and may satisfy the existing visibility-based read check.
- Alice had zero unread messages; all 23 Bob messages had read records despite the reported progressive hidden reveal.
- Normal/Practice switching changes bubble geometry without preserving a message anchor.
- All seven local test photo files still existed in private Supabase Storage; the failure was device-cache absence, not file loss.
- Existing translation rows persist in Supabase, but the learning-language cutoff excludes earlier history from the new target.

## Goals

1. Messages delivered while the recipient is outside the chat are normally final and translated when the chat first paints.
2. A genuine remaining translation wait is understandable, chronological, non-blocking, and does not move the reader.
3. Read state represents content the recipient could actually see, never an invisible pending row.
4. Switching Normal/Practice retains the reader's current place.
5. Completed Practice history retains its historical learning language across later language changes.
6. Synced chat photos remain recognizable and usable offline without red framework errors.

## Non-goals

- Translating every completed historical message again whenever the learning language changes.
- Showing a special alert or automatically scrolling to an off-screen translation failure.
- Media auto-download preferences, a downloads manager, or user-facing cache controls in this version.
- Keeping every full-resolution photo on-device forever; Supabase Storage remains the durable original.
- Changing the existing read-receipt privacy toggle or its symmetric OFF behavior.
- Changing outgoing translation motion, word lookup, long-press actions, or photo-upload composition.

## User stories

- As a recipient, I want new messages prepared before I open a chat so I can begin reading immediately.
- As a recipient opening a genuine remaining miss, I want to understand how many messages are still translating without seeing the sender's mistakes in Practice.
- As a recipient, I want messages to become readable oldest-first without one slow result blocking later successful results.
- As a recipient, I want unread state and the unread divider to match what I have actually seen.
- As a reader switching modes, I want to stay at the same message instead of jumping through history.
- As a learner changing language, I want completed earlier translations to keep their previous language and later messages to use the new one.
- As a participant, I want previously synced photos to remain visible offline.

## Product design

### 1. Prepared message views

After delivery, Blab prepares one viewer-specific language package for each participant. The package contains everything needed for both modes:

- exact authored text and detected source language;
- Practice learning-language result and word metadata;
- Normal primary-known-language fallback when the source is unknown;
- correction, explanation, and grammatical-form data where eligible.

The original message remains stored once. Normal and Practice do not create duplicate messages. A package is persisted in Supabase before it is announced as ready.

Normal retains its existing display rule:

- known source language → show the authored message immediately, with no translation wait;
- unknown source language → show the stored primary-known-language result;
- unresolved unknown source → use the rare pending treatment below.

Practice uses the stored learning-language result. It does not expose an incoming authored message while work is pending.

Fully protected content such as emoji-only, number-only, URL-only, or photo-only messages skips language preparation and appears immediately.

### 2. Rare pending treatment

Pending incoming messages retain their chronological positions as normal incoming-bubble slots. Each slot contains two static skeleton lines in `#EAE6E0` inside the existing incoming bubble surface and outline.

One status line appears on the chat background under the pending group, aligned with the incoming bubble edge:

- one pending message: `Translating…`
- multiple pending messages: `Translating {count} messages…`

The status uses regular 12 px `#8C735F`. No header status is shown.

Results reveal oldest-first. As soon as the oldest pending result is ready, its skeleton resolves; Blab does not wait for the rest of the group. A later message may finish processing internally first, but it cannot visually overtake an earlier pending message.

One final translation failure does not block other messages. After the existing quiet retry and shared ten-second deadline, its skeleton becomes the readable authored message with the existing `Couldn’t translate · Retry` row. That visible fallback can be marked read.

Photo-only messages appear immediately. A received photo with a caption follows the same caption-readiness rule; the stored preview and final caption appear together unless the caption reaches final failure, when the preview appears with the authored caption and Retry row.

### 3. Unread entry and read registration

On chat entry, Blab identifies the recipient's oldest unread message before laying out the thread.

The chat opens with that oldest unread message at the top of the readable viewport. Immediately above it, a persistent session divider displays:

`{count} new message` / `{count} new messages`

Divider styling:

- centered label directly on the chat canvas;
- text `#8C735F`, regular 12 px;
- one 1 px `#E1DAD2` line on each side;
- 8 px label-to-line gap;
- 16 px vertical spacing.

The divider records the boundary at entry and remains until the user leaves the chat. It does not disappear one row at a time as read receipts are sent.

A pending skeleton never counts as read. An incoming message becomes read when its final translated, authored, or final-failure fallback content is at least 50% visible.

Reaching the visual bottom is an explicit caught-up signal:

- mark every resolved incoming message through the latest as read, including messages crossed during a fast scroll;
- keep pending skeletons unread;
- while the user remains at bottom, mark each pending message when its real content appears.

Read-receipt OFF continues to emit no read event and disables partner read-state visibility. This design changes eligibility timing, not the privacy contract.

### 4. Stable Normal/Practice switching

Mode switching never navigates to the unread divider or a failed translation.

- At the visual bottom, remain at the bottom.
- Elsewhere, preserve the same top visible message and its relative vertical offset.
- Reflow may change bubble height below the anchor, but the anchored content may not move on screen.
- The private language marker and unread divider exist in both modes so their geometry remains stable.

An off-screen failed translation keeps its inline Retry in place. Blab does not auto-scroll to it.

### 5. Private learning-language timeline

The single cutoff is replaced by a per-chat, per-participant language timeline stored in Supabase. A language change affects only that participant and never changes the partner's timeline or displayed history.

Completed language packages remain linked to the learning language active for that viewer. They are never cleared merely because the viewer chooses another language.

Changing to Spanish adds a private timeline marker:

`Now learning Spanish`

Marker styling matches a date label:

- centered directly on the chat canvas;
- regular 12 px `#8C735F`;
- no lines, pill, outline, or icon;
- when a date label and language marker begin the same section, the date appears first, followed by the language marker, then the messages in that language;
- use exact visible gaps of 18 px from the previous bubble to the date label, 10 px from the date label to the language marker, and 10 px from the marker to the next bubble;
- when the marker sits between message bubbles rather than following a date label, keep 10 px of visible space above and below it;
- visible in both Normal and Practice;
- absent from the partner's chat and data stream.

At change time:

1. Completed and already visible results retain their old language above the marker.
2. Pending unseen work receives the new language revision and moves below the marker.
3. Old pending work is cancelled or allowed to finish only as discarded work.
4. Every message below the marker uses the new learning language in Practice.
5. A late result tagged with the old revision cannot replace the new result.

Switching languages repeatedly is supported. Each change creates one small private timeline event. Every message keeps one authoritative viewer-specific package for its assigned revision; the original message is never duplicated. If the user switches back to a previous language, completed old history remains untouched and only newly assigned/pending work uses the latest revision.

### 6. Translation storage and race safety

Supabase remains the durable source of truth for:

- original messages;
- viewer-specific prepared language packages;
- private learning-language timeline events;
- read events;
- attachment metadata and original media files.

Each prepared result is identified by message, viewer, target language, primary known language, source version, and learning-language revision. Completion is accepted only if those values still match the viewer's current assignment for that message.

Changing language increments the participant's revision before pending work is reassigned. German and Spanish results therefore cannot overwrite each other. A stale completion may be retained as an inert cache variant or discarded, but it cannot become the message's active package.

The phone may cache these records for speed and offline display, but phone memory is not authoritative. Local development uses the laptop's local Supabase; staging and production use their hosted Supabase environments with the same schema and behavior.

### 7. Offline chat photos

The private full-resolution original remains in Supabase Storage. At send time, Blab also creates a chat-sized preview and stores preview metadata with the attachment.

On each participant's device:

- every synced preview is written to app-private persistent storage;
- the full-resolution file is cached after it has been opened;
- reply thumbnails use the same persistent preview;
- reconnect refreshes temporary access links without changing message identity.

Offline display states:

1. **Cached full photo:** show and open full resolution normally.
2. **Cached preview only:** show normally in the bubble and allow opening it at available quality.
3. **No downloaded preview:** preserve the approved photo geometry and 12 px corners; show a neutral `#EAE6E0` surface with the muted photo asset, no visible text, red cross, error artwork, or dim overlay. Tap is disabled.

When connection returns, a missing preview loads automatically and replaces the placeholder without moving the message. A cache eviction never deletes the Supabase original or affects the other participant.

Preview files persist with locally retained chat history. Full-resolution files use a bounded least-recently-used cache so frequent photo chats cannot consume unbounded device storage.

Accessibility may announce `Photo unavailable offline` for the neutral placeholder even though no visible error copy is shown.

## Must-have acceptance criteria

### Prepared translation

- [ ] Given Bob sends at least 20 meaning-bearing messages while Alice is outside the chat, when Alice opens after preparation completes, then every message paints final on first appearance with no skeleton or late random reveal.
- [ ] Given several messages remain pending, when results become ready, then skeletons resolve oldest-first and one ready result does not wait for the full group.
- [ ] Given one result reaches final failure, then its original plus Retry appears without blocking successful later messages.
- [ ] Given Alice opens Normal and knows Bob's source language, then the authored message appears immediately without translation or skeleton.

### Unread and position

- [ ] Given Alice has unread messages, when she opens the chat, then the oldest unread anchors at the top beneath `{count} new messages`.
- [ ] A skeleton never produces a read record.
- [ ] Final content produces a read record only after crossing 50% visibility, unless Alice reaches bottom.
- [ ] Reaching bottom marks all resolved incoming messages through the latest as read; pending rows become read only after resolving while Alice remains caught up.
- [ ] Switching modes at bottom stays at bottom; switching elsewhere preserves the same visible message and offset.

### Language history

- [ ] Given completed German history, when Alice changes to Spanish, then completed German messages remain German above `Now learning Spanish` and later Practice messages use Spanish; at a date boundary the order is date → marker → messages.
- [ ] A pending unseen German message is reassigned to Spanish below the marker.
- [ ] A late German completion cannot overwrite the active Spanish result.
- [ ] Alice's marker and revision never appear for Bob.
- [ ] Repeated language switching does not duplicate original messages or clear completed historical packages.

### Offline photos

- [ ] A synced preview remains visible after airplane mode and app restart.
- [ ] A previously opened full photo opens full-screen offline.
- [ ] A preview-only photo opens offline at available quality.
- [ ] A never-downloaded preview uses the approved neutral placeholder without framework error UI.
- [ ] Reconnection automatically restores the preview without changing scroll position.

## Success measures

- Zero out-of-order visible translation reveals in the 20-message connected-device burst matrix.
- Zero read rows created for pending skeletons in automated and connected-device tests.
- Zero mode-switch anchor movement greater than 1 logical pixel for the anchored message in automated geometry checks.
- 100% of synced photo previews remain visible through the offline/restart device matrix.
- 100% of stale-language completion attempts are rejected by the revision contract.
- No message body, translation text, or photo content is added to analytics or diagnostic logs.

## Rollout and verification sequence

1. Add durable private language revisions, timeline events, and viewer-specific prepared packages.
2. Add delivery-triggered preparation and stale-completion rejection.
3. Add pending-group, unread-divider, read-eligibility, and scroll-anchor behavior.
4. Add persistent media previews and the offline photo fallback.
5. Verify locally with Alice/Bob on the Samsung Galaxy S25.
6. Apply the same schema and server behavior to staging, run the two-account matrix, then release through the normal production process.

## Open questions

No blocking product questions remain. Cache size, preview encoding, worker concurrency, retry scheduling, and stale-row cleanup are engineering decisions and must be recorded in the technical specification before implementation.
