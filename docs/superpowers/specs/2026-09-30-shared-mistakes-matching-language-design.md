# Shared Mistakes for Matching Learning Languages

**Status:** Approved for implementation
**Date:** 2026-09-30  
**Related:** US-015, US-043, US-044; FR-13, FR-36, FR-38  
**Supersedes:** The former blanket rule in US-015, US-043, and FR-13 that recipients always receive clean correction output.

## Objective

Let two people learn collaboratively when they were learning the same language at the moment a message was sent. A recipient may see the author's inline correction marks only for messages that were created while both participants had the same learning language.

Success means the behavior is automatic, historically stable, race-safe, and visually reuses the existing correction treatment. Language changes must never rewrite the correction visibility of an older message.

## Product behavior

### Eligibility

- Blab evaluates eligibility once, in the database transaction that creates the message.
- `languages matched at send` is **true** only when the sender's and recipient's saved learning-language codes are equal.
- Every active chat participant already has a learning language; there is no missing-language state to handle.
- The saved result is permanent for that message. The app never recalculates it from the participants' current languages.
- Existing messages created before this feature ship are treated as **not matched**. Their current presentation remains unchanged.
- Text messages and photo captions follow the same rule.

### Presentation

- The author continues to see their own inline correction marks.
- In Practice mode, the recipient sees the same inline replaced/struck-through correction treatment when:
  1. the message contains a correction result; and
  2. `languages matched at send` is true.
- Correction explanations are not exposed in the UI for either participant. Struck-through text has no tap action.
- Corrected and unchanged words retain the existing standard word-help interaction.
- A low- or medium-confidence correction keeps the existing `Possible correction` treatment.
- When the languages did not match at send, the recipient continues to see the existing clean corrected learning-language line without correction marks.
- Correct writing, translations, and messages with no correction result remain unchanged.
- Normal mode remains unchanged.
- No setting, consent toggle, notice, notification, timeline event, or `Both learning …` label is added in v1.

### Language changes

- A language change affects only messages created after that change wins database ordering.
- If the message is committed first, its eligibility uses the previous learning languages.
- If the language change is committed first, the message uses the new learning languages.
- Switching away from a shared language stops sharing mistakes on later messages but never hides previously shared mistakes.
- Switching back to the same language makes later messages eligible again; messages from the non-matching period stay unchanged.

Example:

1. Both participants learn German. A German message with a mistake is shared with correction marks.
2. One participant changes to Spanish. The earlier German correction stays visible; later messages do not share correction marks.
3. They change back to German. Newly sent German mistakes are shared again; the Spanish-period messages remain unchanged.

## Architecture and data flow

1. Message creation reads and locks the two chat-membership language rows in a stable order.
2. The database compares the two language codes and stores one non-null `languages_matched_at_send` boolean on the message before the insert completes.
3. Existing per-viewer preparation continues to snapshot the learning language and revision and to create each participant's learning-aid package. Explanation data may remain in that internal package but is not presented by this feature.
4. Translation or correction completion uses the message's saved language/revision assignment. A later language change cannot replace the message's historical result.
5. Message loading exposes the saved boolean to the presentation layer.
6. Incoming Practice presentation shows inline correction marks only when the result mode is `correction` and the saved boolean is true.

This design deliberately avoids live monitoring, render-time comparison, and cross-reading another participant's private language timeline.

## Concurrency and recovery

- The database, not either phone, owns the eligibility decision.
- Stable row locking gives a concurrent message send and language change one authoritative order.
- A correction that finishes after a language change still uses the message's historical language assignment and saved eligibility.
- A stale completion for another language revision cannot become active. It is discarded or retried through the existing translation-recovery path.
- A race may briefly extend the existing loading state, but it must not show a wrong-language result, wrong correction visibility, or permanent failure.
- Offline/idempotent resend with the same message identity must preserve the original eligibility decision and must not recalculate it.
- Editing a message reprocesses its content but preserves its original `languages matched at send` value.

## Alternatives rejected

1. **Compare current languages whenever a bubble renders.** This is the least code, but old bubbles would gain or lose correction marks after a language change. Rejected because history would be unstable.
2. **Reconstruct both historical languages from private timelines on every read.** This avoids a new message field, but adds repeated joins, private-data boundary complexity, and more race/error paths. Rejected because the send-time answer is already known once.
3. **Share all correction marks regardless of language.** Rejected because a recipient should only see coaching for a language they were learning together with the author.

## Tech stack and affected boundaries

- Flutter/Dart presentation and message model.
- Supabase Postgres migration, insert-time eligibility snapshot, RLS-compatible message reads, and pgTAP coverage.
- Existing per-viewer prepared packages and translation worker remain the source of translated/corrected content.
- No new dependency, service, notification channel, or user setting.

Likely implementation areas:

- `supabase/migrations/` for the persisted eligibility field and atomic insert rule.
- `supabase/tests/database/` for history, concurrency ordering, authorization, and legacy-message coverage.
- `lib/shared/models/`, `lib/shared/data/`, and `lib/shared/services/` for message transport.
- `lib/features/chat/widgets/message_learning_content.dart` for incoming correction presentation.
- `test/` for message mapping and Practice presentation coverage.

## Code style

Keep the presentation decision pure and explicit:

```dart
bool shouldShowCorrectionMarks({
  required bool isOutgoing,
  required bool languagesMatchedAtSend,
  required LearningAidMode mode,
}) {
  return mode == LearningAidMode.correction &&
      (isOutgoing || languagesMatchedAtSend);
}
```

Database names use `snake_case`; Dart names use `lowerCamelCase`. Persisted product decisions are non-null and fail closed for legacy data.

## Commands

From the repository root:

```bash
dart format --output=none --set-exit-if-changed lib test
bash -n scripts/*.sh
flutter analyze
flutter test
git diff --check
scripts/local_test.sh reset
scripts/local_test.sh integration
```

## Testing strategy

### Database contracts

- Matching language codes save eligibility as true.
- Different language codes save eligibility as false.
- Legacy rows default to false.
- Concurrent message creation and language change produce one valid before/after ordering.
- Idempotent resend preserves the first eligibility value.
- Late results for a stale language revision cannot replace the assigned historical package.
- Both participants can read the eligibility value only through a message they are already authorized to read.

### Flutter contracts

- Outgoing corrections retain current inline treatment.
- Incoming Practice shows inline correction marks only for eligible messages.
- Tapping struck-through text does nothing for both outgoing and incoming corrections.
- Tapping a corrected word still opens the existing word-help popup.
- Incoming mismatched-language Practice remains a clean generated line.
- Normal mode is unchanged.
- Correct, `none`, loading, error, edited, and photo-caption states do not expose correction marks incorrectly.
- Reloading history or changing either participant's language does not alter rendered eligibility for existing messages.

### Manual acceptance flow

Use two connected participants:

1. Set both to German and send a clear German mistake; both must see correction marks.
2. Change one participant to Spanish and send another clear German mistake; only the author may see their correction marks.
3. Confirm the first message remains unchanged.
4. Switch back to German and send a new clear mistake; both must see correction marks again.
5. Delay correction completion, change language while it is pending, and confirm the final message uses its send-time language and visibility without a permanent error.

## Boundaries

### Always

- Decide eligibility atomically at message creation.
- Preserve the exact send-time decision across reloads, edits, retries, and later language changes.
- Keep prepared learning-aid data protected by existing message access rules.
- Fail closed for pre-feature messages.

### Ask first

- Making existing messages retroactively eligible.
- Adding a share-mistakes setting or consent flow.
- Adding notices, labels, timeline events, or notifications.
- Changing correction visibility in Normal mode.

### Never

- Recalculate an old message from current languages.
- Expose a participant's private language timeline to the other participant.
- Let a stale asynchronous result change eligibility or replace a historical language assignment.
- Show correction marks to a recipient whose learning language did not match at send time.

## Success criteria

- [ ] When both participants learn the same language at send time, both see the author's clear mistake with inline correction marks in Practice.
- [ ] Neither participant can open a correction explanation from struck-through text; corrected-word help remains available.
- [ ] When their learning languages differ at send time, only the author sees correction marks; the recipient retains the existing clean line.
- [ ] Later language changes never change an older message's correction visibility.
- [ ] Switching away and back creates the expected true/false/true sequence for newly sent messages.
- [ ] A concurrent send and language change resolve to one valid database order without wrong-language content or permanent translation failure.
- [ ] Late, retried, offline, edited, and legacy messages preserve the correct fail-safe decision.
- [ ] Normal mode, clean messages, translations, privacy rules, and existing language timeline markers remain unchanged.
- [ ] Database, Flutter, and two-participant manual acceptance coverage pass.

## Open questions

None. Any expansion beyond the boundaries above requires a new product decision.
