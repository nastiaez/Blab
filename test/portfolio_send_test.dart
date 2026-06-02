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
