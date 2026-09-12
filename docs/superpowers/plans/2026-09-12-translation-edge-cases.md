# Translation Edge Cases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ambiguous short replies and abbreviation-plus-name messages translate reliably, stop tone changes from reloading history, and show author-aware unsupported-language guidance.

**Architecture:** Keep the existing provider loop, two-attempt ceiling, translation cache, and grammatical-form correction window. Enrich the server-only participant context with the message author's primary known language, add a bounded source-evidence retry gate around the existing provider contract, remove the tone-specific forced-refresh path, and select unsupported copy from the bubble's author direction.

**Tech Stack:** Flutter/Dart, Riverpod, Flutter localization, Deno/TypeScript, Supabase/PostgreSQL, pgTAP

---

### Task 1: Supply source-language evidence to the translator

**Files:**
- Create: `supabase/migrations/20260912000002_translation_author_language_context.sql`
- Modify: `supabase/tests/database/message_preparation_worker.test.sql`
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/index.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [ ] **Step 1: Add a failing pgTAP assertion for the author's primary known language**

Increase the plan count in `message_preparation_worker.test.sql`, set the sender fixture's `primary_known_language` to `en`, and assert that a partner-viewer job receives it:

```sql
update public.profiles
set primary_known_language = 'en'
where id = '00000000-0000-4000-8000-00000000000a';

select is(
  public.request_message_translation_job(
    (select id from claimed_jobs
     where viewer_id = '00000000-0000-4000-8000-00000000000c')
  ) #>> '{formContext,authorPrimaryKnownLanguage}',
  'en',
  'translation preparation supplies the message author primary known language'
);
```

- [ ] **Step 2: Run the database test and verify RED**

Run:

```bash
supabase test db supabase/tests/database/message_preparation_worker.test.sql
```

Expected: FAIL because `formContext.authorPrimaryKnownLanguage` is absent.

- [ ] **Step 3: Add the forward SQL migration**

Copy the current `request_message_translation_job(uuid)` body from `20260829000003_message_preparation_worker.sql` into a new `create or replace function`. Preserve every status, cache, authorization, context, and job check. Add only:

```sql
v_author_primary_known_language text;
```

After loading `v_message`, resolve the author profile:

```sql
select p.primary_known_language
into v_author_primary_known_language
from public.profiles p
where p.id = v_message.sender_id;
```

Add the internal field to `v_form_context`:

```sql
'authorPrimaryKnownLanguage',
case
  when v_author_primary_known_language in
    ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk')
  then v_author_primary_known_language
  else null
end
```

Retain the existing function owner, revoke, and service-role grant statements.

- [ ] **Step 4: Parse and prompt with the author hint**

Extend `FormParticipantContext` compatibly:

```ts
authorPrimaryKnownLanguage?: string | null;
```

In `formContextFrom`, accept only a key in `LANG_NAMES`; return `null` for missing or invalid legacy values. In `systemPrompt`, add this sentence only when the hint exists:

```ts
const authorLanguageHint = formContext?.authorPrimaryKnownLanguage == null
  ? ""
  : ` The author's primary known language is ${
    LANG_NAMES[formContext.authorPrimaryKnownLanguage]
  } (${formContext.authorPrimaryKnownLanguage}); use it only as a final tie-breaker when the current text is genuinely ambiguous and compatible with that language.`;
```

Change the recent-context instruction so same-sender messages may resolve the source language of an ambiguous short current utterance, while context remains forbidden as translation input.

- [ ] **Step 5: Add and run focused contract tests**

Add assertions that `providerMessages`:

```ts
assert(system.includes("same sender"), "same-sender context is source evidence");
assert(system.includes("primary known language is English (en)"), "author hint included");
assert(system.includes("translate only the current user message"), "context is not input");
```

Run:

```bash
deno test --filter "source evidence" supabase/functions/translate-message/contract_test.ts
supabase test db supabase/tests/database/message_preparation_worker.test.sql
```

Expected: PASS.

- [ ] **Step 6: Commit the source-evidence contract**

```bash
git add supabase/migrations/20260912000002_translation_author_language_context.sql supabase/tests/database/message_preparation_worker.test.sql supabase/functions/translate-message/contract.ts supabase/functions/translate-message/index.ts supabase/functions/translate-message/contract_test.ts
git commit -m "fix: add translation source-language evidence"
```

### Task 2: Retry suspicious short replies and abbreviation-plus-name results

**Files:**
- Modify: `supabase/functions/translate-message/contract.ts`
- Modify: `supabase/functions/translate-message/index.ts`
- Test: `supabase/functions/translate-message/contract_test.ts`

- [ ] **Step 1: Write failing source-evidence retry tests**

Export a wished-for `sourceEvidenceNeedsRetry` API and test these cases separately:

```ts
const noAsGerman: TranslationResult = {
  mode: "none",
  sourceLang: "de",
  translation: "No",
  interfaceText: "No",
  explanation: null,
  confidence: null,
  tokens: [],
  formAlternatives: null,
};

assert(sourceEvidenceNeedsRetry({
  result: noAsGerman,
  sourceText: "No",
  targetLang: "de",
  context: [{ speaker: "partner", text: "I am not coming today" }],
  formContext: {
    viewerName: "Bob",
    partnerName: "Alice",
    messageAuthor: "partner",
    viewerForm: null,
    partnerForm: null,
    tone: "informal",
    authorPrimaryKnownLanguage: "en",
  },
}), "No misclassified as German must retry");

assert(!sourceEvidenceNeedsRetry({
  result: {
    ...noAsGerman,
    translation: "Nein",
    interfaceText: "Nein",
  },
  sourceText: "Nein",
  targetLang: "de",
  context: [],
  formContext: {
    viewerName: "Alice",
    partnerName: "Bob",
    messageAuthor: "viewer",
    viewerForm: null,
    partnerForm: null,
    tone: "informal",
    authorPrimaryKnownLanguage: "de",
  },
}), "genuine target-language text must remain accepted");
```

Add another failing test where `sourceLang=other`, the text is `OMG Nastia`, and `Nastia` is the supplied partner name. Add negative tests for `你好 Nastia`, an unknown capitalized token, URLs, emoji-only text, and long prose.

- [ ] **Step 2: Run the focused tests and verify RED**

```bash
deno test --filter "source evidence retry" supabase/functions/translate-message/contract_test.ts
```

Expected: FAIL because `sourceEvidenceNeedsRetry` does not exist.

- [ ] **Step 3: Implement the bounded evidence predicate**

Implement one pure helper with this signature:

```ts
export function sourceEvidenceNeedsRetry({
  result,
  sourceText,
  targetLang,
  context = [],
  formContext,
}: {
  result: TranslationResult;
  sourceText: string;
  targetLang: string;
  context?: TranslationContextMessage[];
  formContext?: FormParticipantContext;
}): boolean;
```

It returns `true` only for:

1. a short plain one-word/utterance result that claims `sourceLang=targetLang`, remains unchanged in `mode=none`, and has conflicting same-sender or author-primary-language evidence; or
2. `sourceLang=other` when the input contains a supplied participant name plus one of the existing supported chat abbreviations (`omg`, `ttyl`, `brb`, `lol`, `lmao`, `idk`, `fyi`, `wtf`).

Use Unicode-aware token boundaries. Remove supplied participant names before matching abbreviations. Do not treat capitalization alone as a name and do not accept unsupported-script residue.

- [ ] **Step 4: Strengthen first-attempt and retry guidance**

In `systemPrompt`, state that a meaning-bearing abbreviation combined with a supplied participant name remains supported language and must be translated naturally. Update `sourceClassificationRetryGuidance` to mention same-sender context and the author hint, without hardcoding `No`, `Nastia`, or a target language.

- [ ] **Step 5: Wire the helper into the existing provider loop**

Before `translationNeedsRetry`, call:

```ts
if (sourceEvidenceNeedsRetry({
  result: candidate,
  sourceText: text,
  targetLang,
  context,
  formContext,
})) {
  previousSourceClassificationConflict = true;
  lastFailedSourceLang = candidate.sourceLang;
  providerFailure = `${credential.provider}_source_evidence_conflict`;
  continue;
}
```

This uses the existing second attempt; it must not add a third attempt or touch the normal successful path.

- [ ] **Step 6: Verify GREEN and the eleven-language matrix**

Add table-driven prompt/contract cases for every supported target code. They must prove that abbreviation-plus-name input stays on the supported translation path without asserting one exact stylistic phrase. Run:

```bash
deno test supabase/functions/translate-message/contract_test.ts
deno check supabase/functions/translate-message/index.ts
```

Expected: PASS.

- [ ] **Step 7: Commit translation classification hardening**

```bash
git add supabase/functions/translate-message/contract.ts supabase/functions/translate-message/contract_test.ts supabase/functions/translate-message/index.ts
git commit -m "fix: use context for ambiguous translation sources"
```

### Task 3: Make tone changes future-only

**Files:**
- Modify: `lib/features/chat/state/grammatical_form_preferences_state.dart`
- Modify: `lib/features/chat/state/message_translations_state.dart`
- Modify: `test/translation_preferences_screen_test.dart`
- Modify: `test/message_translations_state_test.dart`
- Modify: `test/account_private_state_test.dart`

- [ ] **Step 1: Change tests first**

Rename the tone test to `saving tone invalidates preferences without refreshing completed translations`. Keep assertions for persistence and preferences rebuilding, but require no translation revision.

Replace the existing message-state revision test with a regression test that loads a cached translation, saves a new tone, calls `ensure` again, and asserts the cached text remains present with zero fresh translation calls. Remove the account-state test's revision-only setup/assertions; its other account-private state checks remain.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
flutter test test/translation_preferences_screen_test.dart test/message_translations_state_test.dart test/account_private_state_test.dart
```

Expected: FAIL because saving tone still bumps the global revision and visible entries still force `translateFresh`.

- [ ] **Step 3: Remove the tone refresh path**

Change the save action to:

```dart
final saveConversationToneProvider = Provider<SetConversationToneFn>((ref) {
  return (chatId, tone) async {
    await ref.read(setConversationToneFnProvider)(chatId, tone);
    ref.invalidate(grammaticalFormPreferencesProvider(chatId));
  };
});
```

Delete `grammaticalFormPreferenceRevisionProvider`, `forceTranslateMessageFnProvider`, `_formPreferenceRevision`, `_forceFormRefresh`, the build-time revision watcher, the cache-bypass branch, and the `translateFresh` selection. Keep the normal cache and serialized live-translation path unchanged.

- [ ] **Step 4: Verify GREEN and gender non-regression**

```bash
flutter test test/translation_preferences_screen_test.dart test/message_translations_state_test.dart test/account_private_state_test.dart test/form_correction_state_test.dart test/form_correction_chat_test.dart
```

Expected: PASS; form-correction-window behavior remains unchanged.

- [ ] **Step 5: Commit future-only tone behavior**

```bash
git add lib/features/chat/state/grammatical_form_preferences_state.dart lib/features/chat/state/message_translations_state.dart test/translation_preferences_screen_test.dart test/message_translations_state_test.dart test/account_private_state_test.dart
git commit -m "fix: keep completed translations after tone changes"
```

### Task 4: Show author-aware unsupported-language guidance

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/app_localizations.dart`
- Regenerate: `lib/l10n/generated/app_localizations_en.dart`
- Regenerate: `lib/l10n/generated/app_localizations_de.dart`
- Regenerate: `lib/l10n/generated/app_localizations_es.dart`
- Regenerate: `lib/l10n/generated/app_localizations_uk.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Test: `test/bubble_expand_test.dart`

- [ ] **Step 1: Write failing incoming/outgoing widget tests**

Split the current unsupported-source test into two cases. Assert incoming Chinese shows:

```dart
expect(
  find.text('Blab can’t translate this language yet. Showing the original.'),
  findsOneWidget,
);
```

Assert outgoing Chinese retains the actionable learning-language copy and both cases keep the authored Chinese text visible with no translation Retry action.

- [ ] **Step 2: Run the widget tests and verify RED**

```bash
flutter test test/bubble_expand_test.dart --plain-name "unsupported"
```

Expected: FAIL because both directions use `unsupportedLanguageHint`.

- [ ] **Step 3: Add localized incoming copy and choose by author**

Add `unsupportedIncomingLanguageHint` to all four interface-language ARB files. Use these approved/localized values:

```text
en: Blab can’t translate this language yet. Showing the original.
de: Blab kann diese Sprache noch nicht übersetzen. Das Original wird angezeigt.
es: Blab aún no puede traducir este idioma. Se muestra el original.
uk: Blab поки не може перекласти цю мову. Показуємо оригінал.
```

Run `flutter gen-l10n`. In `chat_screen.dart`, select:

```dart
text: isOut
    ? context.l10n.unsupportedLanguageHint(
        _languageNameForCode(languageCode),
      )
    : context.l10n.unsupportedIncomingLanguageHint,
```

- [ ] **Step 4: Verify GREEN**

```bash
flutter test test/bubble_expand_test.dart test/message_presentation_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit author-aware guidance**

```bash
git add lib/l10n lib/features/chat/chat_screen.dart test/bubble_expand_test.dart
git commit -m "fix: tailor unsupported guidance to message author"
```

### Task 5: Full verification and real-client acceptance

**Files:**
- Modify: `docs/superpowers/plans/2026-09-12-translation-edge-cases.md` checkboxes only
- Modify: `tasks/progress.md` only after acceptance passes

- [ ] **Step 1: Run complete automated verification**

```bash
flutter test
flutter analyze
deno test --allow-read supabase/functions/translate-message/automatic_forms_test.ts supabase/functions/translate-message/cache_migration_test.ts supabase/functions/translate-message/contract_test.ts supabase/functions/translate-message/provider_test.ts
deno check supabase/functions/translate-message/index.ts
deno fmt --check supabase/functions/translate-message
supabase test db
git diff --check
```

Expected: zero failures and no formatting errors.

- [ ] **Step 2: Run Alice/Bob acceptance on the real clients**

Use Alice in the Flutter web browser and Bob in the Android emulator in their shared test chat. Verify and capture screenshots for:

1. English context followed by Alice sending `No`; Bob sees `Nein` in German.
2. `OMG Nastia` translates naturally for German, Ukrainian, and Hindi targets; the remaining target codes are covered by the automated matrix.
3. Changing tone does not reload any existing bubble; the next newly translated message uses the new tone.
4. Incoming Chinese shows the neutral original-visible copy; outgoing Chinese shows the actionable `Try <learning language>` copy.

- [ ] **Step 3: Record completion only from acceptance evidence**

Update `tasks/progress.md` with the automated counts and the real-client pass/fail result. Do not mark the work complete if any Alice/Bob scenario fails.

- [ ] **Step 4: Commit final verification records**

```bash
git add docs/superpowers/plans/2026-09-12-translation-edge-cases.md tasks/progress.md
git commit -m "test: verify translation edge cases"
```

- [ ] **Step 5: Integrate and publish**

Review the complete diff against `docs/superpowers/specs/2026-09-12-translation-edge-cases-design.md`, merge the isolated branch into `main`, rerun the focused smoke checks, and push `main` only if every automated and real-client gate is green.
