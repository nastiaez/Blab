# Real-Chat Translation (Tamil → English) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tamil incoming messages in real (non-portfolio) chats render with shimmer subtitle that swaps to tappable Tamil tokens + English sentence subtitle, mirroring portfolio-mode behavior. Failures show muted "Translation unavailable". Other 10 languages render unchanged.

**Architecture:** New Supabase Edge Function `translate-message` (clone of `translate-portfolio` parametrized on source + target lang). New Flutter `MessageTranslator` service mirroring `PortfolioTranslator`. New per-chat in-memory `messageTranslationsProvider` cache keyed by message id. `_Bubble`/`_MessageRow` triggers translation on incoming Tamil bubbles when not cached, renders subtitle off the cache entry's `AsyncValue`.

**Tech Stack:** Flutter / Dart, Riverpod 3, Supabase Edge Functions (Deno), OpenRouter routed to Claude Haiku 4.5.

**Spec:** `docs/superpowers/specs/2026-06-06-real-chat-translation-design.md`

---

## File Structure

**New files:**
- `supabase/functions/translate-message/index.ts` — edge function
- `lib/shared/services/message_translator.dart` — Flutter client service
- `lib/features/chat/state/message_translations_state.dart` — Riverpod cache
- `test/message_translator_test.dart`
- `test/message_translations_state_test.dart`

**Modified files:**
- `lib/features/chat/chat_screen.dart` — `_MessageRow` triggers translation; `_Bubble` reads cache for subtitle state

**Untouched:** `portfolio_translator.dart`, `translate-portfolio`, `Message` model, `TranslationSubtitle` widget, `MessageText` widget, `WordPopup`.

---

## Task 1: Edge function `translate-message`

**Files:**
- Create: `supabase/functions/translate-message/index.ts`

This is a generalized clone of `translate-portfolio`. Accepts `sourceLang` + `targetLang`. System prompt is parametrized — same JSON shape, but tells the model which direction.

- [ ] **Step 1.1: Write the edge function**

Create `supabase/functions/translate-message/index.ts`:

```typescript
// Real-chat translator. Calls OpenRouter (OpenAI-compatible) routed to
// Anthropic Claude Haiku 4.5 with a parametrized prompt that returns
// { translation, tokens[] } JSON matching the curated chat shape.
// Auth required (Supabase JWT). Basic guards:
//   - POST only
//   - 400-char hard cap on `text`
//   - sourceLang + targetLang required, must be supported codes
//
// Deploy:  supabase functions deploy translate-message
// Reuses ANTHROPIC_API_KEY / OPEN_ROUTER_KEY secret already set on the
// project for translate-portfolio.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPEN_ROUTER_KEY = Deno.env.get("OPEN_ROUTER_KEY")!;
const MODEL = "openai/gpt-4o-mini";
const MAX_CHARS = 400;

const LANG_NAMES: Record<string, string> = {
  en: "English",
  ta: "Tamil",
  uk: "Ukrainian",
  es: "Spanish",
  de: "German",
  fr: "French",
  it: "Italian",
  pt: "Portuguese",
  nl: "Dutch",
  tr: "Turkish",
  hi: "Hindi",
};

const NON_LATIN: Set<string> = new Set(["ta", "uk", "hi"]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function systemPrompt(sourceLang: string, targetLang: string): string {
  const sourceName = LANG_NAMES[sourceLang];
  const targetName = LANG_NAMES[targetLang];
  const romanGuidance = NON_LATIN.has(sourceLang)
    ? `- For each content token (a ${sourceName} word) include "roman" (Latin-script romanization, e.g. IAST for Tamil).`
    : `- "roman" may be omitted on content tokens when the source script is already Latin.`;

  return `You translate ${sourceName} sentences into ${targetName} for a
language-learning app. You ALWAYS reply with strict JSON in this exact
shape and nothing else (no prose, no markdown fences):

{
  "translation": "<full ${targetName} translation as one string>",
  "tokens": [
    { "text": "<segment of the ORIGINAL ${sourceName} sentence>", "english": "<1-3 word ${targetName} gloss>", "roman": "<romanization>", "isContent": true },
    { "text": " ", "isContent": false }
  ]
}

Rules:
- The "tokens" array's "text" fields, concatenated in order, MUST exactly
  reproduce the ORIGINAL ${sourceName} sentence the user sent (whitespace
  and punctuation included). NOT the translation.
- Content tokens (${sourceName} words) have isContent=true and include
  "english" (the ${targetName} gloss) and "roman".
- Whitespace, punctuation, and emoji are separate tokens with
  isContent=false and MUST NOT include "english" or "roman".
${romanGuidance}
- The "translation" field is the full natural ${targetName} sentence —
  colloquial, not word-for-word.`;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  let body: { text?: unknown; sourceLang?: unknown; targetLang?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const text = body.text;
  const sourceLang = body.sourceLang;
  const targetLang = body.targetLang;
  if (typeof text !== "string" || text.trim().length === 0) {
    return json({ error: "missing_text" }, 400);
  }
  if (text.length > MAX_CHARS) {
    return json({ error: "text_too_long" }, 400);
  }
  if (typeof sourceLang !== "string" || !(sourceLang in LANG_NAMES)) {
    return json({ error: "unsupported_source" }, 400);
  }
  if (typeof targetLang !== "string" || !(targetLang in LANG_NAMES)) {
    return json({ error: "unsupported_target" }, 400);
  }
  if (sourceLang === targetLang) {
    return json({ error: "same_language" }, 400);
  }

  let llm: Response;
  try {
    llm = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPEN_ROUTER_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 2048,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt(sourceLang, targetLang) },
          { role: "user", content: text.trim() },
        ],
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
  const content = payload?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    return json({ error: "upstream_unexpected_shape" }, 502);
  }
  let cleaned = content
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  const firstBrace = cleaned.indexOf("{");
  const lastBrace = cleaned.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    cleaned = cleaned.slice(firstBrace, lastBrace + 1);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    return json({ error: "upstream_non_json", raw: content.slice(0, 800) }, 502);
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

- [ ] **Step 1.2: Commit**

```bash
git add supabase/functions/translate-message/
git commit -m "edge: translate-message function for real chats (parametrized on source+target lang)"
```

Note: deploy + curl smoke-test happens in Task 5 alongside the human verification step. No Deno unit tests in this slice — function is a straight clone of an already-deployed shape.

---

## Task 2: `MessageTranslator` Dart service

**Files:**
- Create: `lib/shared/services/message_translator.dart`
- Test: `test/message_translator_test.dart`

Mirror of `PortfolioTranslator`. Same `MessageToken` model on the way out. Reuses raw token shape (`text` / `english` / `roman` / `isContent`).

- [ ] **Step 2.1: Write the failing tests**

Create `test/message_translator_test.dart`:

```dart
import 'dart:async';

import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a successful response into translation + tokens', () async {
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async => {
        'translation': 'Hello!',
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

    final result = await translator.translate(
      text: 'வணக்கம்!',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    expect(result.translation, 'Hello!');
    expect(result.tokens, hasLength(2));
    expect(result.tokens.first.text, 'வணக்கம்');
    expect(result.tokens.first.english, 'Hello');
    expect(result.tokens.first.romanization, 'Vaṇakkam');
    expect(result.tokens.first.isContent, isTrue);
    expect(result.tokens.last.text, '!');
    expect(result.tokens.last.isContent, isFalse);
  });

  test('passes source + target lang through to the invoker', () async {
    String? capturedSource;
    String? capturedTarget;
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async {
        capturedSource = sourceLang;
        capturedTarget = targetLang;
        return {'translation': 'x', 'tokens': <Map<String, dynamic>>[]};
      },
    );

    await translator.translate(
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    expect(capturedSource, 'ta');
    expect(capturedTarget, 'en');
  });

  test('trims input before invoking', () async {
    String? captured;
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async {
        captured = text;
        return {'translation': 'x', 'tokens': <Map<String, dynamic>>[]};
      },
    );

    await translator.translate(
      text: '  வணக்கம்  ',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    expect(captured, 'வணக்கம்');
  });

  test('throws MessageTranslationFailed when invoker throws', () async {
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async {
        throw Exception('boom');
      },
    );

    expect(
      translator.translate(text: 'hi', sourceLang: 'ta', targetLang: 'en'),
      throwsA(isA<MessageTranslationFailed>()),
    );
  });

  test('throws MessageTranslationFailed when response is malformed', () async {
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async => {'translation': null},
    );

    expect(
      translator.translate(text: 'hi', sourceLang: 'ta', targetLang: 'en'),
      throwsA(isA<MessageTranslationFailed>()),
    );
  });

  test('rejects empty / whitespace-only input', () async {
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) async => {},
    );

    expect(
      translator.translate(text: '   ', sourceLang: 'ta', targetLang: 'en'),
      throwsA(isA<MessageTranslationFailed>()),
    );
  });

  test('times out when invoker never completes', () async {
    final never = Completer<Map<String, dynamic>>();
    final translator = MessageTranslator(
      invoke: ({
        required String text,
        required String sourceLang,
        required String targetLang,
      }) => never.future,
      timeout: const Duration(milliseconds: 10),
    );

    try {
      await translator.translate(
        text: 'வணக்கம்',
        sourceLang: 'ta',
        targetLang: 'en',
      );
      fail('expected MessageTranslationFailed');
    } on MessageTranslationFailed catch (e) {
      expect(e.reason, 'timeout');
    }
  });
}
```

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
flutter test test/message_translator_test.dart
```

Expected: compile errors — `message_translator.dart` doesn't exist yet.

- [ ] **Step 2.3: Write the service**

Create `lib/shared/services/message_translator.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_token.dart';

class MessageTranslation {
  const MessageTranslation({required this.translation, required this.tokens});
  final String translation;
  final List<MessageToken> tokens;
}

class MessageTranslationFailed implements Exception {
  MessageTranslationFailed(this.reason);
  final String reason;
  @override
  String toString() => 'MessageTranslationFailed: $reason';
}

/// Injectable invoker. Production wires to a real Supabase Edge Function
/// call; tests pass a fake.
typedef MessageTranslateInvoke = Future<Map<String, dynamic>> Function({
  required String text,
  required String sourceLang,
  required String targetLang,
});

class MessageTranslator {
  MessageTranslator({
    MessageTranslateInvoke? invoke,
    Duration timeout = const Duration(seconds: 15),
  })  : _invoke = invoke ?? _defaultInvoke,
        _timeout = timeout;

  final MessageTranslateInvoke _invoke;
  final Duration _timeout;

  Future<MessageTranslation> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw MessageTranslationFailed('empty_input');
    }
    Map<String, dynamic> raw;
    try {
      raw = await _invoke(
        text: trimmed,
        sourceLang: sourceLang,
        targetLang: targetLang,
      ).timeout(_timeout);
    } on TimeoutException {
      throw MessageTranslationFailed('timeout');
    } catch (e) {
      throw MessageTranslationFailed('invoke_failed: $e');
    }
    final translation = raw['translation'];
    final rawTokens = raw['tokens'];
    if (translation is! String || translation.isEmpty) {
      throw MessageTranslationFailed('missing_translation');
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
    return MessageTranslation(translation: translation, tokens: tokens);
  }
}

Future<Map<String, dynamic>> _defaultInvoke({
  required String text,
  required String sourceLang,
  required String targetLang,
}) async {
  final response = await Supabase.instance.client.functions.invoke(
    'translate-message',
    body: {
      'text': text,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
    },
  );
  final data = response.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw StateError('unexpected_payload');
}

final messageTranslatorProvider =
    Provider<MessageTranslator>((ref) => MessageTranslator());
```

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
flutter test test/message_translator_test.dart
```

Expected: all 7 tests pass.

- [ ] **Step 2.5: Commit**

```bash
git add lib/shared/services/message_translator.dart test/message_translator_test.dart
git commit -m "chat: MessageTranslator service for real-chat translation"
```

---

## Task 3: `MessageTranslationsNotifier` cache provider

**Files:**
- Create: `lib/features/chat/state/message_translations_state.dart`
- Test: `test/message_translations_state_test.dart`

Per-chat in-memory cache. Map from `messageId` → `AsyncValue<MessageTranslation>`. `ensure(...)` is idempotent: kicks off translation on first call, no-ops on subsequent calls for the same id. State is `dispose`d when the chat screen unmounts (provider scoped via `family.autoDispose` — but per project convention check `pending_sends_state` for the pattern actually used; if non-autoDispose, that's also fine for an in-memory slice).

A `translateFnProvider` function-pointer indirection lets tests inject a fake translator without touching `MessageTranslator` directly.

- [ ] **Step 3.1: Write the failing tests**

Create `test/message_translations_state_test.dart`:

```dart
import 'dart:async';

import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({
  required Future<MessageTranslation> Function(
    String messageId,
    String text,
    String sourceLang,
    String targetLang,
  ) translateFn,
}) {
  return ProviderContainer(overrides: [
    translateMessageFnProvider.overrideWithValue(translateFn),
  ]);
}

void main() {
  test('ensure fires translator once and caches AsyncData on success',
      () async {
    var calls = 0;
    final container = _container(
      translateFn: (id, text, source, target) async {
        calls++;
        return MessageTranslation(
          translation: 'Hello',
          tokens: [
            const MessageToken(
              text: 'வணக்கம்',
              english: 'Hello',
              romanization: 'Vaṇakkam',
              isContent: true,
            ),
          ],
        );
      },
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(messageTranslationsProvider('chat-1').notifier);
    notifier.ensure(
      messageId: 'm1',
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );

    // After microtask drain the future resolves and state is AsyncData.
    await Future<void>.delayed(Duration.zero);

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1'], isA<AsyncData<MessageTranslation>>());
    expect(state['m1']!.value!.translation, 'Hello');

    // Second ensure for the same id does NOT re-fire.
    notifier.ensure(
      messageId: 'm1',
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });

  test('ensure sets AsyncError on translator failure', () async {
    final container = _container(
      translateFn: (id, text, source, target) async {
        throw MessageTranslationFailed('timeout');
      },
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(messageTranslationsProvider('chat-1').notifier);
    notifier.ensure(
      messageId: 'm1',
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1'], isA<AsyncError>());
  });

  test('different message ids cache independently', () async {
    final container = _container(
      translateFn: (id, text, source, target) async => MessageTranslation(
        translation: 'T-$id',
        tokens: const [],
      ),
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(messageTranslationsProvider('chat-1').notifier);
    notifier.ensure(
      messageId: 'm1',
      text: 'a',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    notifier.ensure(
      messageId: 'm2',
      text: 'b',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1']!.value!.translation, 'T-m1');
    expect(state['m2']!.value!.translation, 'T-m2');
  });

  test('different chats cache independently', () async {
    final container = _container(
      translateFn: (id, text, source, target) async => MessageTranslation(
        translation: 'T',
        tokens: const [],
      ),
    );
    addTearDown(container.dispose);

    container.read(messageTranslationsProvider('chat-1').notifier).ensure(
          messageId: 'm1',
          text: 'a',
          sourceLang: 'ta',
          targetLang: 'en',
        );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(messageTranslationsProvider('chat-1'))['m1'],
        isA<AsyncData<MessageTranslation>>());
    expect(
        container.read(messageTranslationsProvider('chat-2'))['m1'], isNull);
  });
}
```

- [ ] **Step 3.2: Run tests to verify they fail**

```bash
flutter test test/message_translations_state_test.dart
```

Expected: compile errors — provider file doesn't exist yet.

- [ ] **Step 3.3: Write the provider**

Create `lib/features/chat/state/message_translations_state.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/message_translator.dart';

/// Function-pointer indirection. Tests override this to swap the real
/// translator out without monkeying with [messageTranslatorProvider].
typedef TranslateMessageFn = Future<MessageTranslation> Function(
  String messageId,
  String text,
  String sourceLang,
  String targetLang,
);

final translateMessageFnProvider = Provider<TranslateMessageFn>((ref) {
  final translator = ref.watch(messageTranslatorProvider);
  return (id, text, sourceLang, targetLang) => translator.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
});

/// Per-chat in-memory translation cache. Keyed by message id. Dies when
/// the provider is disposed. No persistence in this slice.
class MessageTranslationsNotifier
    extends FamilyNotifier<Map<String, AsyncValue<MessageTranslation>>, String> {
  @override
  Map<String, AsyncValue<MessageTranslation>> build(String arg) => const {};

  /// Triggers translation for [messageId] if not already started. Safe to
  /// call on every rebuild — idempotent.
  void ensure({
    required String messageId,
    required String text,
    required String sourceLang,
    required String targetLang,
  }) {
    if (state.containsKey(messageId)) return;
    state = {...state, messageId: const AsyncLoading()};
    final fn = ref.read(translateMessageFnProvider);
    fn(messageId, text, sourceLang, targetLang).then((result) {
      state = {...state, messageId: AsyncData(result)};
    }, onError: (Object error, StackTrace stack) {
      state = {
        ...state,
        messageId: AsyncError(error, stack),
      };
    });
  }
}

final messageTranslationsProvider = NotifierProvider.family<
    MessageTranslationsNotifier,
    Map<String, AsyncValue<MessageTranslation>>,
    String>(MessageTranslationsNotifier.new);
```

- [ ] **Step 3.4: Run tests to verify they pass**

```bash
flutter test test/message_translations_state_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 3.5: Commit**

```bash
git add lib/features/chat/state/message_translations_state.dart test/message_translations_state_test.dart
git commit -m "chat: messageTranslationsProvider — per-chat in-memory translation cache"
```

---

## Task 4: Wire `_Bubble` / `_MessageRow` to trigger + render translation

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`

Add translation triggering for incoming Tamil bubbles, render shimmer / tokens / unavailable off the cache entry.

Behavior:
- Only fires when `!isOut` (incoming bubble), `chat.learningLanguage.code == 'ta'`, and not in portfolio mode (portfolio bubbles already carry hand-curated tokens).
- Trigger lives in `_MessageRow.build` via `ref.read(...).ensure(...)` inside a `Future.microtask` (post-frame, so we don't mutate provider state during build).
- `_Bubble` reads `ref.watch(messageTranslationsProvider(chatId))[message.id]` and renders accordingly.

The existing portfolio-mode rendering path (`message.translationState == TranslationState.pending` etc.) is for outgoing bubbles only and stays intact.

- [ ] **Step 4.1: Modify `_MessageRow` to be the trigger point**

The current `_MessageRow` is already a `ConsumerWidget`. Add the translation trigger for incoming Tamil messages just before returning the widget tree. The trigger must read the chat's learning language and the portfolio-mode flag — both already available via `chatListProvider` and `portfolioModeProvider`.

Find the `_MessageRow.build` method (around line 870). After the existing `final isFailed = message.status == MessageStatus.failed;` line, add:

```dart
    // Fire real-chat translation for incoming Tamil bubbles. No-op when
    // portfolio mode is on (curated tokens already shipped), when this is
    // an outgoing bubble, or when the chat's learning language isn't a
    // language we translate this slice.
    if (!isOut &&
        languageCode == 'ta' &&
        !ref.watch(portfolioModeProvider) &&
        message.originalText.trim().isNotEmpty) {
      Future.microtask(() {
        ref
            .read(messageTranslationsProvider(chatId).notifier)
            .ensure(
              messageId: message.id,
              text: message.originalText,
              sourceLang: 'ta',
              targetLang: 'en',
            );
      });
    }
```

Add the required imports near the top of the file if not present:

```dart
import 'state/message_translations_state.dart';
import '../../shared/state/portfolio_mode.dart';
```

(Check existing imports first — the file likely already imports `portfolio_mode.dart` for the portfolio path.)

- [ ] **Step 4.2: Modify `_Bubble` to render translation off the cache**

`_Bubble` is currently a `StatelessWidget`. Convert to `ConsumerWidget` so it can read the cache.

Find the `_Bubble` class declaration (around line 927). Change:

```dart
class _Bubble extends StatelessWidget {
```

to:

```dart
class _Bubble extends ConsumerWidget {
```

and add `chatId` as a required param (needed for the cache lookup). Update the constructor + field declarations:

```dart
  const _Bubble({
    required this.chatId,
    required this.message,
    required this.showTranslation,
    required this.maxWidth,
    required this.languageCode,
    required this.popupTopInset,
  });

  final String chatId;
  final Message message;
  final bool showTranslation;
  final double maxWidth;
  final String languageCode;
  final double popupTopInset;
```

Change the `build` signature:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

Inside `build`, immediately after `final isOut = message.isOutgoing;`, compute the cache lookup:

```dart
    final liveTranslation = !isOut && languageCode == 'ta'
        ? ref.watch(messageTranslationsProvider(chatId))[message.id]
        : null;
```

Find the `else ...[` branch around line 1038 that handles non-portfolio bubbles (the `MessageText(...)` + `if (showTranslation && message.translation.isNotEmpty)` block). Replace the whole `else ...[` block with:

```dart
            ] else ...[
              MessageText(
                text: isOut && message.translation.isNotEmpty
                    ? message.translation
                    : message.originalText,
                tokens: liveTranslation is AsyncData<MessageTranslation>
                    ? liveTranslation.value.tokens
                    : message.tokens,
                languageCode: languageCode,
                popupTopInset: popupTopInset,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.7,
                  color: isOut ? Colors.white : BlabColors.textPrimary,
                ),
              ),
              if (showTranslation) ...[
                if (liveTranslation is AsyncLoading)
                  TranslationSubtitle(
                    state: TranslationSubtitleState.pending,
                    text: '',
                    isOutgoing: isOut,
                  )
                else if (liveTranslation is AsyncError)
                  TranslationSubtitle(
                    state: TranslationSubtitleState.unavailable,
                    text: '',
                    isOutgoing: isOut,
                  )
                else if (liveTranslation is AsyncData<MessageTranslation>)
                  TranslationSubtitle(
                    state: TranslationSubtitleState.ready,
                    text: liveTranslation.value.translation,
                    isOutgoing: isOut,
                  )
                else if (message.translation.isNotEmpty)
                  TranslationSubtitle(
                    state: TranslationSubtitleState.ready,
                    text:
                        isOut ? message.originalText : message.translation,
                    isOutgoing: isOut,
                  ),
              ],
            ],
```

Logic summary:
- If we have a live translation (AsyncData), render the original Tamil text in the bubble with the LIVE tokens, and the LIVE English sentence in the subtitle.
- If still loading, render the original Tamil text (no tappable tokens yet) and show the shimmer subtitle.
- If errored, render the original Tamil + muted "Translation unavailable".
- Outgoing bubbles + already-translated portfolio bubbles fall back to the existing `message.translation` / `message.tokens` path.

- [ ] **Step 4.3: Update `_MessageRow` to pass `chatId` to `_Bubble`**

Find the `child: _Bubble(` call inside `_MessageRow.build` (around line 881). Add `chatId: chatId,` as the first named arg:

```dart
      child: _Bubble(
        chatId: chatId,
        message: message,
        showTranslation: showTranslation,
        maxWidth: maxBubble,
        languageCode: languageCode,
        popupTopInset: popupTopInset,
      ),
```

- [ ] **Step 4.4: Run analyze + tests**

```bash
flutter analyze
flutter test
```

Expected: analyze clean. All existing tests still green. The 11 new tests from Tasks 2 and 3 pass.

If any pre-existing tests broke, the most likely cause is `_Bubble`'s new required `chatId` param — search for any test that constructs `_Bubble` directly and fix call sites.

- [ ] **Step 4.5: Commit**

```bash
git add lib/features/chat/chat_screen.dart
git commit -m "chat: wire incoming Tamil bubbles to live translation cache"
```

---

## Task 5: Deploy edge function + device verification

This is the human-in-the-loop checkpoint. The edge function ships from a logged-in Supabase CLI; verification runs on a real phone with two paired accounts.

- [ ] **Step 5.1: Deploy the edge function**

The user runs in their terminal:

```bash
supabase functions deploy translate-message
```

The `OPEN_ROUTER_KEY` secret is already set on the project (used by `translate-portfolio`), so no new secret needed. Expected output: `Function translate-message deployed`.

If the user gets `Error: not logged in`, run `supabase login` first.

- [ ] **Step 5.2: Smoke-test the function via curl**

```bash
SUPABASE_URL=$(grep SUPABASE_URL lib/shared/data/supabase_config.dart | head -1)
# Use the Supabase anon key from the dashboard if needed.
curl -sS -X POST "https://bhzcexhebjszwyqvcsxs.supabase.co/functions/v1/translate-message" \
  -H "Authorization: Bearer <anon-or-user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"text":"வணக்கம், எப்படி இருக்கீங்க?","sourceLang":"ta","targetLang":"en"}' | jq
```

Expected: `{ "translation": "Hello, how are you?", "tokens": [...] }`. Tokens' `text` fields concatenated reproduce the original Tamil sentence.

- [ ] **Step 5.3: Build + install on Samsung S931B**

```bash
flutter build apk --debug
flutter install
```

- [ ] **Step 5.4: Live verification with two paired accounts**

1. Sign in as Nastia (account A) on Samsung S931B.
2. From another device (or by switching accounts), have Aswin send a Tamil message into the existing paired chat — e.g. `வணக்கம், எப்படி இருக்கீங்க?`.
3. On Nastia's phone, open the chat. The bubble should appear with a shimmer subtitle, then swap to tappable Tamil tokens + English subtitle within ~2 seconds.
4. Tap any Tamil token — the word popup opens with English gloss + romanization + working speaker.
5. Toggle ⋯ → Show translations off — translation row disappears under every bubble. Toggle on — reappears.
6. Force airplane mode on Nastia's phone. Have Aswin send another Tamil message. Wait for the realtime delivery (might be queued for when Nastia's online), then re-enter the chat with airplane mode still on. The bubble should render the original Tamil + muted "Translation unavailable" subtitle.
7. Turn airplane mode off, reopen chat — the cache is gone (in-memory only), translation re-fires successfully.

- [ ] **Step 5.5: Other-language sanity check**

If a non-Tamil chat is available (e.g. paired with a Ukrainian-learning account), open it. Confirm:
- No shimmer appears under incoming bubbles.
- No network call to `translate-message` (check Supabase Edge Function logs in the dashboard — there should be no invocations from this chat).
- Plain rendering, no tappable tokens.

- [ ] **Step 5.6: Flip the progress.md step**

Update `tasks/progress.md`:

- Mark Step 2.7 progress: add a sub-bullet noting Tamil → English (incoming direction) is shipped via LLM path. The step's `[ ]` stays unchecked since English → Tamil + Ukrainian still owe.
- Add a Changelog line dated `2026-06-06`.

- [ ] **Step 5.7: Commit progress.md**

```bash
git add tasks/progress.md
git commit -m "progress: Step 2.7 — Tamil incoming live translation shipped"
```

---

## Out of scope (next sessions)

- English → Tamil direction (Aswin's view of Nastia's outgoing messages)
- Ukrainian ↔ English in both directions
- "Translation coming soon" subtitle on the 9 unsupported languages
- DB-side cache (`messages.translation` + `messages.tokens` columns + edge-function writeback for cross-session persistence)
- Retry button on translation failure
- Real-chat invite flow polish (separate backlog item)
