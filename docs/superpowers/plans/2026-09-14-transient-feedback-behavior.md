# Transient Feedback Behavior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Blab's language-change Snackbar compact, target-locale-correct, and dismissible on navigation without interfering with its Undo action.

**Architecture:** Keep `showAppSnack` as the single shared presenter, add a route observer that dismisses visible feedback on navigation, and build language-change copy from the saved target locale through a pure localization helper. Preserve the existing visual treatment except for removing the redundant close icon.

**Tech Stack:** Flutter, Dart, `ScaffoldMessenger`, `go_router`, generated Flutter localizations, `flutter_test`

---

### Task 1: Lock shared Snackbar behavior

**Files:**
- Create: `test/app_messenger_test.dart`
- Modify: `lib/app/app_messenger.dart`
- Modify: `lib/app/theme.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Write failing duration and close-icon tests**

Create widget tests that show a passive Snackbar and an actionable Snackbar through `showAppSnack`, inspect their `duration`, and assert the shared theme does not request a close icon:

```dart
expect(passive.duration, const Duration(milliseconds: 2500));
expect(actionable.duration, const Duration(seconds: 4));
expect(blabTheme.snackBarTheme.showCloseIcon, isFalse);
```

- [ ] **Step 2: Run the focused test and verify the expected failures**

Run:

```bash
flutter test test/app_messenger_test.dart
```

Expected: FAIL because passive feedback is still 2200 ms and the theme still enables the close icon.

- [ ] **Step 3: Implement the shared timing and no-close rule**

Define shared constants and update the presenter:

```dart
const passiveAppSnackDuration = Duration(milliseconds: 2500);
const actionableAppSnackDuration = Duration(seconds: 4);

duration: duration ??
    (action == null ? passiveAppSnackDuration : actionableAppSnackDuration),
```

Set `SnackBarThemeData.showCloseIcon` to `false` without changing the existing floating behavior.

- [ ] **Step 4: Write a failing navigation-dismissal test**

Add a widget test with `AppSnackRouteObserver` that shows feedback, pushes another route, and expects the message to be gone. Also assert a normal tap on the current route leaves the Snackbar visible.

- [ ] **Step 5: Run the focused test and verify the expected failure**

Run:

```bash
flutter test test/app_messenger_test.dart
```

Expected: FAIL because no route observer exists yet.

- [ ] **Step 6: Implement route-aware dismissal**

Add a shared dismissal function and observer:

```dart
void dismissAppSnack() => appMessengerKey.currentState?.hideCurrentSnackBar();

class AppSnackRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    dismissAppSnack();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    dismissAppSnack();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    dismissAppSnack();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    dismissAppSnack();
  }
}
```

Register one observer with the root `GoRouter`. Keep `showAppSnack` after the interface-language route pop, so its success feedback appears on the destination and only a later navigation dismisses it.

- [ ] **Step 7: Run focused tests and verify green**

Run:

```bash
flutter test test/app_messenger_test.dart
```

Expected: PASS.

### Task 2: Localize language-change feedback from the target locale

**Files:**
- Create: `test/interface_language_feedback_test.dart`
- Modify: `lib/l10n/l10n.dart`
- Modify: `lib/features/profile/interface_language_screen.dart`

- [ ] **Step 1: Write a failing four-locale feedback test**

Define the expected target-locale pairs:

```dart
const expected = {
  'en': ('Switched to English', 'Undo'),
  'de': ('Zu Deutsch gewechselt', 'Rückgängig'),
  'es': ('Idioma cambiado a Español', 'Deshacer'),
  'uk': ('Мову змінено на Українська', 'Скасувати'),
};
```

For every supported interface locale, call `interfaceLanguageChangeFeedback(code)` and compare its message and action label to the expected pair.

- [ ] **Step 2: Run the focused test and verify the expected failure**

Run:

```bash
flutter test test/interface_language_feedback_test.dart
```

Expected: FAIL because the target-locale feedback helper does not exist.

- [ ] **Step 3: Implement target-locale feedback**

Add a pure helper in `lib/l10n/l10n.dart`:

```dart
({String message, String actionLabel}) interfaceLanguageChangeFeedback(
  String languageCode,
) {
  final localizations = lookupAppLocalizations(Locale(languageCode));
  return (
    message: localizations.switchedToLanguage(
      localizedInterfaceLanguageName(localizations, languageCode),
    ),
    actionLabel: localizations.undo,
  );
}
```

Use this result after the save succeeds instead of reading the departing route's localization context.

- [ ] **Step 4: Run both focused test files and verify green**

Run:

```bash
flutter test test/app_messenger_test.dart test/interface_language_feedback_test.dart
```

Expected: PASS.

### Task 3: Record and verify the product behavior

**Files:**
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`
- Create: `docs/qa/2026-09-14-transient-feedback/README.md`
- Create: `docs/qa/2026-09-14-transient-feedback/screenshots/*`

- [ ] **Step 1: Record the resolved shared-feedback rule**

Add the approved timing, dismissal, navigation, and target-locale ownership rule to the technical decisions. Add an in-progress changelog entry without marking an existing launch step complete.

- [ ] **Step 2: Run automated verification**

Run:

```bash
dart format --output=none --set-exit-if-changed lib/app/app_messenger.dart lib/app/router.dart lib/app/theme.dart lib/l10n/l10n.dart lib/features/profile/interface_language_screen.dart test/app_messenger_test.dart test/interface_language_feedback_test.dart
flutter analyze
flutter test
```

Expected: formatting clean, analysis clean, and the full suite passes.

- [ ] **Step 3: Run the device language matrix**

On the Android emulator, switch into English, German, Spanish, and Ukrainian. For each resulting Snackbar, verify the target-locale message and action, no close icon, no clipping or overlap, natural wrapping, swipe dismissal, 4-second timeout, and dismissal on the next navigation.

- [ ] **Step 4: Capture and review screenshots**

Capture one real Android screenshot per interface locale, preserve the canonical files under the QA directory, and record each result as `Pass`, `Wrong copy`, `English leak`, `Layout issue`, or `Broken`. Run the UI/UX review and the Impeccable detector once over the changed UI targets.

- [ ] **Step 5: Send the review packet**

Send a numbered four-image packet to the current topic and wait for owner approval before committing or pushing the implementation changes.
