# Hindi and Tamil Reading Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one account-wide, native-default Reading script choice that changes cached Blab-generated Hindi and Tamil learning text between native script and English letters.

**Architecture:** Persist one constrained profile preference and expose it through one Riverpod state owner. A pure presentation helper converts complete tokenized Hindi/Tamil sentences to English letters while retaining native text for lookup and TTS. Existing Translation preferences rows, message renderers, correction paths, and reply previews consume the shared preference without changing translation requests or cache identities.

**Tech Stack:** Flutter/Dart 3, Riverpod, Supabase/PostgreSQL, pgTAP, Flutter localization, widget/unit/integration tests.

**Spec:** `docs/superpowers/specs/2026-09-14-hindi-tamil-reading-script-design.md`

---

### Task 1: Persist one account reading-script preference

**Files:**
- Create: `lib/shared/models/reading_script.dart`
- Create: `lib/shared/state/reading_script_state.dart`
- Create: `supabase/migrations/20260914000001_reading_script_preference.sql`
- Create: `supabase/tests/database/reading_script_preference.test.sql`
- Modify: `lib/shared/services/profile_service.dart`
- Modify: `test/profile_service_test.dart`
- Create: `test/reading_script_state_test.dart`

- [x] **Step 1: Write failing model, profile, state, and database tests**

Cover `native` default/fallback, `english_letters` parsing, profile row mapping, a self-only update, unchanged state on save failure, database default/constraint, authenticated update privilege, and account isolation.

```dart
expect(readingScriptFromWire(null), ReadingScript.native);
expect(readingScriptFromWire('english_letters'), ReadingScript.englishLetters);
expect(profile.readingScript, ReadingScript.englishLetters);
await container.read(readingScriptProvider.notifier).set(ReadingScript.englishLetters);
expect(container.read(readingScriptProvider).value, ReadingScript.englishLetters);
```

```sql
select is(
  (select reading_script from public.profiles where id = '00000000-0000-4000-8000-00000000000a'),
  'native',
  'reading script defaults to native'
);
select throws_ok(
  $$update public.profiles set reading_script = 'mixed' where id = '00000000-0000-4000-8000-00000000000a'$$,
  '23514'
);
```

- [x] **Step 2: Run focused tests and verify RED**

```bash
flutter test test/profile_service_test.dart test/reading_script_state_test.dart
supabase test db supabase/tests/database/reading_script_preference.test.sql
```

Expected: Flutter fails because the model/state/profile field do not exist; database fails because the migration has not added `reading_script`.

- [x] **Step 3: Implement the model, profile persistence, and state owner**

```dart
enum ReadingScript { native, englishLetters }

ReadingScript readingScriptFromWire(String? value) =>
    value == 'english_letters'
        ? ReadingScript.englishLetters
        : ReadingScript.native;

extension ReadingScriptWire on ReadingScript {
  String get wire => this == ReadingScript.englishLetters
      ? 'english_letters'
      : 'native';
}
```

Extend `UserProfile`, the profile select, and `ProfileService.updateReadingScript`. Implement `ReadingScriptNotifier` as an account-watching `AsyncNotifier<ReadingScript>` that keeps the old value on failure, writes the new value, updates state only after success, and invalidates `currentProfileProvider`.

```sql
alter table public.profiles
  add column reading_script text not null default 'native'
  constraint profiles_reading_script_check
    check (reading_script in ('native', 'english_letters'));
grant update (reading_script) on public.profiles to authenticated;
```

- [x] **Step 4: Re-run focused tests and verify GREEN**

Run the Step 2 commands. Expected: all focused Flutter and pgTAP assertions pass.

- [x] **Step 5: Commit the persistence slice**

```bash
git add lib/shared/models/reading_script.dart lib/shared/state/reading_script_state.dart lib/shared/services/profile_service.dart test/profile_service_test.dart test/reading_script_state_test.dart supabase/migrations/20260914000001_reading_script_preference.sql supabase/tests/database/reading_script_preference.test.sql docs/superpowers/plans/2026-09-14-hindi-tamil-reading-script.md
git commit -m "feat: persist reading script preference"
```

### Task 2: Build a complete-sentence script presentation boundary

**Files:**
- Create: `lib/features/chat/reading_script_presentation.dart`
- Create: `test/reading_script_presentation_test.dart`
- Modify: `lib/shared/models/message_token.dart`
- Modify: `test/message_token_test.dart`
- Modify: `lib/features/chat/widgets/word_popup.dart`
- Modify: `test/word_popup_test.dart`

- [x] **Step 1: Write failing presentation and popup tests**

Test Hindi and Tamil conversion, punctuation/emoji/Latin protected content, non-eligible languages, native mode, incomplete Romanization whole-sentence fallback, popup primary/secondary swap, and native TTS.

```dart
final result = presentReadingScript(
  text: 'வணக்கம்!',
  tokens: const [
    MessageToken(text: 'வணக்கம்', romanization: 'vanakkam', gloss: 'hello'),
    MessageToken(text: '!', isContent: false),
  ],
  languageCode: 'ta',
  readingScript: ReadingScript.englishLetters,
);
expect(result.text, 'vanakkam!');
expect(result.tokens.first.nativeText, 'வணக்கம்');
expect(result.usedEnglishLetters, isTrue);
```

For missing Romanization, expect the unchanged native text and `usedEnglishLetters == false`. Tap the Romanized visible word and expect the popup to show it at 22 px, native spelling at 13 px, and `speak:ta:வணக்கம்`.

- [x] **Step 2: Run focused tests and verify RED**

```bash
flutter test test/reading_script_presentation_test.dart test/message_token_test.dart test/word_popup_test.dart
```

Expected: FAIL because the presentation helper and native speech field are absent.

- [x] **Step 3: Implement complete-sentence conversion and native speech retention**

Add optional `nativeText` to `MessageToken`, defaulting to `text`. Implement:

```dart
ReadingScriptPresentation presentReadingScript({
  required String text,
  required List<MessageToken>? tokens,
  required String languageCode,
  required ReadingScript readingScript,
});
```

Return unchanged presentation unless language is `hi`/`ta`, preference is English letters, metadata exactly reproduces the native sentence, and every non-Latin content token has non-empty Romanization. Map convertible content tokens to visible Romanization, secondary native text, unchanged gloss, and native `nativeText`; keep non-content and already-Latin protected tokens exact. Update popup audio to speak `token.nativeText`.

- [x] **Step 4: Re-run focused tests and verify GREEN**

Run the Step 2 command. Expected: all focused presentation and popup tests pass.

- [x] **Step 5: Commit the rendering boundary**

```bash
git add lib/features/chat/reading_script_presentation.dart lib/shared/models/message_token.dart lib/features/chat/widgets/word_popup.dart test/reading_script_presentation_test.dart test/message_token_test.dart test/word_popup_test.dart
git commit -m "feat: render complete learning sentences in English letters"
```

### Task 3: Add the contextual Reading script settings row

**Files:**
- Modify: `lib/features/chat/translation_preferences_screen.dart`
- Modify: `test/translation_preferences_screen_test.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Regenerate: `lib/l10n/generated/`
- Modify: `test/app_localization_test.dart`

- [x] **Step 1: Write failing row, synchronization, and localization tests**

Test chat visibility for `hi`/`ta`, absence for `uk`, language-change disappearance, Profile absence/no chats, one-language contextual copy, both-language `Native scripts`, English-letters value, sheet selection, successful save, failed-save rollback, and all four interface locales.

```dart
expect(find.text('Reading script'), findsOneWidget);
expect(find.text('Hindi script'), findsOneWidget);
await tester.tap(find.text('Reading script'));
expect(find.text('English letters'), findsOneWidget);
```

- [x] **Step 2: Run focused tests and verify RED**

```bash
flutter test test/translation_preferences_screen_test.dart test/app_localization_test.dart
```

Expected: FAIL because the contextual row, choice sheet, and localization getters do not exist.

- [x] **Step 3: Implement the row with current settings visuals**

Watch `learningLanguageProvider(chatId)` in chat context and `chatListProvider` in Profile context. Derive zero, one, or both eligible language codes. Insert one `_PreferenceRow(label: context.l10n.readingScript, value: ...)` with the same dividers, arrow, type, spacing, and card as Gender form. Use the existing checkmarked modal-sheet structure; call `readingScriptProvider.notifier.set`, and show the existing save-failure snackbar on error.

Add localized keys for `readingScript`, `hindiScript`, `tamilScript`, `nativeScripts`, and `englishLetters`, then run:

```bash
flutter gen-l10n
```

- [x] **Step 4: Re-run focused tests and verify GREEN**

Run the Step 2 command. Expected: all row and localization tests pass.

- [x] **Step 5: Commit the settings flow**

```bash
git add lib/features/chat/translation_preferences_screen.dart test/translation_preferences_screen_test.dart lib/l10n test/app_localization_test.dart
git commit -m "feat: add contextual reading script settings"
```

### Task 4: Apply the preference to generated messages and replies

**Files:**
- Modify: `lib/features/chat/widgets/message_learning_content.dart`
- Modify: `lib/features/chat/widgets/inline_correction_text.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/chat/message_presentation.dart`
- Modify: `test/message_learning_content_test.dart`
- Modify: `test/inline_correction_text_test.dart`
- Modify: `test/message_presentation_test.dart`
- Modify: `test/chat_screen_primary_known_language_test.dart`

- [x] **Step 1: Write failing generated-content tests**

Cover Practice translations, Normal fallback translations, resolved grammatical alternatives, outgoing correction display, reply preview, authored/Original preservation, native and Romanized authored input, and a provider-call counter that remains unchanged when the preference toggles.

```dart
expect(find.text('aap kaise hain?'), findsOneWidget);
expect(find.text('आप कैसे हैं?'), findsNothing);
expect(translator.calls, 1);
await container.read(readingScriptProvider.notifier).set(ReadingScript.native);
expect(translator.calls, 1);
```

- [x] **Step 2: Run focused tests and verify RED**

```bash
flutter test test/message_learning_content_test.dart test/inline_correction_text_test.dart test/message_presentation_test.dart test/chat_screen_primary_known_language_test.dart
```

Expected: FAIL because message and reply paths ignore Reading script.

- [x] **Step 3: Route every eligible generated path through the pure helper**

Add `readingScript` to `MessageLearningContent` and to `resolveMessageDisplayText`/`resolveMessagePresentation`. Before creating `MessageText`, resolve the active form and its matching token set, then call `presentReadingScript`. Pass converted text/tokens to the rich renderer. Extend `InlineCorrectionText` with converted corrected-token metadata so corrected taps keep gloss/native audio. Watch the account preference once per chat bubble/reply and apply it only to generated target-language content; leave authored/Original and Chats-list previews unchanged.

- [x] **Step 4: Re-run focused tests and verify GREEN**

Run the Step 2 command. Expected: all generated-content and preservation tests pass with no additional translation call.

- [x] **Step 5: Commit the message integration**

```bash
git add lib/features/chat/widgets/message_learning_content.dart lib/features/chat/widgets/inline_correction_text.dart lib/features/chat/chat_screen.dart lib/features/chat/message_presentation.dart test/message_learning_content_test.dart test/inline_correction_text_test.dart test/message_presentation_test.dart test/chat_screen_primary_known_language_test.dart
git commit -m "feat: apply reading script across chat learning text"
```

### Task 5: Verify the full feature and deliver owner evidence

**Files:**
- Modify: `tasks/progress.md`
- Modify: `tasks/launch/backlog.md`
- Create: `docs/qa/2026-09-14-hindi-tamil-reading-script/README.md`
- Create: verified browser/emulator screenshots in `docs/qa/2026-09-14-hindi-tamil-reading-script/screenshots/`

- [ ] **Step 1: Run all automated gates**

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
supabase test db
git diff --check
```

Expected: formatting and analysis clean; all Flutter and database checks pass, with only documented integration-only skips.

- [ ] **Step 2: Run the real Alice/Bob matrix**

Reset/start the local stack, run Alice in the browser and Bob in the Android emulator against the same backend, and verify Hindi and Tamil in both directions. Check native default, English letters, immediate past-message switching, Profile/chat synchronization, row disappearance after another language is selected, word hierarchy/audio, exact native/Romanized authored text, and whole-sentence fallback.

- [ ] **Step 3: Capture and inspect evidence**

Save actual client screenshots showing the Reading script row/sheet plus Hindi and Tamil native/English-letter messages for Alice and Bob. Inspect every image for account identity, correct script, intact message fidelity, and no visual regression. Record exact pass/fail results; do not mark owner acceptance complete.

- [ ] **Step 4: Update trackers and commit verified work**

Remove `← in progress` only if the real-client done-when rubric passes; keep owner-facing checks open until explicit owner confirmation.

```bash
git add tasks/progress.md tasks/launch/backlog.md docs/qa/2026-09-14-hindi-tamil-reading-script
git commit -m "test: verify Hindi and Tamil reading scripts"
```

- [ ] **Step 5: Rebase safely, re-run the merged gate, and push `main`**

```bash
git fetch origin main
git rebase origin/main
flutter analyze
flutter test
git push origin main
```

Expected: `main` pushes without force, the worktree is clean, and the final screenshots are sent to the owner in the current Telegram topic.
