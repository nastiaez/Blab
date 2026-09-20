# Invite Error Action Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every invite error action content-width and keep each Retry visibly attached to the error it resolves without changing copy or behavior.

**Architecture:** Add two invite-owned action components for compact filled and text actions, then reuse them in the resolver and invite-creation error states. Existing providers, navigation, localization resources, and the bottom **Send invite** action remain unchanged.

**Tech Stack:** Flutter, Material buttons, Riverpod, `flutter_test`

---

### Task 1: Lock the resolver hierarchy with failing widget tests

**Files:**
- Modify: `test/invite_resolver_recovery_test.dart`

- [ ] **Step 1: Add compact terminal-action assertions**

Extend the invalid-link test to find the **Go to chats** `FilledButton`, assert its height is at least 48 dp, and assert its width is below 220 dp. Add the same assertions to the already-claimed state.

```dart
final goToChats = find.widgetWithText(FilledButton, 'Go to chats');
expect(goToChats, findsOneWidget);
expect(tester.getSize(goToChats).height, greaterThanOrEqualTo(48));
expect(tester.getSize(goToChats).width, lessThan(220));
```

- [ ] **Step 2: Add temporary-failure hierarchy assertions**

Mount a failing lookup and assert **Retry** is a `FilledButton`, **Go to chats** is a `TextButton`, both controls are below 220 dp wide, and **Retry** appears above **Go to chats**.

```dart
await _mount(
  tester,
  lookup: (_) async => throw Exception('temporary outage'),
);
await tester.pumpAndSettle();
final retry = find.widgetWithText(FilledButton, 'Retry');
final goToChats = find.widgetWithText(TextButton, 'Go to chats');
expect(retry, findsOneWidget);
expect(goToChats, findsOneWidget);
expect(tester.getSize(retry).width, lessThan(220));
expect(tester.getSize(goToChats).width, lessThan(220));
expect(tester.getTopLeft(retry).dy, lessThan(tester.getTopLeft(goToChats).dy));
```

- [ ] **Step 3: Run the focused test and verify RED**

Run:

```bash
flutter test test/invite_resolver_recovery_test.dart
```

Expected: FAIL because the terminal action is full width and temporary **Go to chats** is still filled.

### Task 2: Lock inline Retry proximity with a failing widget test

**Files:**
- Modify: `test/new_chat_screen_test.dart`

- [ ] **Step 1: Add the proximity assertion**

In the failed-link test, compare the left edge of the localized error text with the left edge of the **Retry** label and require a difference below 24 dp. Require **Retry** to sit below the error and within 48 dp of it vertically.

```dart
final error = find.text("Couldn't create invite. Try again.");
final retry = find.text('Retry');
final errorLeft = tester.getTopLeft(error).dx;
final retryLeft = tester.getTopLeft(retry).dx;
final verticalGap =
    tester.getTopLeft(retry).dy - tester.getBottomLeft(error).dy;
expect((retryLeft - errorLeft).abs(), lessThan(24));
expect(verticalGap, allOf(greaterThanOrEqualTo(0), lessThan(48)));
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
flutter test test/new_chat_screen_test.dart
```

Expected: FAIL because the current `Expanded` row pushes **Retry** to the far edge.

### Task 3: Add shared compact invite actions

**Files:**
- Create: `lib/features/invite/invite_error_actions.dart`
- Modify: `lib/features/invite/invite_resolver_screen.dart`
- Modify: `lib/features/invite/new_chat_screen.dart`

- [ ] **Step 1: Create invite-owned action components**

Add `InvitePrimaryAction` and `InviteTextAction`. Both accept `label` and `onPressed`, keep a minimum 48 dp tap target, use content-driven width, and preserve Blab's orange/brown palette. `InviteTextAction` also accepts `edgeAligned`; when true it removes horizontal visual padding and aligns its label to the leading edge while retaining the tap target.

```dart
class InvitePrimaryAction extends StatelessWidget {
  const InvitePrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFFF88C5A),
      foregroundColor: const Color(0xFF46281C),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      shape: const StadiumBorder(),
    ),
    onPressed: onPressed,
    child: Text(label),
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

For terminal states, render one centered `InvitePrimaryAction` for **Go to chats**. For temporary failures, render `InvitePrimaryAction` for **Retry**, then an `InviteTextAction` for **Go to chats** with an 4 dp relationship gap. Remove the full-width `SizedBox`.

```dart
if (onRetry case final retry?) ...[
  InvitePrimaryAction(label: context.l10n.retry, onPressed: retry),
  const SizedBox(height: 4),
  InviteTextAction(
    label: context.l10n.goToChats,
    onPressed: () => context.go('/chats'),
  ),
] else
  InvitePrimaryAction(
    label: context.l10n.goToChats,
    onPressed: () => context.go('/chats'),
  ),
```

- [ ] **Step 3: Re-group the creation failure**

Replace the `Row` and `Expanded` with a left-aligned `Column`: localized error text first, then edge-aligned `InviteTextAction` for **Retry**. Keep the error group below the helper, and keep the bottom **Send invite** action unchanged.

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
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
