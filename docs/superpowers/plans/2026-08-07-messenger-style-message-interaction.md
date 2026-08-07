# Messenger-Style Message Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the long-press modal bottom sheet with a Messenger-style
interaction: a floating reaction row above the pressed bubble, an inline
action row that replaces the composer, and a half-screen searchable emoji
sheet for "more reactions" — no scrim, list stays scrollable, scrolling or
tapping elsewhere dismisses.

**Architecture:** The bubble's on-screen rectangle and the long-press touch
point are captured at press time (no `GlobalKey`s needed — each message row
already owns a `BuildContext` at that moment) and stored as local state on
`_ChatScreenState`. The floating reaction row renders as a `Positioned`
sibling inside the *existing* top-level `Stack` in `chat_screen.dart` (the
same pattern already used for the "⋯" chat-menu dropdown at
`chat_screen.dart:672-710` — no new `Overlay` entry, no scrim, and nothing
intercepts touches outside the row's own small hit area, so the list stays
scrollable underneath). The action row is a plain conditional swap in place
of `_InputBar`. Dismissal reuses the existing tap-to-close-menu handler and
a new scroll-start listener — both just clear the selection state.

**Tech Stack:** Flutter/Dart, Riverpod (existing `messageReactionsProvider`),
`emoji_picker_flutter: ^4.5.3` (added this session) for the searchable
"more reactions" sheet.

## Global Constraints

- Dart/Flutter conventions already in the codebase: `ConsumerWidget`/
  `ConsumerStatefulWidget` for Riverpod-reading widgets, `BlabColors` for all
  color values (no ad-hoc hex outside that class except where a design spec
  gave an exact one-off hex, as `message_reaction_bar.dart` already does).
- No new l10n strings needed beyond what's already defined
  (`context.l10n.reply/edit/copy/delete/report`) — the action row reuses
  those exact keys.
- Every new file goes under `lib/features/chat/widgets/` or
  `lib/features/chat/` (positioning function), matching existing structure.
- Run `flutter analyze` and `flutter test` after every task; both must be
  clean before moving on.
- `pubspec.yaml` already has `emoji_picker_flutter: ^4.5.3` added (verified
  installable, `flutter analyze` clean with it present).

---

### Task 1: Geometry-aware long press

**Files:**
- Modify: `lib/features/chat/widgets/message_interaction_target.dart`
- Modify: `lib/features/chat/chat_screen.dart` (`_MessageList`, `_MessageRow`,
  the `onLongPress` closure passed to `_MessageList` around line 577)
- Test: `test/message_interaction_target_test.dart` (new file)

**Interfaces:**
- Produces: `MessageInteractionTarget.onLongPress` becomes
  `void Function(Rect bubbleRect, Offset pressPosition)` (was
  `VoidCallback`). Later tasks read `bubbleRect`/`pressPosition` to position
  the floating reaction row.

- [ ] **Step 1: Write the failing test**

Create `test/message_interaction_target_test.dart`:

```dart
import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('long press reports the bubble rect and press position', (
    tester,
  ) async {
    Rect? capturedRect;
    Offset? capturedPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 100, left: 20),
              child: MessageInteractionTarget(
                isFailed: false,
                onLongPress: (rect, position) {
                  capturedRect = rect;
                  capturedPosition = position;
                },
                onFailedTap: () {},
                child: const SizedBox(width: 150, height: 60),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();

    expect(capturedRect, isNotNull);
    expect(capturedRect, tester.getRect(find.byType(MessageInteractionTarget)));
    expect(capturedPosition, isNotNull);
    // The synthetic long-press lands at the target's center.
    expect(capturedPosition!.dx, closeTo(capturedRect!.center.dx, 1));
    expect(capturedPosition!.dy, closeTo(capturedRect!.center.dy, 1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/message_interaction_target_test.dart`
Expected: FAIL — `onLongPress` doesn't accept two positional arguments yet
(compile error against the current `VoidCallback` signature).

- [ ] **Step 3: Update `MessageInteractionTarget`**

In `lib/features/chat/widgets/message_interaction_target.dart`, change the
field type and constructor param:

```dart
  final bool isFailed;
  final void Function(Rect bubbleRect, Offset pressPosition) onLongPress;
  final VoidCallback onFailedTap;
```

Add a handler method inside `_MessageInteractionTargetState` (above
`build`):

```dart
  void _handleLongPressStart(LongPressStartDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    widget.onLongPress(rect, details.globalPosition);
  }
```

In `build`, replace `onLongPress: widget.onLongPress,` with:

```dart
        onLongPressStart: _handleLongPressStart,
```

- [ ] **Step 4: Thread the new signature through `chat_screen.dart`**

In `_MessageRow` (around `chat_screen.dart:1244-1248`), change:

```dart
  final void Function(String emoji) onReact;
```

is unrelated — leave reactions alone. Instead find and change the
`onLongPress` field:

```dart
  final VoidCallback onLongPress;
```

to:

```dart
  final void Function(Rect bubbleRect, Offset pressPosition) onLongPress;
```

Where `_MessageRow` builds `MessageInteractionTarget` (around
`chat_screen.dart:1282-1286`), `onLongPress: onLongPress` already matches —
no change needed there, the type now flows through correctly.

In `_MessageList` (around `chat_screen.dart:1020-1041`), change:

```dart
  final void Function(Message) onLongPress;
```

to:

```dart
  final void Function(Message, Rect, Offset) onLongPress;
```

Where `_MessageList` builds each `_MessageRow` (around
`chat_screen.dart:1129`), change:

```dart
            onLongPress: () => onLongPress(item.message),
```

to:

```dart
            onLongPress: (rect, position) =>
                onLongPress(item.message, rect, position),
```

Finally, in `_ChatScreenState.build()` where `_MessageList` is constructed
(around `chat_screen.dart:577-596`), change the closure signature so it
still compiles and behaves exactly as today (this task does not change
behavior, only plumbing):

```dart
                              onLongPress: (m, rect, pressPosition) {
                                HapticFeedback.mediumImpact();
                                showMessageActionSheet(
                                  context,
                                  message: m,
                                  onAction: (a) => _handleAction(m, a, chat),
                                  onReact: canReplyToMessage(m)
                                      ? (emoji) => ref
                                            .read(
                                              messageReactionsProvider(
                                                widget.chatId,
                                              ).notifier,
                                            )
                                            .react(
                                              messageId: m.id,
                                              emoji: emoji,
                                            )
                                      : null,
                                );
                              },
```

(Only the closure's parameter list changed from `(m) {` to
`(m, rect, pressPosition) {` — the body is untouched. `rect` and
`pressPosition` are intentionally unused here; Task 5 consumes them.)

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/message_interaction_target_test.dart`
Expected: PASS

- [ ] **Step 6: Full regression check**

Run: `flutter analyze && flutter test`
Expected: both clean — this task changes only plumbing, not behavior, so
every existing test should still pass unmodified.

- [ ] **Step 7: Commit**

```bash
git add lib/features/chat/widgets/message_interaction_target.dart \
  lib/features/chat/chat_screen.dart \
  test/message_interaction_target_test.dart
git commit -m "Thread bubble geometry through the long-press handler"
```

---

### Task 2: Reaction row positioning math

**Files:**
- Create: `lib/features/chat/reaction_row_positioning.dart`
- Test: `test/reaction_row_positioning_test.dart`

**Interfaces:**
- Produces: `computeReactionRowTop({required Rect bubbleRect, required
  Offset pressPosition, required double rowHeight, required double minTop,
  double tallBubbleThreshold = 120, double pressGap = 8}) -> double`. Task 5
  calls this to compute the floating row's vertical position.

- [ ] **Step 1: Write the failing tests**

Create `test/reaction_row_positioning_test.dart`:

```dart
import 'package:blab/features/chat/reaction_row_positioning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rowHeight = 44.0;
  const minTop = 60.0;

  test('short bubble with room above sits flush against the bubble top', () {
    final bubbleRect = const Rect.fromLTWH(20, 300, 200, 50);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: bubbleRect.center,
      rowHeight: rowHeight,
      minTop: minTop,
    );
    expect(top, bubbleRect.top - rowHeight);
  });

  test('short bubble near the top clamps to press position, not flush', () {
    final bubbleRect = const Rect.fromLTWH(20, 90, 200, 50);
    final pressPosition = const Offset(120, 130);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: pressPosition,
      rowHeight: rowHeight,
      minTop: minTop,
    );
    // flush (90 - 44 = 46) is below minTop, so it anchors near the press
    // point instead: 130 - 44 - 8 = 78, which clears minTop on its own
    // (no further clamp needed) and sits below the bubble's true top.
    expect(top, pressPosition.dy - rowHeight - 8);
    expect(top, greaterThanOrEqualTo(minTop));
    expect(top, lessThan(bubbleRect.top));
  });

  test('tall bubble anchors near the press point, not the true bubble top', () {
    final bubbleRect = const Rect.fromLTWH(20, -300, 200, 500);
    final pressPosition = const Offset(120, 250);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: pressPosition,
      rowHeight: rowHeight,
      minTop: minTop,
    );
    expect(top, pressPosition.dy - rowHeight - 8);
    expect(top, greaterThan(bubbleRect.top));
  });

  test('tall bubble still respects the minimum top clamp', () {
    final bubbleRect = const Rect.fromLTWH(20, -300, 200, 500);
    final pressPosition = const Offset(120, 50);
    final top = computeReactionRowTop(
      bubbleRect: bubbleRect,
      pressPosition: pressPosition,
      rowHeight: rowHeight,
      minTop: minTop,
    );
    expect(top, minTop);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/reaction_row_positioning_test.dart`
Expected: FAIL — `reaction_row_positioning.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/chat/reaction_row_positioning.dart`:

```dart
import 'package:flutter/material.dart';

/// Computes the top Y coordinate (in the same coordinate space as
/// [bubbleRect] and [pressPosition]) for the floating reaction row.
///
/// Default: the row sits flush against the top of the bubble (no gap).
/// When the bubble is short and there's room above it, that's exactly what
/// happens. When the bubble is tall (more than [tallBubbleThreshold]
/// logical pixels — roughly 3 lines of text or a photo) or there simply
/// isn't room above it, the row instead anchors near where the user
/// actually pressed rather than the bubble's true (possibly off-screen)
/// top, staying visually attached to the touch point. [minTop] is a hard
/// floor — the row's top never goes above it (e.g. above the status bar),
/// though it's allowed to overlap page content like the chat header.
double computeReactionRowTop({
  required Rect bubbleRect,
  required Offset pressPosition,
  required double rowHeight,
  required double minTop,
  double tallBubbleThreshold = 120,
  double pressGap = 8,
}) {
  final isTall = bubbleRect.height > tallBubbleThreshold;
  final flushTop = bubbleRect.top - rowHeight;
  if (!isTall && flushTop >= minTop) {
    return flushTop;
  }
  final pressAnchoredTop = pressPosition.dy - rowHeight - pressGap;
  return pressAnchoredTop < minTop ? minTop : pressAnchoredTop;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/reaction_row_positioning_test.dart`
Expected: PASS (all 4 cases)

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/reaction_row_positioning.dart \
  test/reaction_row_positioning_test.dart
git commit -m "Add pure positioning function for the floating reaction row"
```

---

### Task 3: `FloatingReactionRow` widget

**Files:**
- Create: `lib/features/chat/widgets/floating_reaction_row.dart`
- Test: `test/floating_reaction_row_test.dart`

**Interfaces:**
- Consumes: `kQuickMessageReactions` (existing `const List<String>` in
  `lib/features/chat/widgets/message_action_sheet.dart`), `BlabColors` from
  `lib/app/theme.dart`.
- Produces: `FloatingReactionRow({required String? selectedEmoji, required
  void Function(String emoji) onPick, required VoidCallback onMore})`. Task
  5 renders this positioned above the pressed bubble.

- [ ] **Step 1: Write the failing test**

Create `test/floating_reaction_row_test.dart`:

```dart
import 'package:blab/features/chat/widgets/floating_reaction_row.dart';
import 'package:blab/features/chat/widgets/message_action_sheet.dart'
    show kQuickMessageReactions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows every quick reaction plus a trailing more button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingReactionRow(
            selectedEmoji: null,
            onPick: (_) {},
            onMore: () {},
          ),
        ),
      ),
    );

    for (final emoji in kQuickMessageReactions) {
      expect(find.text(emoji), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('floating-reaction-more')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('floating-reaction-selected')),
      findsNothing,
    );
  });

  testWidgets('marks the viewer\'s existing reaction as selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingReactionRow(
            selectedEmoji: kQuickMessageReactions.first,
            onPick: (_) {},
            onMore: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('floating-reaction-selected')),
      findsOneWidget,
    );
  });

  testWidgets('tapping an emoji fires onPick with that emoji', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingReactionRow(
            selectedEmoji: null,
            onPick: (emoji) => picked = emoji,
            onMore: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text(kQuickMessageReactions[1]));
    expect(picked, kQuickMessageReactions[1]);
  });

  testWidgets('tapping the more button fires onMore', (tester) async {
    var moreTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingReactionRow(
            selectedEmoji: null,
            onPick: (_) {},
            onMore: () => moreTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('floating-reaction-more')));
    expect(moreTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/floating_reaction_row_test.dart`
Expected: FAIL — `floating_reaction_row.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/chat/widgets/floating_reaction_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'message_action_sheet.dart' show kQuickMessageReactions;

/// The compact horizontal emoji row that floats above a long-pressed
/// message bubble, Messenger-style. Packed closer together than the old
/// bottom-sheet picker; ends in a "+" that opens the full searchable sheet.
class FloatingReactionRow extends StatelessWidget {
  const FloatingReactionRow({
    super.key,
    required this.selectedEmoji,
    required this.onPick,
    required this.onMore,
  });

  /// The emoji the viewer has already reacted with on this message, if any.
  final String? selectedEmoji;
  final void Function(String emoji) onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in kQuickMessageReactions)
              _EmojiButton(
                emoji: emoji,
                selected: emoji == selectedEmoji,
                onTap: () => onPick(emoji),
              ),
            _MoreButton(onTap: onMore),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: selected ? const ValueKey('floating-reaction-selected') : null,
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? BlabColors.selectedTint : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22, height: 1)),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('floating-reaction-more'),
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        alignment: Alignment.center,
        child: const Icon(Icons.add, size: 20, color: BlabColors.textMuted),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/floating_reaction_row_test.dart`
Expected: PASS (all 4 cases)

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/widgets/floating_reaction_row.dart \
  test/floating_reaction_row_test.dart
git commit -m "Add FloatingReactionRow widget"
```

---

### Task 4: `MessageActionRow` widget

**Files:**
- Create: `lib/features/chat/widgets/message_action_row.dart`
- Test: `test/message_action_row_test.dart`

**Interfaces:**
- Consumes: `MessageAction` enum, `canReplyToMessage(Message)`,
  `canEditMessage(Message, {DateTime? now})` — all existing, in
  `lib/features/chat/widgets/message_action_sheet.dart`. `Message` model
  from `lib/shared/models/message.dart`.
- Produces: `MessageActionRow({required Message message, required void
  Function(MessageAction) onAction, DateTime? now})`. Task 5 swaps this in
  for the composer while a message is selected.

- [ ] **Step 1: Write the failing test**

Create `test/message_action_row_test.dart`:

```dart
import 'package:blab/features/chat/widgets/message_action_row.dart';
import 'package:blab/features/chat/widgets/message_action_sheet.dart'
    show MessageAction;
import 'package:blab/shared/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Message _message({required bool isOutgoing, DateTime? sentAt}) => Message(
  id: 'm1',
  chatId: 'chat-1',
  isOutgoing: isOutgoing,
  originalText: 'Hello',
  translation: '',
  sentAt: sentAt ?? DateTime.utc(2026, 8, 7, 12),
  status: MessageStatus.delivered,
);

void main() {
  testWidgets('outgoing message shows Reply, Edit, Copy, Delete — not Report', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 7, 12, 5);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(isOutgoing: true, sentAt: now),
            onAction: (_) {},
            now: now,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('message-action-reply')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('message-action-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-action-delete')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('message-action-report')),
      findsNothing,
    );
  });

  testWidgets('incoming message shows Reply, Copy, Report — not Edit/Delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(isOutgoing: false),
            onAction: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('message-action-reply')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('message-action-copy')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-action-report')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('message-action-edit')), findsNothing);
    expect(
      find.byKey(const ValueKey('message-action-delete')),
      findsNothing,
    );
  });

  testWidgets('tapping an action fires onAction with that action', (
    tester,
  ) async {
    MessageAction? fired;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActionRow(
            message: _message(isOutgoing: false),
            onAction: (a) => fired = a,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('message-action-copy')));
    expect(fired, MessageAction.copy);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/message_action_row_test.dart`
Expected: FAIL — `message_action_row.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/chat/widgets/message_action_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/message.dart';
import 'message_action_sheet.dart'
    show MessageAction, canEditMessage, canReplyToMessage;

/// Icon + label action row that replaces the composer, Messenger-style,
/// while a message is selected via long-press. Same eligibility rules as
/// the modal sheet it replaces.
class MessageActionRow extends StatelessWidget {
  const MessageActionRow({
    super.key,
    required this.message,
    required this.onAction,
    this.now,
  });

  final Message message;
  final void Function(MessageAction) onAction;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final isOut = message.isOutgoing;
    final canReply = canReplyToMessage(message);
    final canEdit = canEditMessage(message, now: now);
    final items = <_ActionItem>[
      if (canReply)
        _ActionItem(Icons.reply, context.l10n.reply, MessageAction.reply),
      if (canEdit)
        _ActionItem(
          Icons.edit_outlined,
          context.l10n.edit,
          MessageAction.edit,
        ),
      _ActionItem(Icons.copy_outlined, context.l10n.copy, MessageAction.copy),
      if (isOut)
        _ActionItem(
          Icons.delete_outline,
          context.l10n.delete,
          MessageAction.delete,
          destructive: true,
        ),
      if (!isOut)
        _ActionItem(
          Icons.flag_outlined,
          context.l10n.report,
          MessageAction.report,
          destructive: true,
        ),
    ];
    return Container(
      color: BlabColors.cream,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final item in items)
                _ActionButton(item: item, onTap: () => onAction(item.action)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem(
    this.icon,
    this.label,
    this.action, {
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final MessageAction action;
  final bool destructive;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.item, required this.onTap});

  final _ActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? const Color(0xFFEF4444)
        : BlabColors.textPrimary;
    return InkWell(
      key: ValueKey('message-action-${item.action.name}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/message_action_row_test.dart`
Expected: PASS (all 3 cases)

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/widgets/message_action_row.dart \
  test/message_action_row_test.dart
git commit -m "Add MessageActionRow widget"
```

---

### Task 5: Half-screen searchable emoji sheet

**Files:**
- Create: `lib/features/chat/widgets/full_emoji_picker_sheet.dart`
- Test: `test/full_emoji_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `package:emoji_picker_flutter` (already added to `pubspec.yaml`
  this session — `Config`, `EmojiViewConfig`, `SearchViewConfig`,
  `EmojiPicker`, `Emoji`, `Category`, `OnEmojiSelected =
  void Function(Category? category, Emoji emoji)`).
- Produces: `showFullEmojiPickerSheet(BuildContext context, {required void
  Function(String emoji) onPick}) -> Future<void>`. Task 6 wires this to
  the reaction row's "+" and to the reaction badge's tap (replacing the
  smaller `showReactionPickerSheet` from earlier today).

- [ ] **Step 1: Write the failing test**

Create `test/full_emoji_picker_sheet_test.dart`:

```dart
import 'package:blab/features/chat/widgets/full_emoji_picker_sheet.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens an EmojiPicker and forwards the selected emoji', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFullEmojiPickerSheet(
                context,
                onPick: (emoji) => picked = emoji,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final picker = tester.widget<EmojiPicker>(find.byType(EmojiPicker));
    expect(picker.onEmojiSelected, isNotNull);

    picker.onEmojiSelected!(null, const Emoji('🎉', 'party popper'));
    await tester.pumpAndSettle();

    expect(picked, '🎉');
    expect(find.byType(EmojiPicker), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/full_emoji_picker_sheet_test.dart`
Expected: FAIL — `full_emoji_picker_sheet.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

Create `lib/features/chat/widgets/full_emoji_picker_sheet.dart`:

```dart
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// Opened from the floating reaction row's "+" (and from tapping an
/// existing reaction badge) — the full emoji set with search, half the
/// screen height, standard drag-to-dismiss.
Future<void> showFullEmojiPickerSheet(
  BuildContext context, {
  required void Function(String emoji) onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      final sheetHeight = MediaQuery.sizeOf(sheetCtx).height * 0.5;
      return SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4DCCC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    Navigator.of(sheetCtx).pop();
                    onPick(emoji.emoji);
                  },
                  config: Config(
                    height: sheetHeight,
                    emojiViewConfig: const EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 28,
                    ),
                    searchViewConfig: const SearchViewConfig(
                      hintText: 'Search emoji',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/full_emoji_picker_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/widgets/full_emoji_picker_sheet.dart \
  test/full_emoji_picker_sheet_test.dart pubspec.yaml pubspec.lock
git commit -m "Add half-screen searchable emoji sheet"
```

---

### Task 6: Wire the new interaction into `chat_screen.dart`

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`

**Interfaces:**
- Consumes: `computeReactionRowTop` (Task 2), `FloatingReactionRow` (Task
  3), `MessageActionRow` (Task 4), `showFullEmojiPickerSheet` (Task 5),
  existing `messageReactionsProvider`, `MessageReactionSummary` (from
  `lib/shared/models/message_reaction.dart`, already imported).
- Produces: the live, on-device-verifiable feature. No new public API —
  this task is the integration point.

This task has no isolated unit test (it wires several already-tested
widgets into the top-level screen's `Stack`/state, matching how other
top-level `chat_screen.dart` wiring in this codebase — e.g. today's gallery
picker and attach-flow changes — is verified manually on-device rather than
through a full-screen widget test). Verify each step by running the app.

- [ ] **Step 1: Add imports**

At the top of `lib/features/chat/chat_screen.dart`, add:

```dart
import 'reaction_row_positioning.dart';
import 'widgets/floating_reaction_row.dart';
import 'widgets/full_emoji_picker_sheet.dart';
import 'widgets/message_action_row.dart';
```

(Keep these alongside the existing `import 'widgets/...'` block, sorted the
same way the file already sorts its local imports.)

- [ ] **Step 2: Add selection state**

In `_ChatScreenState`, alongside the existing `_scroll`/`_menuOpen` fields
(near `chat_screen.dart:62-69`), add:

```dart
  final GlobalKey _stackKey = GlobalKey();
  Message? _selectedMessage;
  Rect? _selectedBubbleRect;
  Offset? _selectedPressPosition;
```

- [ ] **Step 3: Add select/close methods**

Near `_closeMenu` (around `chat_screen.dart:260-264`), add:

```dart
  void _selectMessage(Message message, Rect bubbleRect, Offset pressPosition) {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedMessage = message;
      _selectedBubbleRect = bubbleRect;
      _selectedPressPosition = pressPosition;
    });
  }

  void _closeSelection() {
    if (_selectedMessage == null) return;
    setState(() {
      _selectedMessage = null;
      _selectedBubbleRect = null;
      _selectedPressPosition = null;
    });
  }

  String? _viewerReactionEmoji(String messageId) {
    final reactions = ref
        .read(messageReactionsProvider(widget.chatId))
        .value?[messageId];
    if (reactions == null) return null;
    for (final reaction in reactions) {
      if (reaction.reactedByMe) return reaction.emoji;
    }
    return null;
  }
```

- [ ] **Step 4: Replace the old long-press handler**

Find the closure from Task 1, Step 4 (around `chat_screen.dart:577-596`)
that still calls `showMessageActionSheet`. Replace the whole `onLongPress:`
value with:

```dart
                              onLongPress: _selectMessage,
```

(Delete the old body that called `showMessageActionSheet` — that function
and its supporting widgets are removed in Task 7, once nothing references
them.)

- [ ] **Step 5: Swap the composer for the action row when a message is selected**

Find the `_InputBar(...)` call (around `chat_screen.dart:656-669`). Wrap it:

```dart
                _selectedMessage != null
                    ? MessageActionRow(
                        message: _selectedMessage!,
                        onAction: (action) {
                          final message = _selectedMessage!;
                          _closeSelection();
                          _handleAction(message, action, chat);
                        },
                      )
                    : _InputBar(
                        controller: _input,
                        hasText: _hasText,
                        hintText: chatIsEmpty
                            ? context.l10n.sayHi
                            : context.l10n.message,
                        textLength: _textLength,
                        maxLength: _maxMessageLength,
                        counterShowAt: _counterShowAt,
                        onAttach: () =>
                            _attachImage(recipientName: chat.partnerName),
                        onSend: _send,
                        autofocus: chatIsEmpty,
                      ),
```

- [ ] **Step 6: Render the floating reaction row in the existing `Stack`**

Give the top-level `Stack` (around `chat_screen.dart:450`) the key from
Step 2:

```dart
        child: Stack(
          key: _stackKey,
          children: [
```

Then, alongside the existing `if (_menuOpen) Positioned(...)` blocks
(around `chat_screen.dart:672-710`), add a new sibling — insert it right
before the closing `],` of the `Stack`'s children list:

```dart
            if (_selectedMessage != null &&
                _selectedBubbleRect != null &&
                _selectedPressPosition != null)
              Builder(
                builder: (_) {
                  final stackBox =
                      _stackKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (stackBox == null) return const SizedBox.shrink();
                  const rowHeight = 44.0;
                  const rowWidth = 7 * 38.0;
                  final minTop = MediaQuery.paddingOf(context).top + 4;
                  final globalTop = computeReactionRowTop(
                    bubbleRect: _selectedBubbleRect!,
                    pressPosition: _selectedPressPosition!,
                    rowHeight: rowHeight,
                    minTop: minTop,
                  );
                  final localTopLeft = stackBox.globalToLocal(
                    Offset(_selectedBubbleRect!.center.dx, globalTop),
                  );
                  final screenWidth = MediaQuery.sizeOf(context).width;
                  final left = (localTopLeft.dx - rowWidth / 2).clamp(
                    8.0,
                    screenWidth - rowWidth - 8.0,
                  );
                  return Positioned(
                    top: localTopLeft.dy,
                    left: left,
                    child: FloatingReactionRow(
                      selectedEmoji: _viewerReactionEmoji(
                        _selectedMessage!.id,
                      ),
                      onPick: (emoji) {
                        final message = _selectedMessage!;
                        _closeSelection();
                        ref
                            .read(
                              messageReactionsProvider(
                                widget.chatId,
                              ).notifier,
                            )
                            .react(messageId: message.id, emoji: emoji);
                      },
                      onMore: () {
                        final message = _selectedMessage!;
                        _closeSelection();
                        showFullEmojiPickerSheet(
                          context,
                          onPick: (emoji) => ref
                              .read(
                                messageReactionsProvider(
                                  widget.chatId,
                                ).notifier,
                              )
                              .react(messageId: message.id, emoji: emoji),
                        );
                      },
                    ),
                  );
                },
              ),
```

- [ ] **Step 7: Dismiss on outside tap**

Find the existing tap handler on the message-list area (around
`chat_screen.dart:484-486`):

```dart
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeMenu,
```

Change `onTap: _closeMenu` to:

```dart
                    onTap: () {
                      _closeMenu();
                      _closeSelection();
                    },
```

- [ ] **Step 8: Dismiss on scroll start**

Find the `FutureBuilder<void>` immediately inside that same
`GestureDetector` (around `chat_screen.dart:487`). Wrap its `builder`
return value — specifically, wrap the `_MessageList` widget it eventually
returns — with a `NotificationListener`. The simplest correct place is one
level up, wrapping the whole `FutureBuilder`:

```dart
                    child: NotificationListener<ScrollStartNotification>(
                      onNotification: (_) {
                        if (_selectedMessage != null) _closeSelection();
                        return false;
                      },
                      child: FutureBuilder<void>(
                        future: _ready,
                        builder: (context, snapshot) {
```

(This adds one new opening brace/child; close it with the matching `)`
right after the existing `FutureBuilder`'s closing, before the
`GestureDetector`'s own closing paren — match the existing indentation
style in the file.)

- [ ] **Step 9: Run full regression**

Run: `flutter analyze && flutter test`
Expected: both clean.

- [ ] **Step 10: Manual on-device verification**

Rebuild and run on the connected device
(`flutter run -d <device-id> --dart-define=...` — same invocation used
throughout this session). Confirm:
- Long-pressing a short message shows the reaction row flush above it and
  the action row in place of the composer, no scrim.
- Tapping a quick emoji reacts and closes both rows.
- Tapping "+" opens the half-screen searchable sheet; picking an emoji
  reacts and closes it.
- Tapping elsewhere in the chat, or starting to scroll, closes both rows
  and brings the composer back without reacting.
- Long-pressing a very long message or a photo message keeps the row
  visually near the press point rather than off-screen.

- [ ] **Step 11: Commit**

```bash
git add lib/features/chat/chat_screen.dart
git commit -m "Wire the Messenger-style reaction/action rows into chat_screen"
```

---

### Task 7: Remove the old modal sheet and its dead code

**Files:**
- Modify: `lib/features/chat/widgets/message_action_sheet.dart`
- Modify: `lib/features/chat/widgets/message_reaction_bar.dart` (badge tap
  now opens the full sheet instead of the old small picker)
- Modify: `lib/features/chat/chat_screen.dart` (badge-tap call site)

**Interfaces:**
- Kept from `message_action_sheet.dart` (still used by Tasks 3/4/6):
  `MessageAction` enum, `messageEditWindow`, `kQuickMessageReactions`,
  `canReplyToMessage(Message)`, `canEditMessage(Message, {DateTime? now})`.
- Removed: `showMessageActionSheet`, `showReactionPickerSheet`,
  `kMoreMessageReactions`, `kMessageActionSheetMaxWidth`, and every private
  widget that only existed to support the modal sheet (`_ActionRow`,
  `_ReactionPicker`, `_ReactionButton`, `_MoreReactionButton`,
  `_OriginalMessage`).

- [ ] **Step 1: Confirm nothing else references the code being removed**

Run:

```bash
grep -rn "showMessageActionSheet\|showReactionPickerSheet\|kMoreMessageReactions\|kMessageActionSheetMaxWidth" lib/ test/
```

Expected: only hits inside `message_action_sheet.dart` itself and the one
call site in `chat_screen.dart`/`message_reaction_bar.dart` handled in the
next steps. If anything else shows up, stop and re-check Task 6 was
completed correctly before continuing.

- [ ] **Step 2: Trim `message_action_sheet.dart`**

Open `lib/features/chat/widgets/message_action_sheet.dart` and delete:
- The `showMessageActionSheet` function in full.
- `class _ReactionPicker` and `class _ReactionPickerState` in full.
- `class _ReactionButton` in full.
- `class _MoreReactionButton` in full.
- `class _OriginalMessage` in full.
- `class _ActionRow` in full.
- The `showReactionPickerSheet` function in full.
- The `kMoreMessageReactions` constant.
- The `kMessageActionSheetMaxWidth` constant.

Keep: the `MessageAction` enum, `messageEditWindow`,
`kQuickMessageReactions`, `canReplyToMessage`, `canEditMessage` — and their
doc comments.

- [ ] **Step 3: Repoint the reaction badge's tap target**

In `lib/features/chat/chat_screen.dart`, find where the badge's `onReact`
callback is built (the closure that previously called
`showReactionPickerSheet`, added when reaction badges shipped earlier
today). Replace the `showReactionPickerSheet(...)` call with
`showFullEmojiPickerSheet(...)`, matching that function's real signature
from Task 5 (`onPick`, not `onReact`):

```dart
                              onReact: (m) => showFullEmojiPickerSheet(
                                context,
                                onPick: (emoji) => ref
                                    .read(
                                      messageReactionsProvider(
                                        widget.chatId,
                                      ).notifier,
                                    )
                                    .react(messageId: m.id, emoji: emoji),
                              ),
```

- [ ] **Step 4: Run full regression**

Run: `flutter analyze && flutter test`
Expected: both clean. If `flutter analyze` reports unused imports in
`message_action_sheet.dart` (e.g. an import only needed by deleted code),
remove them.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/widgets/message_action_sheet.dart \
  lib/features/chat/chat_screen.dart
git commit -m "Remove the old modal action sheet, now superseded"
```

---

### Task 8: Progress log and final verification

**Files:**
- Modify: `tasks/progress.md`

- [ ] **Step 1: Full regression one more time**

Run: `flutter analyze && flutter test`
Expected: both clean, full suite green.

- [ ] **Step 2: On-device smoke test**

Rebuild and run on the connected device. Walk through the full flow once
more end to end: react via the row, react via "+", reply/edit/copy/delete
via the action row, dismiss via outside-tap, dismiss via scroll.

- [ ] **Step 3: Update `tasks/progress.md`**

Add a `## Changelog` entry (newest entries go at the top of that section,
per the file's existing convention) summarizing: the modal bottom sheet
replaced with the floating reaction row + inline action row + half-screen
searchable emoji sheet; `emoji_picker_flutter` added as a dependency;
`showMessageActionSheet`/`showReactionPickerSheet` and their supporting
private widgets removed as dead code.

- [ ] **Step 4: Commit**

```bash
git add tasks/progress.md
git commit -m "Log the Messenger-style message interaction in progress.md"
```
