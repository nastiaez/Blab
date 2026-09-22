# Invite Error Action Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate resolver exit from recovery, and keep each Retry visibly attached to the error it resolves without changing localization resources.

**Architecture:** Add invite-owned close and text-action components. Resolver error states use a top-right close action that routes directly to Chats; only the temporary failure also shows a centered Retry text action. The invite-creation failure splits its existing localized message into error and recovery phrases, makes that recovery phrase tappable in a wrapping group directly below the card, and hides unrelated failure-time content.

**Tech Stack:** Flutter, Material buttons, Riverpod, `flutter_test`

---

### Task 1: Lock the resolver hierarchy with failing widget tests

**Files:**
- Modify: `test/invite_resolver_recovery_test.dart`

- [ ] **Step 1: Add terminal close-action assertions**

Extend the invalid-link and already-claimed tests to require a close `IconButton`, assert its tap target is at least 48 dp, and assert **Go to chats** is absent. Tap close and verify routing to Chats.

```dart
final close = find.byKey(const ValueKey('invite-close'));
expect(close, findsOneWidget);
expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
expect(find.text('Go to chats'), findsNothing);
await tester.tap(close);
await tester.pumpAndSettle();
expect(find.text('chats'), findsOneWidget);
```

- [ ] **Step 2: Add temporary-failure hierarchy assertions**

Mount a failing lookup and assert the explanatory sentence and **Go to chats** are absent. Require one centered **Retry** `TextButton`, no `FilledButton`, a 48 dp tap target, and the shared top-right close action.

```dart
await _mount(
  tester,
  lookup: (_) async => throw Exception('temporary outage'),
);
await tester.pumpAndSettle();
final retry = find.widgetWithText(TextButton, 'Retry');
expect(retry, findsOneWidget);
expect(find.byType(FilledButton), findsNothing);
expect(find.text('Try again to continue.'), findsNothing);
expect(find.text('Go to chats'), findsNothing);
expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
```

- [ ] **Step 3: Run the focused test and verify RED**

Run:

```bash
flutter test test/invite_resolver_recovery_test.dart
```

Expected: FAIL because the current states still show the old filled and stacked actions.

### Task 2: Lock inline Retry proximity with a failing widget test

**Files:**
- Modify: `test/new_chat_screen_test.dart`

- [ ] **Step 1: Add the failure-content assertions**

In the failed-link test, require the helper and bottom **Send invite** action to be absent. Assert the localized error and its existing recovery phrase are children of one wrapping group directly below the invite card, with no duplicated **Retry** label.

```dart
expect(find.text('Only one friend can use this link'), findsNothing);
expect(find.text('Send invite'), findsNothing);
final recovery = find.byKey(const ValueKey('invite-create-recovery'));
expect(recovery, findsOneWidget);
expect(find.descendant(of: recovery, matching: find.text('Retry')), findsOneWidget);
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
flutter test test/new_chat_screen_test.dart
```

Expected: FAIL because the helper and disabled bottom action are still visible and the error uses a vertical group.

### Task 3: Add shared invite recovery actions

**Files:**
- Create: `lib/features/invite/invite_error_actions.dart`
- Modify: `lib/features/invite/invite_resolver_screen.dart`
- Modify: `lib/features/invite/new_chat_screen.dart`

- [ ] **Step 1: Create invite-owned close and text actions**

Add `InviteCloseAction` and `InviteTextAction`. Both keep a minimum 48 dp tap target. The close action uses `Icons.close` and routes through the callback supplied by the resolver. The text action uses content-driven width and Blab's brand color.

```dart
class InviteCloseAction extends StatelessWidget {
  const InviteCloseAction({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('invite-close'),
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    onPressed: onPressed,
    icon: const Icon(Icons.close),
  );
}

class InviteTextAction extends StatelessWidget {
  const InviteTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.edgeAligned = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool edgeAligned;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: Size(edgeAligned ? 48 : 0, 48),
      padding: edgeAligned
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16),
      alignment: edgeAligned ? Alignment.centerLeft : Alignment.center,
      foregroundColor: const Color(0xFFD96646),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}
```

- [ ] **Step 2: Replace resolver actions**

Put `InviteCloseAction` in the top-right of every resolver state and route it to `/chats`. Remove **Go to chats** from the content. For temporary failures, omit the old body and render only `InviteTextAction` for **Retry** below the title.

```dart
InviteCloseAction(onPressed: () => context.go('/chats')),
if (onRetry case final retry?) ...[
  const SizedBox(height: 12),
  InviteTextAction(label: context.l10n.retry, onPressed: retry),
],
```

- [ ] **Step 3: Re-group the creation failure**

While link creation has failed, hide the one-person helper and bottom **Send invite** action. Split the existing localized message at its sentence boundary so its recovery phrase becomes the edge-aligned `InviteTextAction`. Place both parts in one keyed `Wrap` directly below the card so translations can flow naturally without duplicate recovery copy.

```dart
Wrap(
  key: const ValueKey('invite-create-recovery'),
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Text(
      context.l10n.couldNotCreateInvite,
      style: const TextStyle(color: Color(0xFF917869), fontSize: 13),
    ),
    InviteTextAction(
      label: context.l10n.retry,
      edgeAligned: true,
      onPressed: () =>
          ref.read(preparedInviteProvider.notifier).prepare(),
    ),
  ],
)
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run:

```bash
flutter test test/invite_resolver_recovery_test.dart test/new_chat_screen_test.dart
```

Expected: PASS.

### Task 4: Verify localization resilience and Android output

**Files:**
- Modify only if a regression is found: `test/invite_resolver_recovery_test.dart`, `test/new_chat_screen_test.dart`, or the three implementation files above

- [ ] **Step 1: Run the invite/localization packet**

Run:

```bash
flutter test test/invite_resolver_recovery_test.dart test/new_chat_screen_test.dart test/invite_continuation_test.dart test/invite_auth_flow_test.dart test/app_localization_test.dart
flutter analyze
```

Expected: all checks pass with no analyzer issues.

- [ ] **Step 2: Run the full Flutter suite**

Run:

```bash
flutter test
```

Expected: all non-environment-gated tests pass.

- [ ] **Step 3: Run the design detector once**

Run:

```bash
/Users/aswin/.codex/plugins/cache/openai-curated-remote/impeccable/4.3.1/skills/impeccable/scripts/impeccable detect --json --scope layout lib/features/invite/invite_error_actions.dart lib/features/invite/invite_resolver_screen.dart lib/features/invite/new_chat_screen.dart
```

Expected: no unexplained layout findings.

- [ ] **Step 4: Build, install, and capture the four real failure states**

Install the exact debug APK on the Android emulator. Recreate invite-not-found, temporary open failure, already-claimed, and link-creation failure using local-only fixtures. Restore every temporary permission or fixture immediately after capture.

- [ ] **Step 5: Send screenshots for owner review**

Send the four numbered Android screenshots without committing the implementation. Commit only after owner approval, per the Blab QA workflow.
