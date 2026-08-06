import 'dart:async';

import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/shared/data/translation_support.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({
  required TranslateMessageFn translateFn,
  ChatService? chatService,
}) {
  return ProviderContainer(
    overrides: [
      translateMessageFnProvider.overrideWithValue(translateFn),
      if (chatService != null)
        chatServiceProvider.overrideWithValue(chatService),
    ],
  );
}

class _CommittedTranslationChatService implements ChatService {
  var fetchCalls = 0;

  @override
  Future<
    ({
      String text,
      String interfaceText,
      String interfaceLang,
      String sourceLang,
      String mode,
      String? explanation,
      String? confidence,
      List<Map<String, dynamic>> tokens,
    })?
  >
  fetchCachedTranslation({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async {
    fetchCalls++;
    if (fetchCalls == 1) return null;
    return (
      text: 'Hallo',
      interfaceText: 'Hello',
      interfaceLang: interfaceLang,
      sourceLang: 'en',
      mode: 'translation',
      explanation: null,
      confidence: null,
      tokens: <Map<String, dynamic>>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PageTranslationChatService implements ChatService {
  List<String>? requestedIds;

  @override
  Future<
    Map<
      String,
      ({
        String text,
        String interfaceText,
        String interfaceLang,
        String sourceLang,
        String mode,
        String? explanation,
        String? confidence,
        List<Map<String, dynamic>> tokens,
      })
    >
  >
  fetchCachedTranslationsForMessages({
    required List<String> messageIds,
    required String targetLang,
    required String interfaceLang,
  }) async {
    requestedIds = [...messageIds];
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EventuallyCommittedPageTranslationChatService implements ChatService {
  var fetchCalls = 0;

  @override
  Future<
    Map<
      String,
      ({
        String text,
        String interfaceText,
        String interfaceLang,
        String sourceLang,
        String mode,
        String? explanation,
        String? confidence,
        List<Map<String, dynamic>> tokens,
      })
    >
  >
  fetchCachedTranslationsForMessages({
    required List<String> messageIds,
    required String targetLang,
    required String interfaceLang,
  }) async {
    fetchCalls++;
    if (fetchCalls == 1) return {};
    return {
      'm1': (
        text: 'Hallo',
        interfaceText: 'Hello',
        interfaceLang: interfaceLang,
        sourceLang: 'en',
        mode: 'translation',
        explanation: null,
        confidence: null,
        tokens: <Map<String, dynamic>>[],
      ),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledCacheChatService implements ChatService {
  _ControlledCacheChatService({this.cachedByMessageId = const {}});

  final Map<String, MessageTranslation> cachedByMessageId;

  @override
  Future<
    ({
      String text,
      String interfaceText,
      String interfaceLang,
      String sourceLang,
      String mode,
      String? explanation,
      String? confidence,
      List<Map<String, dynamic>> tokens,
    })?
  >
  fetchCachedTranslation({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async {
    final cached = cachedByMessageId[messageId];
    if (cached == null) return null;
    return (
      text: cached.translation,
      interfaceText: cached.interfaceText,
      interfaceLang: cached.interfaceLang,
      sourceLang: cached.sourceLang,
      mode: cached.mode.name,
      explanation: cached.explanation,
      confidence: cached.confidence?.name,
      tokens: <Map<String, dynamic>>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RealtimeTranslationChatService implements ChatService {
  final changes = StreamController<MessageTranslationChange>.broadcast();

  @override
  Stream<MessageTranslationChange> watchMessageTranslationChanges({
    required String targetLang,
    required String interfaceLang,
  }) => changes.stream.where(
    (change) =>
        change.targetLang == targetLang &&
        change.interfaceLang == interfaceLang,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MessageTranslation _translation(String text) => MessageTranslation(
  translation: text,
  interfaceText: text,
  interfaceLang: 'en',
  sourceLang: 'en',
  tokens: const [],
);

void main() {
  test('off-screen messages never start a live translation request', () async {
    var calls = 0;
    final container = _container(
      translateFn: (id) async {
        calls++;
        return _translation('Hallo');
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensureVisible(
      visibleFraction: 0,
      messageId: 'off-screen',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    expect(calls, 0);
    expect(container.read(messageTranslationsProvider('chat-1')), isEmpty);

    await notifier.ensureVisible(
      visibleFraction: 0.25,
      messageId: 'visible',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    expect(calls, 1);
  });

  test('database prefetch is restricted to the loaded message ids', () async {
    final chatService = _PageTranslationChatService();
    var liveCalls = 0;
    final container = _container(
      chatService: chatService,
      translateFn: (id) async {
        liveCalls++;
        return _translation(id);
      },
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .prefetchFromDb(['m51', 'm52'], 'de', 'en');

    expect(chatService.requestedIds, ['m51', 'm52']);
    expect(liveCalls, 0);
  });

  test(
    'database prefetch retries rows committed after message insert',
    () async {
      final chatService = _EventuallyCommittedPageTranslationChatService();
      final container = _container(
        chatService: chatService,
        translateFn: (id) async => _translation(id),
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );

      await notifier.prefetchFromDb(['m1'], 'de', 'en');
      expect(
        container.read(messageTranslationsProvider('chat-1'))['m1|de|en'],
        isNull,
      );

      await Future<void>.delayed(const Duration(seconds: 9));

      final entry = container.read(
        messageTranslationsProvider('chat-1'),
      )['m1|de|en'];
      expect(chatService.fetchCalls, 2);
      expect(entry, isA<AsyncData<MessageTranslation>>());
      expect(entry!.value!.translation, 'Hallo');
    },
  );

  test(
    'realtime database row hydrates the matching open-chat bubble',
    () async {
      final chatService = _RealtimeTranslationChatService();
      final live = Completer<MessageTranslation>();
      final container = _container(
        chatService: chatService,
        translateFn: (id) => live.future,
      );
      addTearDown(() async {
        await chatService.changes.close();
        container.dispose();
      });
      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );

      notifier.watchDbRows({'m1'}, 'de', 'en');
      final inFlight = notifier.ensure(
        messageId: 'm1',
        text: 'hello',
        targetLang: 'de',
        interfaceLang: 'en',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(messageTranslationsProvider('chat-1'))['m1|de|en'],
        isA<AsyncLoading<MessageTranslation>>(),
      );

      chatService.changes.add(
        MessageTranslationChange(
          messageId: 'm1',
          targetLang: 'de',
          interfaceLang: 'en',
          translation: (
            text: 'Hallo',
            interfaceText: 'Hello',
            interfaceLang: 'en',
            sourceLang: 'en',
            mode: 'translation',
            explanation: null,
            confidence: null,
            tokens: <Map<String, dynamic>>[],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final entry = container.read(
        messageTranslationsProvider('chat-1'),
      )['m1|de|en'];
      expect(entry, isA<AsyncData<MessageTranslation>>());
      expect(entry!.value!.translation, 'Hallo');
      live.complete(_translation('late'));
      await inFlight;
      expect(
        container
            .read(messageTranslationsProvider('chat-1'))['m1|de|en']!
            .value!
            .translation,
        'Hallo',
      );
    },
  );

  test('loading state times out into a retryable unavailable state', () async {
    final live = Completer<MessageTranslation>();
    final container = ProviderContainer(
      overrides: [
        translateMessageFnProvider.overrideWithValue((id) => live.future),
        chatServiceProvider.overrideWithValue(_ControlledCacheChatService()),
        translationLoadingTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    addTearDown(container.dispose);

    unawaited(
      container
          .read(messageTranslationsProvider('chat-1').notifier)
          .ensure(
            messageId: 'm1',
            text: 'hello',
            targetLang: 'de',
            interfaceLang: 'en',
          ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(entry, isA<AsyncError<MessageTranslation>>());
    expect((entry!.error as MessageTranslationFailed).reason, 'timeout');
    live.complete(_translation('late'));
  });

  test('visible cache misses serialize live translation calls', () async {
    final pending = <String, Completer<MessageTranslation>>{};
    final callOrder = <String>[];
    var inFlight = 0;
    var maxInFlight = 0;
    final container = _container(
      chatService: _ControlledCacheChatService(),
      translateFn: (id) {
        callOrder.add(id);
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        final completer = Completer<MessageTranslation>();
        pending[id] = completer;
        return completer.future.whenComplete(() => inFlight--);
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    final first = notifier.ensureVisible(
      visibleFraction: 1,
      messageId: 'm1',
      text: 'one',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    final second = notifier.ensureVisible(
      visibleFraction: 1,
      messageId: 'm2',
      text: 'two',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);

    expect(callOrder, ['m1']);
    expect(maxInFlight, 1);
    pending['m1']!.complete(_translation('Eins'));
    await Future<void>.delayed(Duration.zero);
    expect(callOrder, ['m1', 'm2']);
    expect(maxInFlight, 1);

    pending['m2']!.complete(_translation('Zwei'));
    await Future.wait([first, second]);
    expect(maxInFlight, 1);
  });

  test('priority visible request bypasses older queued cache misses', () async {
    final pending = <String, Completer<MessageTranslation>>{};
    final callOrder = <String>[];
    final container = _container(
      chatService: _ControlledCacheChatService(),
      translateFn: (id) {
        callOrder.add(id);
        final completer = Completer<MessageTranslation>();
        pending[id] = completer;
        return completer.future;
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    final oldFirst = notifier.ensureVisible(
      visibleFraction: 1,
      messageId: 'old-1',
      text: 'old one',
      targetLang: 'en',
      interfaceLang: 'en',
    );
    final oldSecond = notifier.ensureVisible(
      visibleFraction: 1,
      messageId: 'old-2',
      text: 'old two',
      targetLang: 'en',
      interfaceLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);
    expect(callOrder, ['old-1']);

    final imageCaption = notifier.ensureVisible(
      visibleFraction: 1,
      messageId: 'photo-caption',
      text: 'I goed with photo',
      targetLang: 'en',
      interfaceLang: 'en',
      priority: true,
    );
    await Future<void>.delayed(Duration.zero);

    expect(callOrder, ['old-1', 'photo-caption']);

    pending['photo-caption']!.complete(_translation('I went with photo'));
    await imageCaption;
    pending['old-1']!.complete(_translation('old one'));
    await Future<void>.delayed(Duration.zero);
    expect(callOrder, ['old-1', 'photo-caption', 'old-2']);
    pending['old-2']!.complete(_translation('old two'));
    await Future.wait([oldFirst, oldSecond]);
  });

  test('cached visible result bypasses an active live queue', () async {
    final live = Completer<MessageTranslation>();
    var liveCalls = 0;
    final container = _container(
      chatService: _ControlledCacheChatService(
        cachedByMessageId: {'cached': _translation('Aus Cache')},
      ),
      translateFn: (id) {
        liveCalls++;
        return live.future;
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    final uncached = notifier.ensureVisible(
      visibleFraction: 1,
      messageId: 'live',
      text: 'live source',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);
    await notifier.ensureVisible(
      visibleFraction: 1,
      messageId: 'cached',
      text: 'cached source',
      targetLang: 'de',
      interfaceLang: 'en',
    );

    final cached = container.read(
      messageTranslationsProvider('chat-1'),
    )['cached|de|en'];
    expect(cached, isA<AsyncData<MessageTranslation>>());
    expect(cached!.value!.translation, 'Aus Cache');
    expect(liveCalls, 1);

    live.complete(_translation('Live'));
    await uncached;
  });

  test('language cutoff excludes old history and includes new messages', () {
    final cutoff = DateTime.utc(2026, 7, 17, 12);

    expect(
      shouldTranslateMessage(
        sentAt: cutoff.subtract(const Duration(microseconds: 1)),
        translationCutoffAt: cutoff,
      ),
      isFalse,
    );
    expect(
      shouldTranslateMessage(sentAt: cutoff, translationCutoffAt: cutoff),
      isTrue,
    );
    expect(
      shouldTranslateMessage(
        sentAt: cutoff.subtract(const Duration(days: 365)),
        translationCutoffAt: null,
      ),
      isTrue,
    );
  });

  test('translation requests require the display toggle to be enabled', () {
    final sentAt = DateTime.utc(2026, 7, 17, 12);

    expect(
      shouldRequestTranslation(
        showTranslations: false,
        learningLanguageCode: 'de',
        text: 'Hello',
        sentAt: sentAt,
        translationCutoffAt: null,
      ),
      isFalse,
    );
    expect(
      shouldRequestTranslation(
        showTranslations: true,
        learningLanguageCode: 'de',
        text: 'Hello',
        sentAt: sentAt,
        translationCutoffAt: null,
      ),
      isTrue,
    );
  });

  test('source detection applies to incoming and outgoing messages', () {
    final sentAt = DateTime.utc(2026, 7, 17, 12);

    expect(
      shouldRequestBubbleTranslation(
        showTranslations: true,
        learningLanguageCode: 'en',
        text: 'Already English',
        sentAt: sentAt,
        translationCutoffAt: null,
      ),
      isTrue,
    );
    expect(
      shouldRequestBubbleTranslation(
        showTranslations: true,
        learningLanguageCode: 'en',
        text: 'Kannst du mich verstehen?',
        sentAt: sentAt,
        translationCutoffAt: null,
      ),
      isTrue,
    );
  });

  test(
    'ensure fires translator once and caches AsyncData on success',
    () async {
      var calls = 0;
      final container = _container(
        translateFn: (id) async {
          calls++;
          return MessageTranslation(
            translation: 'Hello',
            interfaceText: 'Hello',
            interfaceLang: 'en',
            sourceLang: 'ta',
            tokens: const [
              MessageToken(
                text: 'வணக்கம்',
                gloss: 'Hello',
                romanization: 'Vaṇakkam',
                isContent: true,
              ),
            ],
          );
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );
      await notifier.ensure(
        messageId: 'm1',
        text: 'வணக்கம்',
        targetLang: 'en',
        interfaceLang: 'en',
      );

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|en|en'], isA<AsyncData<MessageTranslation>>());
      expect(state['m1|en|en']!.value!.translation, 'Hello');

      await notifier.ensure(
        messageId: 'm1',
        text: 'வணக்கம்',
        targetLang: 'en',
        interfaceLang: 'en',
      );
      expect(calls, 1);
    },
  );

  test('ensure keeps stable quota failure in AsyncError', () async {
    final container = _container(
      translateFn: (id) async {
        throw MessageTranslationFailed('translation_limit_reached');
      },
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'hello',
          targetLang: 'de',
          interfaceLang: 'en',
        );

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(entry, isA<AsyncError<MessageTranslation>>());
    expect(
      (entry!.error as MessageTranslationFailed).reason,
      'translation_limit_reached',
    );
  });

  test('lost function response recovers its committed cache row', () async {
    final chatService = _CommittedTranslationChatService();
    final container = _container(
      chatService: chatService,
      translateFn: (id) async {
        throw MessageTranslationFailed('invoke_failed');
      },
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'hello',
          targetLang: 'de',
          interfaceLang: 'en',
        );

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(chatService.fetchCalls, 2);
    expect(entry, isA<AsyncData<MessageTranslation>>());
    expect(entry!.value!.translation, 'Hallo');
  });

  test('database hydration replaces a stale translation error', () async {
    final container = _container(
      translateFn: (id) async {
        throw MessageTranslationFailed('invoke_failed');
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm1',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    notifier.hydrateFromDb({'m1': _translation('Hallo')}, 'de', 'en');

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(entry, isA<AsyncData<MessageTranslation>>());
    expect(entry!.value!.translation, 'Hallo');
  });

  test('database hydration replaces an in-flight translation', () async {
    final live = Completer<MessageTranslation>();
    final container = _container(
      chatService: _ControlledCacheChatService(),
      translateFn: (id) => live.future,
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    final inFlight = notifier.ensure(
      messageId: 'm1',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(messageTranslationsProvider('chat-1'))['m1|de|en'],
      isA<AsyncLoading<MessageTranslation>>(),
    );

    notifier.hydrateFromDb({'m1': _translation('Hallo')}, 'de', 'en');

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(entry, isA<AsyncData<MessageTranslation>>());
    expect(entry!.value!.translation, 'Hallo');

    live.complete(_translation('Hallo'));
    await inFlight;
  });

  test('manual retry replaces only the failed translation entry', () async {
    var failedMessageCalls = 0;
    final container = _container(
      translateFn: (id) async {
        if (id == 'm1' && failedMessageCalls++ == 0) {
          throw MessageTranslationFailed('invoke_failed');
        }
        return _translation(id == 'm1' ? 'Hallo' : 'Unchanged');
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm2',
      text: 'keep me',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    await notifier.ensure(
      messageId: 'm1',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    expect(
      container.read(messageTranslationsProvider('chat-1'))['m1|de|en'],
      isA<AsyncError<MessageTranslation>>(),
    );

    await notifier.retry(
      messageId: 'm1',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1|de|en']!.value!.translation, 'Hallo');
    expect(state['m2|de|en']!.value!.translation, 'Unchanged');
  });

  test('quota failure retries after the server retry window', () async {
    var calls = 0;
    final container = _container(
      translateFn: (id) async {
        calls++;
        if (calls == 1) {
          throw MessageTranslationFailed(
            'translation_limit_reached',
            retryAfter: const Duration(milliseconds: 10),
          );
        }
        return _translation('Hallo');
      },
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'hello',
          targetLang: 'de',
          interfaceLang: 'en',
        );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(calls, 2);
    expect(entry, isA<AsyncData<MessageTranslation>>());
    expect(entry!.value!.translation, 'Hallo');
  });

  test('different message ids cache independently', () async {
    final container = _container(
      translateFn: (id) async => _translation('T-$id'),
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm1',
      text: 'a',
      targetLang: 'en',
      interfaceLang: 'en',
    );
    await notifier.ensure(
      messageId: 'm2',
      text: 'b',
      targetLang: 'en',
      interfaceLang: 'en',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1|en|en']!.value!.translation, 'T-m1');
    expect(state['m2|en|en']!.value!.translation, 'T-m2');
  });

  test('different chats cache independently', () async {
    final container = _container(translateFn: (id) async => _translation('T'));
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'a',
          targetLang: 'en',
          interfaceLang: 'en',
        );

    expect(
      container.read(messageTranslationsProvider('chat-1'))['m1|en|en'],
      isA<AsyncData<MessageTranslation>>(),
    );
    expect(
      container.read(messageTranslationsProvider('chat-2'))['m1|en|en'],
      isNull,
    );
  });

  test(
    'same message id with different target langs caches independently',
    () async {
      var calls = 0;
      final container = _container(
        translateFn: (id) async => _translation('translation-${++calls}'),
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );

      await notifier.ensure(
        messageId: 'm1',
        text: 'x',
        targetLang: 'ta',
        interfaceLang: 'en',
      );
      await notifier.ensure(
        messageId: 'm1',
        text: 'x',
        targetLang: 'de',
        interfaceLang: 'en',
      );

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|ta|en']!.value!.translation, 'translation-1');
      expect(state['m1|de|en']!.value!.translation, 'translation-2');
    },
  );

  test('edited source text requests a fresh server result', () async {
    var calls = 0;
    final container = _container(
      translateFn: (id) async => _translation('translation-${++calls}'),
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm1',
      text: 'before',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    await notifier.ensure(
      messageId: 'm1',
      text: 'after',
      targetLang: 'de',
      interfaceLang: 'en',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(calls, 2);
    expect(state['m1|de|en']!.value!.translation, 'translation-2');
  });

  test(
    'same target language caches each interface locale separately',
    () async {
      var calls = 0;
      final container = _container(
        translateFn: (id) async {
          calls++;
          return MessageTranslation(
            translation: 'Hallo',
            interfaceText: 'Hello',
            interfaceLang: calls == 1 ? 'en' : 'uk',
            sourceLang: 'de',
            tokens: [
              MessageToken(
                text: 'Hallo',
                gloss: calls == 1 ? 'Hello' : 'Привіт',
                isContent: true,
              ),
            ],
          );
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );

      await notifier.ensure(
        messageId: 'm1',
        text: 'Hallo',
        targetLang: 'de',
        interfaceLang: 'en',
      );
      await notifier.ensure(
        messageId: 'm1',
        text: 'Hallo',
        targetLang: 'de',
        interfaceLang: 'uk',
      );

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|de|en']!.value!.tokens.first.gloss, 'Hello');
      expect(state['m1|de|uk']!.value!.tokens.first.gloss, 'Привіт');
      expect(calls, 2);
    },
  );
}
