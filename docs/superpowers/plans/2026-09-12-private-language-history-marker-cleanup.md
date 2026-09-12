# Private Language History Marker Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Localize private learning-history markers, collapse consecutive empty language eras visually, and prove historical quoted messages retain their own era.

**Architecture:** Keep the complete viewer-private timeline unchanged for message-era selection. Localize display names at the UI boundary and collapse only the marker events consumed at each visible message boundary. Preserve existing prepared-package and quoted-message era resolution.

**Tech Stack:** Flutter, Dart, generated ARB localization, Riverpod, Flutter widget tests.

---

### Task 1: Localize the complete marker

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_de.arb`
- Modify: `lib/l10n/app_es.arb`
- Modify: `lib/l10n/app_uk.arb`
- Modify: `lib/l10n/l10n.dart`
- Modify: generated files under `lib/l10n/generated/`
- Modify: `lib/features/chat/chat_screen.dart`
- Test: `test/app_localization_test.dart`

- [ ] **Step 1: Write the failing localization test**

```dart
testWidgets('learning-history marker is fully localized', (tester) async {
  const expectations = {
    'en': 'Now learning French',
    'de': 'Du lernst jetzt Französisch',
    'es': 'Ahora aprendes francés',
    'uk': 'Тепер ви вивчаєте французьку',
  };
  for (final entry in expectations.entries) {
    await tester.pumpWidget(_learningMarkerText(Locale(entry.key), 'fr'));
    expect(find.text(entry.value), findsOneWidget);
  }
});
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
flutter test test/app_localization_test.dart --plain-name 'learning-history marker is fully localized'
```

Expected: failure because the marker template and complete learning-language display-name resolver do not exist.

- [ ] **Step 3: Add marker copy and all eleven learning-language names**

Add `nowLearningLanguage` plus missing name keys for Dutch, French, Hindi, Italian, Portuguese, Tamil, and Turkish to all four ARB files. Keep the existing English, Ukrainian, German, and Spanish keys. Use natural grammatical forms in each complete marker.

Add this resolver to `lib/l10n/l10n.dart`:

```dart
String localizedLearningLanguageName(
  AppLocalizations localizations,
  String code,
) => switch (code) {
  'nl' => localizations.languageDutch,
  'fr' => localizations.languageFrench,
  'de' => localizations.languageGerman,
  'hi' => localizations.languageHindi,
  'it' => localizations.languageItalian,
  'pt' => localizations.languagePortuguese,
  'es' => localizations.languageSpanish,
  'ta' => localizations.languageTamil,
  'tr' => localizations.languageTurkish,
  'uk' => localizations.languageUkrainian,
  _ => localizations.languageEnglish,
};
```

Generate output:

```bash
flutter gen-l10n
```

- [ ] **Step 4: Render the marker through localization**

```dart
final language = localizedLearningLanguageName(context.l10n, languageCode);
Text(context.l10n.nowLearningLanguage(language), style: markerStyle)
```

- [ ] **Step 5: Run localization tests**

```bash
flutter test test/app_localization_test.dart
```

Expected: all localization tests pass.

- [ ] **Step 6: Commit the localization slice**

```bash
git add lib/l10n lib/features/chat/chat_screen.dart test/app_localization_test.dart
git commit -m "fix(chat): localize learning history markers"
```

### Task 2: Collapse empty visible eras

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Test: `test/chat_screen_primary_known_language_test.dart`

- [ ] **Step 1: Write failing marker-collapse tests**

```dart
testWidgets('consecutive language changes without messages show only the final marker', (tester) async {
  expect(find.text('Now learning Spanish'), findsNothing);
  expect(find.text('Now learning French'), findsOneWidget);
});

testWidgets('language changes separated by messages keep both markers', (tester) async {
  expect(find.text('Now learning Spanish'), findsOneWidget);
  expect(find.text('Now learning French'), findsOneWidget);
});
```

- [ ] **Step 2: Run the new tests and confirm the empty-era case fails**

```bash
flutter test test/chat_screen_primary_known_language_test.dart --plain-name 'consecutive language changes without messages show only the final marker'
flutter test test/chat_screen_primary_known_language_test.dart --plain-name 'language changes separated by messages keep both markers'
```

Expected: the first case exposes stacked markers; the second preserves meaningful eras.

- [ ] **Step 3: Collapse marker presentation only**

At each message boundary, consume every change up to that message but append only the last consumed marker:

```dart
({DateTime? when, String? language})? visibleChange;
while (languageChangeIndex < languageChanges.length &&
    !languageChanges[languageChangeIndex].when!.isAfter(m.sentAt)) {
  visibleChange = languageChanges[languageChangeIndex++];
}
if (visibleChange != null) {
  items.add(_LanguageTimelineItem(
    languageCode: visibleChange.language!,
    topPadding: startsNewDate ? 0 : 10,
    bottomPadding: (10 - messageTopGap).clamp(0, 10).toDouble(),
  ));
}
```

Apply the same last-event-only rule after the final loaded message. Do not alter the timeline used by `eraForMessage`.

- [ ] **Step 4: Run all marker/history tests**

```bash
flutter test test/chat_screen_primary_known_language_test.dart
```

Expected: collapse, history, mode, and geometry tests pass.

- [ ] **Step 5: Commit the collapse slice**

```bash
git add lib/features/chat/chat_screen.dart test/chat_screen_primary_known_language_test.dart
git commit -m "fix(chat): collapse empty language history markers"
```

### Task 3: Prove cross-era quoted messages

**Files:**
- Modify: `test/reply_translation_preview_test.dart`

- [ ] **Step 1: Add a cross-era fixture**

Configure the fake chat with a Tamil first era, a German second era, a Tamil result for the referenced message, and a German result for the new reply.

- [ ] **Step 2: Add the regression test**

```dart
testWidgets('reply quote keeps the referenced message era after a language switch', (tester) async {
  await tester.pumpWidget(_host(_crossEraReplyService()));
  await tester.pumpAndSettle();
  expect(find.text('இன்று வருகிறாயா?'), findsOneWidget);
  expect(find.text('Ja.'), findsOneWidget);
});
```

- [ ] **Step 3: Run reply-preview tests**

```bash
flutter test test/reply_translation_preview_test.dart
```

Expected: all pass without live translation calls.

- [ ] **Step 4: Commit the regression proof**

```bash
git add test/reply_translation_preview_test.dart
git commit -m "test(chat): cover historical reply language"
```

### Task 4: Product alignment and final verification

**Files:**
- Modify: `tasks/prd-blab.md`
- Modify: `tasks/progress.md`
- Create: `docs/qa/2026-09-12-private-language-history/README.md`

- [ ] **Step 1: Update binding acceptance criteria**

Extend US-046 with fully localized marker copy and last-visible-marker collapse for consecutive empty eras. State explicitly that all private revisions remain stored.

- [ ] **Step 2: Run the owner language-switch device matrix**

Verify on the production chat screen:

1. German history → Spanish message → French message shows both meaningful markers.
2. German → Spanish → French without an intervening message shows only French.
3. Replying to a German-era message keeps the German quote while the new body uses French.
4. Normal/Practice switching preserves markers and reading position.
5. Restart/reopen preserves history.
6. The partner sees none of the viewer's markers.
7. English, German, Spanish, and Ukrainian interfaces show localized markers.

- [ ] **Step 3: Record device evidence and update progress**

Document the matrix outcome without private message content. Mark Step 2.11b complete only after its full device rubric passes.

- [ ] **Step 4: Run final automated verification**

```bash
flutter test
flutter analyze
git diff --check
```

Expected: full suite green, analyzer clean, and no whitespace errors.

- [ ] **Step 5: Check current GitHub main for conflicts**

```bash
git fetch origin main
git merge-tree "$(git merge-base HEAD origin/main)" HEAD origin/main
```

Expected: no unresolved overlap.

- [ ] **Step 6: Commit documentation and push**

```bash
git add tasks/prd-blab.md tasks/progress.md docs/qa/2026-09-12-private-language-history/README.md
git commit -m "docs: verify private language history"
git push -u origin fix/private-language-history
```
