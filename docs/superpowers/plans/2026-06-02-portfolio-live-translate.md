# Portfolio mode — Live English → Tamil send · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In portfolio mode, the user types any English sentence in the Aswin chat, sees an outgoing bubble appear immediately with a shimmering subtitle, then the bubble swaps to a Tamil translation with tappable per-word tokens (English gloss + romanization). On translation failure the bubble stays English with a muted "Translation unavailable" subtitle. Off-mode chat path is unchanged.

**Architecture:** Three new units + targeted edits:
1. A Supabase Edge Function (`translate-portfolio`) calls Anthropic Claude Haiku 4.5 and returns `{translation, tokens[]}` in one shot.
2. A Riverpod `NotifierProvider.family<List<Message>, String>` (`portfolioMessagesProvider`) owns the mutable, in-memory message list; seeds from the existing curated 7.
3. A `PortfolioTranslator` service wraps the Edge Function call.
`ChatNotifier` adds a portfolio branch that watches the new provider and overrides `addOutgoing` to lay an optimistic English bubble, kick the translator, and swap in the Tamil result (or mark failed). A new `TranslationState` enum on `Message` drives the shimmer / unavailable subtitle renders.

**Tech Stack:** Flutter / Dart 3, Riverpod 3.x, `supabase_flutter`, Deno Edge Functions, Anthropic Messages API (`claude-haiku-4-5-20251001`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-02-portfolio-live-translate-design.md`.

---

## Pre-flight: read these first

If you have zero context for this codebase, read these before starting Task 1:

- `CLAUDE.md` — source-of-truth ordering (PRD → tech-spec → progress), Flutter Android-first, designer communication style.
- `tasks/prd-blab.md` — US-013 (compose), US-014 (subtitle), US-018 (word popup), FR-23 (per-chat translation toggle).
- `tasks/tech-spec.md` § Resolved Decisions — log the new Anthropic + Edge Function decision here in Task 8.
- `tasks/progress.md` — Phase 2.5 Track A; the entry log near the bottom describes Step A2 / portfolio mode shipped 2026-06-01.
- `lib/shared/data/portfolio_data.dart` — the curated chat + token shape this work matches.
- `lib/features/chat/state/chat_state.dart` — current portfolio early-returns (`addOutgoing` line 79).
- `lib/features/chat/chat_screen.dart` lines 960–1020 — bubble + translation subtitle layout. Outgoing bubble shows `translation` as the **main** text and `originalText` as the subtitle (mirrors incoming). When `translation` is empty the main text falls back to `originalText`. The shimmer in this plan replaces the subtitle slot during the pending phase.
- `lib/shared/models/message.dart` — `Message`, `MessageStatus`, `copyWith`.
- `lib/shared/models/message_token.dart` — `MessageToken` (text, romanization, english, isContent).
- `supabase/functions/delete-account/index.ts` — the project's Edge Function pattern (`Deno.serve`, JSON helpers, env injection).
- `supabase/config.toml` — local Supabase config.

---

## File Structure

**New (Flutter):**
- `lib/shared/state/portfolio_messages_state.dart` — mutable per-chat message list. ~80 lines.
- `lib/shared/services/portfolio_translator.dart` — `PortfolioTranslator` class + `portfolioTranslatorProvider`. ~70 lines.
- `lib/features/chat/widgets/translation_subtitle.dart` — three-state subtitle (pending shimmer / ready text / unavailable). ~90 lines.

**New (Supabase / tests):**
- `supabase/functions/translate-portfolio/index.ts` — Edge Function. ~120 lines.
- `test/portfolio_messages_state_test.dart`
- `test/portfolio_translator_test.dart`
- `test/portfolio_send_test.dart` — end-to-end of `ChatNotifier.addOutgoing` in portfolio mode (fake translator).
- `test/translation_subtitle_test.dart` — widget test for the three render states.

**Edited:**
- `lib/shared/models/message.dart` — add `TranslationState? translationState` field + extend `copyWith`.
- `lib/shared/data/portfolio_data.dart` — no behavior change; expose the seed list factory as-is (`portfolioMessages` is already callable).
- `lib/features/chat/state/chat_state.dart` — portfolio branch in `build` (watch new provider) + `addOutgoing` (optimistic English bubble → translate → swap or mark unavailable).
- `lib/features/chat/chat_screen.dart` — replace the inline subtitle code (lines ~995–1016) with `TranslationSubtitle(...)`.
- `tasks/tech-spec.md` — § Resolved Decisions: new entry locking Anthropic Claude Haiku 4.5 + Supabase Edge Function for portfolio translation.
- `tasks/progress.md` — new step under Phase 2.5 (Step A2.5) with `← in progress` marker, then `[x]` when verified on device; Changelog entry at the bottom.

**Untouched (verify in Task 10):**
- Real Supabase `addOutgoing` path (`ChatService.sendMessage`, `pendingSendsProvider`).
- Any incoming-bubble code paths.
- Translation-visibility toggle (`showTranslationsProvider`) — must still hide the subtitle row in all three states.

---

## Task 1 — Add `TranslationState` to `Message`

**Files:**
- Modify: `lib/shared/models/message.dart`
- Test: `test/portfolio_send_test.dart` (created later; this task only changes the model + ensures existing tests still pass)

- [ ] **Step 1: Run the existing test suite to confirm a clean baseline**

Run: `flutter test`
Expected: PASS (whatever the current green count is; record it).

- [ ] **Step 2: Add the enum and field**

Edit `lib/shared/models/message.dart`. Above the `Message` class, add:

```dart
/// Render hint for a live-translated outgoing message in portfolio mode.
///
/// `null` (the default) means "no live translation flow involved" — the
/// existing rendering logic runs unchanged. [pending] tells the bubble to
/// show a shimmer in the subtitle slot while the translator is in flight.
/// [unavailable] tells it to show a muted "Translation unavailable" line.
/// On successful translation the field is reset to `null` so the message
/// renders like any normal outgoing bubble.
enum TranslationState { pending, unavailable }
```

In the `Message` class, add the field (right after `isEdited`):

```dart
  /// Optional translation render hint. See [TranslationState].
  final TranslationState? translationState;
```

Add it to the constructor (optional, no default):

```dart
    this.translationState,
```

Extend `copyWith`:

```dart
  Message copyWith({
    MessageStatus? status,
    String? originalText,
    String? translation,
    List<MessageToken>? tokens,
    Message? replyTo,
    bool? isEdited,
    TranslationState? translationState,
    bool clearTranslationState = false,
  }) {
    return Message(
      id: id,
      chatId: chatId,
      isOutgoing: isOutgoing,
      originalText: originalText ?? this.originalText,
      translation: translation ?? this.translation,
      tokens: tokens ?? this.tokens,
      sentAt: sentAt,
      status: status ?? this.status,
      replyTo: replyTo ?? this.replyTo,
      isEdited: isEdited ?? this.isEdited,
      translationState: clearTranslationState
          ? null
          : (translationState ?? this.translationState),
    );
  }
```

`clearTranslationState` is required because `copyWith` cannot otherwise distinguish "leave it alone" from "set it to null" when the existing value is non-null.

- [ ] **Step 3: Run `flutter analyze`**

Run: `flutter analyze`
Expected: clean (no new warnings/errors).

- [ ] **Step 4: Re-run the suite**

Run: `flutter test`
Expected: same PASS count as Step 1. The new field is optional + nullable, so nothing breaks.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/models/message.dart
git commit -m "model: add optional TranslationState to Message"
```

---

## Task 2 — `portfolioMessagesProvider` (mutable per-chat list)

**Files:**
- Create: `lib/shared/state/portfolio_messages_state.dart`
- Test: `test/portfolio_messages_state_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/portfolio_messages_state_test.dart`:

```dart
import 'package:blab/shared/data/portfolio_data.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/state/portfolio_messages_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Message _msg(String id, {String original = 'hi'}) => Message(
      id: id,
      chatId: kPortfolioChatId,
      isOutgoing: true,
      originalText: original,
      translation: '',
      sentAt: DateTime(2026, 6, 2, 9, 40),
      status: MessageStatus.delivered,
    );

void main() {
  test('seeds from curated portfolio messages', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final list = container.read(portfolioMessagesProvider(kPortfolioChatId));
    expect(list, portfolioMessages(kPortfolioChatId));
    expect(list, hasLength(7));
  });

  test('seeds empty for unknown chat ids', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final list = container.read(portfolioMessagesProvider('does-not-exist'));
    expect(list, isEmpty);
  });

  test('append adds a message to the end', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier =
        container.read(portfolioMessagesProvider(kPortfolioChatId).notifier);
    notifier.append(_msg('new-1', original: 'hello'));

    final list = container.read(portfolioMessagesProvider(kPortfolioChatId));
    expect(list, hasLength(8));
    expect(list.last.id, 'new-1');
    expect(list.last.originalText, 'hello');
  });

  test('updateById swaps the message in place', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier =
        container.read(portfolioMessagesProvider(kPortfolioChatId).notifier);
    notifier.append(_msg('new-2'));
    notifier.updateById('new-2', (m) => m.copyWith(translation: 'வணக்கம்'));

    final list = container.read(portfolioMessagesProvider(kPortfolioChatId));
    final found = list.firstWhere((m) => m.id == 'new-2');
    expect(found.translation, 'வணக்கம்');
    // Order preserved.
    expect(list.last.id, 'new-2');
  });

  test('updateById is a no-op when id is absent', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier =
        container.read(portfolioMessagesProvider(kPortfolioChatId).notifier);
    notifier.updateById('nope', (m) => m.copyWith(translation: 'x'));

    final list = container.read(portfolioMessagesProvider(kPortfolioChatId));
    expect(list, hasLength(7));
  });

  test('reset restores the curated seed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier =
        container.read(portfolioMessagesProvider(kPortfolioChatId).notifier);
    notifier.append(_msg('throwaway'));
    notifier.reset();

    final list = container.read(portfolioMessagesProvider(kPortfolioChatId));
    expect(list, portfolioMessages(kPortfolioChatId));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/portfolio_messages_state_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:blab/shared/state/portfolio_messages_state.dart'`.

- [ ] **Step 3: Implement the notifier**

Create `lib/shared/state/portfolio_messages_state.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/portfolio_data.dart';
import '../models/message.dart';

/// Mutable, in-memory message list for the portfolio-mode chat. Seeds from
/// the curated [portfolioMessages] factory and accepts append + in-place
/// updates so live-typed sends can flow through the same chat stream as the
/// hand-written seed messages.
///
/// Scoped per-chatId via `family`. Only the portfolio chat
/// ([kPortfolioChatId]) seeds non-empty; everything else seeds to `const
/// []`. Mutations are intentionally NOT persisted — restarting the app or
/// flipping portfolio mode off and on calls [reset] (or simply rebuilds the
/// provider) to restore the curated seed.
class PortfolioMessagesNotifier extends Notifier<List<Message>> {
  PortfolioMessagesNotifier(this.chatId);

  final String chatId;

  @override
  List<Message> build() => List.of(portfolioMessages(chatId));

  void append(Message m) {
    state = [...state, m];
  }

  void updateById(String id, Message Function(Message current) update) {
    final next = <Message>[];
    var changed = false;
    for (final m in state) {
      if (m.id == id) {
        next.add(update(m));
        changed = true;
      } else {
        next.add(m);
      }
    }
    if (changed) state = next;
  }

  void reset() {
    state = List.of(portfolioMessages(chatId));
  }
}

final portfolioMessagesProvider =
    NotifierProvider.family<PortfolioMessagesNotifier, List<Message>, String>(
  PortfolioMessagesNotifier.new,
);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/portfolio_messages_state_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/state/portfolio_messages_state.dart test/portfolio_messages_state_test.dart
git commit -m "portfolio: mutable per-chat messages provider"
```

---

## Task 3 — `PortfolioTranslator` service

**Files:**
- Create: `lib/shared/services/portfolio_translator.dart`
- Test: `test/portfolio_translator_test.dart`

The translator wraps a single call. The unit test injects a fake "invoker" function so we don't touch real Supabase. The default invoker (used in production) calls `Supabase.instance.client.functions.invoke(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/portfolio_translator_test.dart`:

```dart
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/portfolio_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a successful response into translation + tokens', () async {
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async => {
        'translation': 'வணக்கம்!',
        'tokens': [
          {
            'text': 'வணக்கம்',
            'english': 'Hello',
            'roman': 'Vaṇakkam',
            'isContent': true,
          },
          {'text': '!', 'isContent': false},
        ],
      },
    );

    final result = await translator.translate('Hello!');
    expect(result.tamil, 'வணக்கம்!');
    expect(result.tokens, hasLength(2));
    expect(result.tokens.first.text, 'வணக்கம்');
    expect(result.tokens.first.english, 'Hello');
    expect(result.tokens.first.romanization, 'Vaṇakkam');
    expect(result.tokens.first.isContent, isTrue);
    expect(result.tokens.last.text, '!');
    expect(result.tokens.last.isContent, isFalse);
  });

  test('trims input and skips trailing whitespace before invoking', () async {
    String? captured;
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async {
        captured = text;
        return {'translation': 'x', 'tokens': <Map<String, dynamic>>[]};
      },
    );

    await translator.translate('  hello world  ');
    expect(captured, 'hello world');
  });

  test('throws PortfolioTranslationFailed when invoker throws', () async {
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async {
        throw Exception('boom');
      },
    );

    expect(translator.translate('hi'),
        throwsA(isA<PortfolioTranslationFailed>()));
  });

  test('throws PortfolioTranslationFailed when response is malformed',
      () async {
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async => {
        'translation': null,
      },
    );

    expect(translator.translate('hi'),
        throwsA(isA<PortfolioTranslationFailed>()));
  });

  test('rejects empty / whitespace-only input', () async {
    final translator = PortfolioTranslator(
      invoke: ({required String text, required String target}) async => {},
    );

    expect(translator.translate('   '),
        throwsA(isA<PortfolioTranslationFailed>()));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/portfolio_translator_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the service**

Create `lib/shared/services/portfolio_translator.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_token.dart';

class PortfolioTranslation {
  const PortfolioTranslation({required this.tamil, required this.tokens});
  final String tamil;
  final List<MessageToken> tokens;
}

class PortfolioTranslationFailed implements Exception {
  PortfolioTranslationFailed(this.reason);
  final String reason;
  @override
  String toString() => 'PortfolioTranslationFailed: $reason';
}

/// Injectable invoker. Production wires this to a real Supabase Edge
/// Function call; tests pass a fake.
typedef PortfolioTranslateInvoke = Future<Map<String, dynamic>> Function({
  required String text,
  required String target,
});

class PortfolioTranslator {
  PortfolioTranslator({
    PortfolioTranslateInvoke? invoke,
    Duration timeout = const Duration(seconds: 4),
  })  : _invoke = invoke ?? _defaultInvoke,
        _timeout = timeout;

  final PortfolioTranslateInvoke _invoke;
  final Duration _timeout;

  Future<PortfolioTranslation> translate(String englishText) async {
    final trimmed = englishText.trim();
    if (trimmed.isEmpty) {
      throw PortfolioTranslationFailed('empty_input');
    }
    Map<String, dynamic> raw;
    try {
      raw = await _invoke(text: trimmed, target: 'ta').timeout(_timeout);
    } on TimeoutException {
      throw PortfolioTranslationFailed('timeout');
    } catch (e) {
      throw PortfolioTranslationFailed('invoke_failed: $e');
    }
    final translation = raw['translation'];
    final rawTokens = raw['tokens'];
    if (translation is! String || translation.isEmpty) {
      throw PortfolioTranslationFailed('missing_translation');
    }
    final tokens = <MessageToken>[];
    if (rawTokens is List) {
      for (final t in rawTokens) {
        if (t is! Map) continue;
        final text = t['text'];
        if (text is! String) continue;
        final isContent = t['isContent'] as bool? ?? true;
        tokens.add(MessageToken(
          text: text,
          english: t['english'] as String?,
          romanization: t['roman'] as String?,
          isContent: isContent,
        ));
      }
    }
    return PortfolioTranslation(tamil: translation, tokens: tokens);
  }
}

Future<Map<String, dynamic>> _defaultInvoke({
  required String text,
  required String target,
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'translate-portfolio',
    body: {'text': text, 'target': target},
  );
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('unexpected_payload');
}

final portfolioTranslatorProvider =
    Provider<PortfolioTranslator>((ref) => PortfolioTranslator());
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/portfolio_translator_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/services/portfolio_translator.dart test/portfolio_translator_test.dart
git commit -m "portfolio: translator client + provider"
```

---

## Task 4 — Wire `ChatNotifier` portfolio send path

**Files:**
- Modify: `lib/features/chat/state/chat_state.dart`
- Test: `test/portfolio_send_test.dart`

This task is the meat: portfolio mode now streams from `portfolioMessagesProvider`, and `addOutgoing` appends an English bubble with `translationState: pending`, kicks the translator, then either swaps in the Tamil result (clears state, sets translation + tokens) or marks it `unavailable`. Status flips delivered → read after 1.5s like the curated outgoings.

- [ ] **Step 1: Write the failing test**

Create `test/portfolio_send_test.dart`:

```dart
import 'dart:async';

import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/data/portfolio_data.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/portfolio_translator.dart';
import 'package:blab/shared/state/portfolio_messages_state.dart';
import 'package:blab/shared/state/portfolio_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTranslator extends PortfolioTranslator {
  _FakeTranslator(this._completer) : super(invoke: _never);

  final Completer<PortfolioTranslation> _completer;

  @override
  Future<PortfolioTranslation> translate(String englishText) =>
      _completer.future;
}

class _ThrowingTranslator extends PortfolioTranslator {
  _ThrowingTranslator() : super(invoke: _never);

  @override
  Future<PortfolioTranslation> translate(String englishText) async {
    throw PortfolioTranslationFailed('test');
  }
}

Future<Map<String, dynamic>> _never({
  required String text,
  required String target,
}) =>
    Completer<Map<String, dynamic>>().future;

ProviderContainer _portfolioContainer({required PortfolioTranslator t}) {
  final c = ProviderContainer(overrides: [
    portfolioModeProvider.overrideWith(() => _AlwaysOnPortfolioMode()),
    portfolioTranslatorProvider.overrideWithValue(t),
  ]);
  return c;
}

class _AlwaysOnPortfolioMode extends PortfolioModeNotifier {
  @override
  bool build() => true;
}

void main() {
  test('addOutgoing in portfolio mode appends pending English bubble', () {
    final completer = Completer<PortfolioTranslation>();
    final container =
        _portfolioContainer(t: _FakeTranslator(completer));
    addTearDown(container.dispose);

    final stream = container
        .read(chatMessagesProvider(kPortfolioChatId).notifier);
    // ignore: unawaited_futures
    stream.addOutgoing('Running late tonight');

    final list =
        container.read(portfolioMessagesProvider(kPortfolioChatId));
    expect(list.last.isOutgoing, isTrue);
    expect(list.last.originalText, 'Running late tonight');
    expect(list.last.translation, '');
    expect(list.last.translationState, TranslationState.pending);
    expect(list.last.status, MessageStatus.delivered);
  });

  test('successful translate swaps in Tamil + tokens, clears pending',
      () async {
    final completer = Completer<PortfolioTranslation>();
    final container =
        _portfolioContainer(t: _FakeTranslator(completer));
    addTearDown(container.dispose);

    final notifier = container
        .read(chatMessagesProvider(kPortfolioChatId).notifier);
    final future = notifier.addOutgoing('Hello!');

    completer.complete(PortfolioTranslation(
      tamil: 'வணக்கம்!',
      tokens: const [
        MessageToken(
            text: 'வணக்கம்',
            english: 'Hello',
            romanization: 'Vaṇakkam'),
        MessageToken(text: '!', isContent: false),
      ],
    ));
    await future;

    final list =
        container.read(portfolioMessagesProvider(kPortfolioChatId));
    final sent = list.last;
    expect(sent.translation, 'வணக்கம்!');
    expect(sent.tokens, hasLength(2));
    expect(sent.translationState, isNull);
  });

  test('translator failure marks bubble unavailable', () async {
    final container =
        _portfolioContainer(t: _ThrowingTranslator());
    addTearDown(container.dispose);

    final notifier = container
        .read(chatMessagesProvider(kPortfolioChatId).notifier);
    await notifier.addOutgoing('this will fail');

    final sent =
        container.read(portfolioMessagesProvider(kPortfolioChatId)).last;
    expect(sent.translationState, TranslationState.unavailable);
    expect(sent.translation, '');
    expect(sent.originalText, 'this will fail');
    // No "failed" status: bubble stays delivered for the demo.
    expect(sent.status, isNot(MessageStatus.failed));
  });

  test('whitespace-only input is dropped', () async {
    final container = _portfolioContainer(t: _ThrowingTranslator());
    addTearDown(container.dispose);

    final notifier = container
        .read(chatMessagesProvider(kPortfolioChatId).notifier);
    final before = container
        .read(portfolioMessagesProvider(kPortfolioChatId))
        .length;
    await notifier.addOutgoing('   ');
    final after = container
        .read(portfolioMessagesProvider(kPortfolioChatId))
        .length;

    expect(after, before);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/portfolio_send_test.dart`
Expected: FAIL — `chatMessagesProvider` either still early-returns (test 1 expects bubble appended) or the stream doesn't see `portfolioMessagesProvider`.

- [ ] **Step 3: Edit `chat_state.dart`**

In `lib/features/chat/state/chat_state.dart`, add imports near the top:

```dart
import '../../../shared/services/portfolio_translator.dart';
import '../../../shared/state/portfolio_messages_state.dart';
```

Replace the portfolio branch in `ChatNotifier.build` (around line 45). The current block reads:

```dart
    if (ref.watch(portfolioModeProvider)) {
      yield portfolioMessages(chatId);
      return;
    }
```

Replace with:

```dart
    if (ref.watch(portfolioModeProvider)) {
      yield ref.watch(portfolioMessagesProvider(chatId));
      // Re-yield on every mutation of the portfolio list.
      ref.listen<List<Message>>(portfolioMessagesProvider(chatId),
          (_, next) {
        // No-op listen — StreamNotifier doesn't have a direct re-yield
        // hook here; the StreamNotifier rebuilds when its watched
        // providers change, so the watch above is the actual driver.
      });
      return;
    }
```

(Riverpod 3.x rebuilds the `build` stream when any `ref.watch` value changes, so the single `ref.watch(portfolioMessagesProvider(chatId))` is enough to push updates. The `ref.listen` block above is redundant — delete it. Final form:)

```dart
    if (ref.watch(portfolioModeProvider)) {
      yield ref.watch(portfolioMessagesProvider(chatId));
      return;
    }
```

Now replace the portfolio guard in `addOutgoing`. The current code (line 78–80):

```dart
  Future<void> addOutgoing(String text, {Message? replyTo}) async {
    if (ref.read(portfolioModeProvider)) return;
    final trimmed = text.trim();
    ...
```

Replace with:

```dart
  Future<void> addOutgoing(String text, {Message? replyTo}) async {
    if (ref.read(portfolioModeProvider)) {
      await _addOutgoingPortfolio(text, replyTo: replyTo);
      return;
    }
    final trimmed = text.trim();
    ...
```

Add the new private method at the bottom of the `ChatNotifier` class (before the closing `}`):

```dart
  Future<void> _addOutgoingPortfolio(String text, {Message? replyTo}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final id = 'portfolio-${DateTime.now().microsecondsSinceEpoch}';
    final pending = Message(
      id: id,
      chatId: chatId,
      isOutgoing: true,
      originalText: trimmed,
      translation: '',
      sentAt: DateTime.now(),
      status: MessageStatus.delivered,
      replyTo: replyTo,
      translationState: TranslationState.pending,
    );
    final messages =
        ref.read(portfolioMessagesProvider(chatId).notifier);
    messages.append(pending);

    // Optimistic delivered → read flip, mirrors the curated outgoing
    // bubbles in portfolio_data.dart.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      messages.updateById(id, (m) => m.copyWith(status: MessageStatus.read));
    });

    try {
      final result =
          await ref.read(portfolioTranslatorProvider).translate(trimmed);
      messages.updateById(
        id,
        (m) => m.copyWith(
          translation: result.tamil,
          tokens: result.tokens,
          clearTranslationState: true,
        ),
      );
    } on PortfolioTranslationFailed {
      messages.updateById(
        id,
        (m) => m.copyWith(translationState: TranslationState.unavailable),
      );
    }
  }
```

Note the import for `TranslationState` is already covered by the existing `../../../shared/models/message.dart` import.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/portfolio_send_test.dart`
Expected: PASS — all 4 tests green.

- [ ] **Step 5: Run the full suite + analyze**

Run: `flutter test && flutter analyze`
Expected: green + clean. The `message_reads_test.dart` headless failures from the 2026-06-01 log are pre-existing — leave them alone, don't try to fix them in this task.

- [ ] **Step 6: Commit**

```bash
git add lib/features/chat/state/chat_state.dart test/portfolio_send_test.dart
git commit -m "portfolio: live send wires translator into chat stream"
```

---

## Task 5 — `TranslationSubtitle` widget (3 render states)

**Files:**
- Create: `lib/features/chat/widgets/translation_subtitle.dart`
- Test: `test/translation_subtitle_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/translation_subtitle_test.dart`:

```dart
import 'package:blab/features/chat/widgets/translation_subtitle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget _host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('ready state renders the translation text', (tester) async {
    await tester.pumpWidget(_host(const TranslationSubtitle(
      state: TranslationSubtitleState.ready,
      text: 'வணக்கம்!',
      isOutgoing: true,
    )));
    expect(find.text('வணக்கம்!'), findsOneWidget);
    expect(find.text('Translation unavailable'), findsNothing);
  });

  testWidgets('pending state renders shimmer placeholder, not text',
      (tester) async {
    await tester.pumpWidget(_host(const TranslationSubtitle(
      state: TranslationSubtitleState.pending,
      text: '',
      isOutgoing: true,
    )));
    expect(find.byKey(const ValueKey('translation-shimmer')), findsOneWidget);
    expect(find.text('Translation unavailable'), findsNothing);
  });

  testWidgets('unavailable state renders the muted label', (tester) async {
    await tester.pumpWidget(_host(const TranslationSubtitle(
      state: TranslationSubtitleState.unavailable,
      text: '',
      isOutgoing: true,
    )));
    expect(find.text('Translation unavailable'), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-shimmer')), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/translation_subtitle_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Implement the widget**

Create `lib/features/chat/widgets/translation_subtitle.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

enum TranslationSubtitleState { ready, pending, unavailable }

/// Renders the line that sits under a message bubble's main text. Owns the
/// thin divider above it. Used for both incoming and outgoing bubbles; the
/// caller picks the colors via [isOutgoing].
///
/// Pending state shows a single-line gradient shimmer (no extra package).
/// Unavailable state shows a muted italic "Translation unavailable" label.
class TranslationSubtitle extends StatelessWidget {
  const TranslationSubtitle({
    super.key,
    required this.state,
    required this.text,
    required this.isOutgoing,
  });

  final TranslationSubtitleState state;
  final String text;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        height: 1,
        color: isOutgoing
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.grey.shade200,
      ),
    );

    final Widget body;
    switch (state) {
      case TranslationSubtitleState.ready:
        body = Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isOutgoing
                ? Colors.white.withValues(alpha: 0.85)
                : BlabColors.textMuted,
            height: 1.3,
          ),
        );
      case TranslationSubtitleState.pending:
        body = _ShimmerLine(isOutgoing: isOutgoing);
      case TranslationSubtitleState.unavailable:
        body = Text(
          'Translation unavailable',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: isOutgoing
                ? Colors.white.withValues(alpha: 0.6)
                : BlabColors.textMuted,
            height: 1.3,
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [divider, body],
    );
  }
}

class _ShimmerLine extends StatefulWidget {
  const _ShimmerLine({required this.isOutgoing});
  final bool isOutgoing;

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.isOutgoing
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.grey.shade200;
    final highlight = widget.isOutgoing
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.grey.shade100;
    return AnimatedBuilder(
      key: const ValueKey('translation-shimmer'),
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/translation_subtitle_test.dart`
Expected: PASS — 3 tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/widgets/translation_subtitle.dart test/translation_subtitle_test.dart
git commit -m "chat: TranslationSubtitle widget with shimmer + unavailable states"
```

---

## Task 6 — Wire `TranslationSubtitle` into the bubble + handle pending main text

**Files:**
- Modify: `lib/features/chat/chat_screen.dart` (lines ~975–1016 and the `MessageText` block immediately before)
- Test: covered by existing `widget_test.dart` smoke + the unit tests in Task 4 (no new test added — this is glue).

Outgoing layout reminder: today, the **main** bubble text is the Tamil translation (when present) and the **subtitle** is the original English. In portfolio pending state, `translation` is empty so the main falls back to English (correct, what we want). The subtitle slot is the one that needs the new 3-state widget. In the unavailable state the main is still English; the subtitle says "Translation unavailable". On success the main flips to Tamil and the subtitle flips to English. No additional layout swap logic needed beyond what's already there — only the subtitle widget changes.

- [ ] **Step 1: Add the import**

Near the existing widget imports in `lib/features/chat/chat_screen.dart`, add:

```dart
import 'widgets/translation_subtitle.dart';
```

- [ ] **Step 2: Replace the inline subtitle code**

Find the block (around lines 995–1016):

```dart
            if (showTranslation &&
                message.translation.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  height: 1,
                  color: isOut
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.grey.shade200,
                ),
              ),
              Text(
                isOut ? message.originalText : message.translation,
                style: TextStyle(
                  fontSize: 14,
                  color: isOut
                      ? Colors.white.withValues(alpha: 0.85)
                      : BlabColors.textMuted,
                  height: 1.3,
                ),
              ),
            ],
```

Replace with:

```dart
            if (showTranslation) ...[
              if (message.translationState == TranslationState.pending)
                TranslationSubtitle(
                  state: TranslationSubtitleState.pending,
                  text: '',
                  isOutgoing: isOut,
                )
              else if (message.translationState == TranslationState.unavailable)
                TranslationSubtitle(
                  state: TranslationSubtitleState.unavailable,
                  text: '',
                  isOutgoing: isOut,
                )
              else if (message.translation.isNotEmpty)
                TranslationSubtitle(
                  state: TranslationSubtitleState.ready,
                  text: isOut ? message.originalText : message.translation,
                  isOutgoing: isOut,
                ),
            ],
```

`showTranslationsProvider` (FR-23 toggle) still hides the whole subtitle row by wrapping the entire `if (showTranslation)` block — preserved.

- [ ] **Step 3: Run `flutter analyze`**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 4: Run the suite**

Run: `flutter test`
Expected: green (plus the pre-existing `message_reads_test.dart` headless failures — same as the baseline).

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/chat_screen.dart
git commit -m "chat: render TranslationSubtitle for pending/unavailable/ready"
```

---

## Task 7 — Reset portfolio messages on mode toggle

**Files:**
- Modify: `lib/shared/state/portfolio_mode.dart`

Spec: "Toggling portfolio mode off → on resets the chat to the curated 7-message seed." When the toggle flips to `true`, reset all portfolio chat lists so the demo always starts from the curated state.

- [ ] **Step 1: Open `lib/shared/state/portfolio_mode.dart` and locate the toggle method.**

Read the file to confirm the notifier exposes a `set(bool)` or `toggle()` mutator.

- [ ] **Step 2: Add a reset call after a transition `false → true`.**

In whichever mutator(s) set `state = true`, call:

```dart
ref.read(portfolioMessagesProvider(kPortfolioChatId).notifier).reset();
```

Add the necessary imports:

```dart
import '../data/portfolio_data.dart' show kPortfolioChatId;
import 'portfolio_messages_state.dart';
```

If both `toggle()` and `set(bool)` exist, wrap the reset behind a guard so it only runs on the off → on edge:

```dart
final wasOff = !state;
state = value;
if (wasOff && value) {
  ref.read(portfolioMessagesProvider(kPortfolioChatId).notifier).reset();
}
```

- [ ] **Step 3: Add a unit test**

Append to `test/portfolio_messages_state_test.dart`:

```dart
import 'package:blab/shared/state/portfolio_mode.dart';

// ... at the bottom of the existing main():

  test('flipping portfolio mode off→on resets the message list', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mode = container.read(portfolioModeProvider.notifier);
    final messages = container
        .read(portfolioMessagesProvider(kPortfolioChatId).notifier);

    // Start in off, ensure list has the seed.
    expect(container.read(portfolioModeProvider), isFalse);

    // Mutate while off (simulating leftover state from a prior session).
    messages.append(Message(
      id: 'leftover',
      chatId: kPortfolioChatId,
      isOutgoing: true,
      originalText: 'should be wiped',
      translation: '',
      sentAt: DateTime(2026, 6, 2),
      status: MessageStatus.delivered,
    ));
    expect(
        container.read(portfolioMessagesProvider(kPortfolioChatId)).length,
        8);

    // Flip on.
    mode.set(true);

    expect(
        container.read(portfolioMessagesProvider(kPortfolioChatId)).length,
        7);
  });
```

If `portfolioModeProvider` reads from `SharedPreferences` and the test environment doesn't have a mock, add `TestWidgetsFlutterBinding.ensureInitialized()` + `SharedPreferences.setMockInitialValues({})` in a `setUp()` at the top of the file. Inspect `portfolio_mode.dart` to confirm.

- [ ] **Step 4: Run the test**

Run: `flutter test test/portfolio_messages_state_test.dart`
Expected: PASS — all tests including the new one.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/state/portfolio_mode.dart test/portfolio_messages_state_test.dart
git commit -m "portfolio: reset chat seed when mode flips on"
```

---

## Task 8 — Supabase Edge Function `translate-portfolio`

**Files:**
- Create: `supabase/functions/translate-portfolio/index.ts`
- Modify: `supabase/config.toml` (only if anonymous function invocation is not already permitted — verify and only add what's needed)

- [ ] **Step 1: Create the function file**

Create `supabase/functions/translate-portfolio/index.ts`:

```ts
// Portfolio mode live English → Tamil translator.
//
// Calls Anthropic Claude Haiku 4.5 with a fixed prompt that returns
// `{ translation, tokens[] }` JSON matching the curated portfolio chat
// shape. No authn — portfolio mode is a public demo. Basic guards:
//   - POST only
//   - 400-char hard cap on `text`
//   - target must equal "ta"
//
// Deploy:  supabase functions deploy translate-portfolio --no-verify-jwt
// Required env (set via `supabase secrets set`):
//   ANTHROPIC_API_KEY

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const MODEL = "claude-haiku-4-5-20251001";
const MAX_CHARS = 400;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const SYSTEM_PROMPT = `You translate English sentences into Tamil for a
language-learning app. You ALWAYS reply with strict JSON in this exact
shape and nothing else (no prose, no markdown fences):

{
  "translation": "<full Tamil translation as one string>",
  "tokens": [
    { "text": "<segment>", "english": "<1-3 word gloss>", "roman": "<IAST-style romanization>", "isContent": true },
    { "text": " ", "isContent": false }
  ]
}

Rules:
- The "tokens" array, when each token's "text" is concatenated in order,
  MUST exactly reproduce the "translation" string (whitespace and
  punctuation included).
- Content tokens (Tamil words) have isContent=true and include "english"
  + "roman". Whitespace, punctuation, and emoji are separate tokens with
  isContent=false and MUST NOT include "english" or "roman".
- Use IAST-style transliteration for "roman" (e.g. "Vaṇakkam", "Eppadi").
- Translation must read naturally to a Tamil speaker — colloquial, not
  word-for-word.`;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  let body: { text?: unknown; target?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const text = body.text;
  const target = body.target;
  if (typeof text !== "string" || text.trim().length === 0) {
    return json({ error: "missing_text" }, 400);
  }
  if (text.length > MAX_CHARS) {
    return json({ error: "text_too_long" }, 400);
  }
  if (target !== "ta") {
    return json({ error: "unsupported_target" }, 400);
  }

  let llm: Response;
  try {
    llm = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content: text.trim() }],
      }),
    });
  } catch (e) {
    return json({ error: `upstream_unreachable: ${e}` }, 502);
  }
  if (!llm.ok) {
    const detail = await llm.text();
    return json({ error: "upstream_error", status: llm.status, detail }, 502);
  }
  const payload = await llm.json();
  const content = payload?.content?.[0]?.text;
  if (typeof content !== "string") {
    return json({ error: "upstream_unexpected_shape" }, 502);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    return json({ error: "upstream_non_json" }, 502);
  }
  if (
    typeof parsed !== "object" ||
    parsed === null ||
    typeof (parsed as { translation?: unknown }).translation !== "string" ||
    !Array.isArray((parsed as { tokens?: unknown }).tokens)
  ) {
    return json({ error: "upstream_malformed" }, 502);
  }
  return json(parsed);
});
```

- [ ] **Step 2: Verify local Supabase CLI is installed**

Run: `supabase --version`
Expected: prints a version number. If not installed, install via Homebrew (`brew install supabase/tap/supabase`) before continuing.

- [ ] **Step 3: Set the local Anthropic key for local testing**

Append to `supabase/.env.local` (gitignored — create if missing):

```
ANTHROPIC_API_KEY=sk-ant-...   # your dev key, do NOT commit
```

Verify `supabase/.env.local` is in `.gitignore`. If not, add it before committing anything.

- [ ] **Step 4: Smoke-test the function locally**

In one terminal: `supabase functions serve translate-portfolio --env-file supabase/.env.local --no-verify-jwt`

In another terminal:

```bash
curl -sS -X POST http://127.0.0.1:54321/functions/v1/translate-portfolio \
  -H "Content-Type: application/json" \
  -d '{"text":"Running late tonight, can we move to 8?","target":"ta"}' | jq
```

Expected: a JSON object with a Tamil `translation` string + a non-empty `tokens` array whose concatenated `text` fields equal the translation.

- [ ] **Step 5: Set the production secret**

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-prod-...   # production key
```

Confirm: `supabase secrets list` shows `ANTHROPIC_API_KEY` (value not displayed).

- [ ] **Step 6: Deploy**

```bash
supabase functions deploy translate-portfolio --no-verify-jwt
```

Expected: deploy succeeds. Note the deploy URL.

- [ ] **Step 7: Hit production once to confirm**

```bash
curl -sS -X POST "https://<project-ref>.supabase.co/functions/v1/translate-portfolio" \
  -H "Content-Type: application/json" \
  -H "apikey: <anon-key>" \
  -d '{"text":"Hello!","target":"ta"}' | jq
```

The `apikey` header is the published Supabase anon key (already in the Flutter app's env). Expected: same JSON shape as local.

- [ ] **Step 8: Commit**

```bash
git add supabase/functions/translate-portfolio/index.ts
git commit -m "edge: translate-portfolio Edge Function (Claude Haiku 4.5)"
```

---

## Task 9 — Manual device verification

**Files:** none (verification only).

- [ ] **Step 1: Build and install**

```bash
flutter build apk --debug
flutter install
```

Expected: install succeeds on the Samsung S931B (or current device — check `flutter devices`).

- [ ] **Step 2: Run the demo flow**

1. Launch app. Open dev menu, flip **Portfolio mode** on.
2. Open the Aswin chat. Confirm the 7 curated messages are present.
3. Type *"Running late tonight, can we move to 8?"* and tap send.
4. Observe: orange bubble appears immediately with English text. Subtitle slot shows a single shimmer line for ~0.5–2s.
5. Shimmer is replaced by Tamil translation; main bubble text swaps from English to Tamil; English moves to subtitle.
6. Tap any Tamil word in the new bubble. Word popup opens with English + romanization.
7. After ~1.5s the bubble's read tick should have appeared (existing behavior).

- [ ] **Step 3: Verify the failure path**

1. Enable airplane mode on the device.
2. Type any English and send.
3. Bubble appears with English as main; subtitle shows muted italic "Translation unavailable" after the request times out (~4s).
4. No red tick, no failed-message sheet.

- [ ] **Step 4: Verify reseed**

1. Re-enable wifi. Flip Portfolio mode off in the dev menu, then back on.
2. Open the Aswin chat — only the curated 7 messages are present (the typed sends are gone).

- [ ] **Step 5: Off-mode regression check**

1. Flip Portfolio mode off.
2. Open a real (non-portfolio) chat (if signed in) and send a message. Confirm the normal Supabase flow still works (pending → delivered → read).

If any of the above fails, do not mark the step `[x]` — debug, fix, re-commit, re-test.

---

## Task 10 — Update tech-spec and progress.md

**Files:**
- Modify: `tasks/tech-spec.md`
- Modify: `tasks/progress.md`

- [ ] **Step 1: Add a Resolved Decision to `tech-spec.md`**

Append under § Resolved Decisions (numbered after the last existing entry):

```markdown
### Decision N — Portfolio-mode live translation backend
Use Anthropic Claude Haiku 4.5 (`claude-haiku-4-5-20251001`) via a Supabase
Edge Function (`translate-portfolio`) for portfolio-mode live English →
Tamil sends. Rationale: cheapest fast model that emits structured JSON
reliably; Edge Function keeps the API key off-device; reuses the existing
Supabase backend so no new infra. Scope is portfolio mode only — real chats
are unaffected. Spec:
`docs/superpowers/specs/2026-06-02-portfolio-live-translate-design.md`.
```

- [ ] **Step 2: Add Step A2.5 to `progress.md`**

Insert under Phase 2.5 (Portfolio polish), after Step A2:

```markdown
### Step A2.5 — Portfolio mode: live English → Tamil send `[x]`
- **Scope:** in portfolio mode, the user types any English in the Aswin
  chat and sees the bubble appear immediately, then the bubble swaps to a
  real Tamil translation with tappable per-word tokens (English gloss +
  romanization). On failure the bubble stays English with a muted
  "Translation unavailable" subtitle.
- **Done when:**
  1. Type English in portfolio Aswin chat → bubble appears with shimmer
     subtitle → bubble swaps to Tamil with tappable tokens that match the
     curated-chat word popup format.
  2. Word popup on the new bubble shows English + romanization.
  3. Airplane mode → "Translation unavailable" subtitle, no failed-message
     sheet.
  4. Flipping portfolio mode off → on resets the chat to the curated 7
     messages.
  5. Off-mode chat send path unchanged. `flutter analyze` clean, `flutter
     test` green.
- Spec: `docs/superpowers/specs/2026-06-02-portfolio-live-translate-design.md`.
- Plan: `docs/superpowers/plans/2026-06-02-portfolio-live-translate.md`.
```

- [ ] **Step 3: Add a Changelog entry**

At the bottom of `progress.md`, under ## Changelog:

```markdown
- 2026-06-02 — Step A2.5 shipped. Portfolio mode now supports live English →
  Tamil sends. New Supabase Edge Function `translate-portfolio` (Claude
  Haiku 4.5) returns sentence + per-token gloss/romanization in one shot.
  New `portfolioMessagesProvider` (Riverpod) makes the curated chat
  mutable; new `PortfolioTranslator` client wraps the function;
  `ChatNotifier.addOutgoing` gets a portfolio branch that appends an
  optimistic English bubble (pending shimmer subtitle), then swaps in the
  Tamil result or marks the bubble unavailable on failure. New
  `TranslationSubtitle` widget owns the 3-state subtitle (pending shimmer,
  ready text, muted "Translation unavailable"). `Message` model gained an
  optional `TranslationState` enum field. Portfolio mode toggle off → on
  resets the curated seed. Off-mode send path untouched. `flutter analyze`
  clean, `flutter test` green, device verification logged.
```

- [ ] **Step 4: Commit**

```bash
git add tasks/tech-spec.md tasks/progress.md
git commit -m "docs: progress + tech-spec for portfolio live translate"
```

---

## Self-Review (run after the plan is written)

**Spec coverage:**
- Behavior 1–5 (immediate bubble, shimmer, swap to Tamil with tokens): Tasks 4 + 5 + 6.
- Behavior 6 (read tick after 1.5s): Task 4 step 3 schedules the flip.
- Behavior 7 (unavailable subtitle on failure): Task 4 step 3 + Task 5.
- Behavior 8 (in-memory only, reseed on toggle / restart): Task 2 (no persistence) + Task 7 (toggle reset). App restart naturally rebuilds the notifier with the seed since there is no persistence.
- Architecture units 1–5: Tasks 7, 2, 3, 4, 5/6 respectively.
- Done-when 1–5 from the spec: Task 9 verification + Task 10 progress entry.

**Placeholder scan:** No TBDs. All code blocks are complete. The one runtime check (in Task 7) — "If `portfolioModeProvider` reads from `SharedPreferences`" — directs the engineer to inspect the file and add a mock if needed; this is a real verification step, not a hand-wave.

**Type consistency:**
- `TranslationState` enum (`pending`, `unavailable`) — added in Task 1, consumed in Tasks 4, 5, 6.
- `TranslationSubtitleState` enum (`ready`, `pending`, `unavailable`) — added + consumed in Task 5; mapped from `Message.translationState` in Task 6.
- `PortfolioTranslator.translate(String)` signature — defined Task 3, called Task 4.
- `PortfolioTranslation { tamil, tokens }` — defined Task 3, consumed Task 4.
- `portfolioMessagesProvider` family + `append` / `updateById` / `reset` — defined Task 2, consumed Tasks 4, 7.
- `Message.copyWith` `clearTranslationState` flag — added Task 1, used Task 4 step 3.

No mismatches found.
