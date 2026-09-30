# Shared Mistakes for Matching Learning Languages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show incoming Practice correction marks only for messages created while both chat participants had the same Learning Language, without rewriting old history after language changes.

**Architecture:** Persist one server-owned `languages_matched_at_send` boolean on each message. A database trigger derives it atomically from the two locked membership rows; Flutter transports and caches the value, then uses it only to decide whether an incoming Practice correction renders inline marks. Existing rows default false and all current translation preparation, language revisions, Normal mode, and author correction behavior remain intact.

**Tech Stack:** Supabase Postgres/pgTAP, Flutter/Dart, Riverpod, Flutter widget tests

---

## File structure

- Create `supabase/migrations/20260930000001_shared_mistakes_matching_languages.sql`: persisted eligibility column and server-owned insert trigger.
- Create `supabase/tests/database/shared_mistakes_matching_languages.test.sql`: database contract for matching, mismatching, history, edits, and forged client values.
- Modify `lib/shared/models/message.dart`: add immutable message eligibility.
- Modify `lib/shared/data/chat_mappers.dart`: map server rows and fail closed for legacy/cache-shaped rows.
- Modify `lib/shared/services/local_chat_history_cache.dart`: preserve eligibility across offline reloads.
- Modify `lib/features/chat/widgets/message_learning_content.dart`: make the correction-mark decision explicit.
- Modify `lib/features/chat/chat_screen.dart`: pass message eligibility into presentation.
- Modify `test/chat_mappers_test.dart`, `test/local_chat_history_cache_test.dart`, and `test/message_learning_content_test.dart`: focused Flutter regressions.
- Modify `tasks/tech-spec.md` and `tasks/progress.md`: record the engineering decision and verified status.

### Task 1: Persist send-time matching-language eligibility

**Files:**
- Create: `supabase/migrations/20260930000001_shared_mistakes_matching_languages.sql`
- Create: `supabase/tests/database/shared_mistakes_matching_languages.test.sql`

- [ ] **Step 1: Write the failing database contract**

Create a pgTAP test that inserts two participants learning German, sends message A, changes one participant to Spanish, sends message B, changes back to German, and sends message C. Assert `true, false, true`; update A's body and assert A remains true; attempt to insert B with `languages_matched_at_send = true` and assert the database stores false.

```sql
select results_eq(
  $$
    select languages_matched_at_send
    from public.messages
    where id in (
      '73000000-0000-4000-8000-000000000001',
      '73000000-0000-4000-8000-000000000002',
      '73000000-0000-4000-8000-000000000003'
    )
    order by created_at, id
  $$,
  array[true, false, true],
  'eligibility follows the language match at each message insert'
);
```

- [ ] **Step 2: Run the database test to verify it fails**

Run:

```bash
scripts/local_test.sh reset
supabase test db supabase/tests/database/shared_mistakes_matching_languages.test.sql
```

Expected: FAIL because `messages.languages_matched_at_send` does not exist.

- [ ] **Step 3: Add the minimal migration**

Add the non-null legacy-safe field and a `BEFORE INSERT` trigger. The trigger must ignore any client-supplied value, lock both membership rows in stable `user_id` order, and derive true only for exactly two members with one distinct language.

```sql
alter table public.messages
  add column languages_matched_at_send boolean not null default false;

create or replace function public.set_message_language_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_count integer;
  v_language_count integer;
begin
  perform cm.user_id
  from public.chat_members cm
  where cm.chat_id = new.chat_id
  order by cm.user_id
  for share;

  select count(*), count(distinct cm.learning_language)
    into v_member_count, v_language_count
  from public.chat_members cm
  where cm.chat_id = new.chat_id;

  new.languages_matched_at_send :=
    v_member_count = 2 and v_language_count = 1;
  return new;
end;
$$;
```

Create the trigger before the existing preparation trigger, revoke direct function execution, and leave update permissions unchanged so clients cannot edit the field.

- [ ] **Step 4: Run the focused and complete database contracts**

Run:

```bash
scripts/local_test.sh reset
supabase test db supabase/tests/database/shared_mistakes_matching_languages.test.sql
supabase test db
```

Expected: focused PASS and full pgTAP suite PASS.

- [ ] **Step 5: Commit the database contract**

```bash
git add supabase/migrations/20260930000001_shared_mistakes_matching_languages.sql \
  supabase/tests/database/shared_mistakes_matching_languages.test.sql
git commit -m "feat: persist matching-language message eligibility"
```

### Task 2: Carry eligibility through message mapping and offline history

**Files:**
- Modify: `lib/shared/models/message.dart`
- Modify: `lib/shared/data/chat_mappers.dart`
- Modify: `lib/shared/services/local_chat_history_cache.dart`
- Modify: `test/chat_mappers_test.dart`
- Modify: `test/local_chat_history_cache_test.dart`

- [ ] **Step 1: Write failing mapper and cache tests**

Add a mapper test for a row with `languages_matched_at_send: true`, a legacy-row test with the key absent, and an offline-cache round trip that starts with true.

```dart
expect(mapped.languagesMatchedAtSend, true);
expect(legacy.languagesMatchedAtSend, false);
expect(restored.single.languagesMatchedAtSend, true);
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
flutter test test/chat_mappers_test.dart test/local_chat_history_cache_test.dart
```

Expected: FAIL because `Message.languagesMatchedAtSend` does not exist.

- [ ] **Step 3: Add the immutable model field and row mapping**

Add a legacy-safe constructor default and preserve it in `copyWith`.

```dart
this.languagesMatchedAtSend = false,

final bool languagesMatchedAtSend;
```

Map both full messages and reply-preview rows with:

```dart
languagesMatchedAtSend:
    row['languages_matched_at_send'] as bool? ?? false,
```

- [ ] **Step 4: Persist the field in offline history**

Write `languagesMatchedAtSend` in `_messageToJson` for the message and reply preview; read it with `as bool? ?? false` in `_messageFromJson`. Keep old caches valid and false by default.

- [ ] **Step 5: Run focused tests and commit**

Run:

```bash
dart format lib/shared/models/message.dart lib/shared/data/chat_mappers.dart \
  lib/shared/services/local_chat_history_cache.dart test/chat_mappers_test.dart \
  test/local_chat_history_cache_test.dart
flutter test test/chat_mappers_test.dart test/local_chat_history_cache_test.dart
```

Expected: PASS.

```bash
git add lib/shared/models/message.dart lib/shared/data/chat_mappers.dart \
  lib/shared/services/local_chat_history_cache.dart test/chat_mappers_test.dart \
  test/local_chat_history_cache_test.dart
git commit -m "feat: retain shared-correction eligibility in history"
```

### Task 3: Render eligible incoming corrections in Practice

**Files:**
- Modify: `lib/features/chat/widgets/message_learning_content.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `test/message_learning_content_test.dart`

- [ ] **Step 1: Write failing presentation tests**

Keep the existing mismatched-recipient test as the false case. Add an eligible-recipient case using the same correction fixture and assert the inline correction exists.

```dart
await tester.pumpWidget(host(
  const AsyncData(correction),
  authoredText: 'What is you doing?',
  languagesMatchedAtSend: true,
));

expect(find.byKey(const ValueKey('inline-correction')), findsOneWidget);
```

Also assert Normal mode remains clean even when eligibility is true.

- [ ] **Step 2: Run the focused widget test to verify it fails**

Run:

```bash
flutter test test/message_learning_content_test.dart
```

Expected: FAIL because the widget has no incoming eligibility input and still gates marks on `isOutgoing`.

- [ ] **Step 3: Make the presentation decision explicit**

Add `languagesMatchedAtSend` to `MessageLearningContent` with a false default for isolated fixtures. Replace the author-only gate with:

```dart
final showCorrectionMarks =
    value.mode == LearningAidMode.correction &&
    (isOutgoing || languagesMatchedAtSend);
```

Use `showCorrectionMarks` only in the existing Practice rich-rendering branch. Do not alter Normal, translation, none, loading, error, or form-alternative branches.

- [ ] **Step 4: Pass the message snapshot from the chat bubble**

In `chat_screen.dart`, pass:

```dart
languagesMatchedAtSend: message.languagesMatchedAtSend,
```

Because text and caption bubbles share this builder, photo captions receive the same behavior without a second branch.

- [ ] **Step 5: Run focused tests and commit**

Run:

```bash
dart format lib/features/chat/widgets/message_learning_content.dart \
  lib/features/chat/chat_screen.dart test/message_learning_content_test.dart
flutter test test/message_learning_content_test.dart
```

Expected: PASS for outgoing, eligible incoming, mismatched incoming, and Normal-mode cases.

```bash
git add lib/features/chat/widgets/message_learning_content.dart \
  lib/features/chat/chat_screen.dart test/message_learning_content_test.dart
git commit -m "feat: share corrections for matching learners"
```

### Task 4: Record the decision and run complete verification

**Files:**
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`

- [ ] **Step 1: Record the resolved engineering decision**

Revise Resolved Decision 19 to state that the database snapshots matching-language eligibility at message creation, eligible incoming Practice messages show marks with viewer-specific explanations, and legacy/mismatched messages remain clean.

- [ ] **Step 2: Run source and Flutter gates**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test
bash -n scripts/*.sh
flutter analyze
flutter test
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 3: Run local backend and integration gates**

Run:

```bash
scripts/local_test.sh reset
supabase test db
scripts/local_test.sh integration
```

Expected: migrations apply, all pgTAP contracts pass, and local integration passes with only documented environment/provider skips.

- [ ] **Step 4: Exercise the two-participant language sequence**

With Alice and Bob, verify German/German → German/Spanish → German/German produces shared/clean/shared incoming correction presentation while the first two historical messages remain unchanged. Record evidence before marking Step 2.16 complete; automated checks alone do not close it.

- [ ] **Step 5: Update progress and commit verification records**

Keep Step 2.16 in progress if the real-client sequence cannot be completed. Otherwise remove `← in progress`, mark `[x]`, and add the observed verification counts and evidence location to the changelog.

```bash
git add tasks/tech-spec.md tasks/progress.md
git commit -m "docs: record shared-mistakes verification"
```
