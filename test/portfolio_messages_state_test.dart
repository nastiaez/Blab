import 'package:blab/shared/data/portfolio_data.dart';
import 'package:blab/shared/models/message.dart';
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
    final seed = portfolioMessages(kPortfolioChatId);
    expect(list, hasLength(7));
    expect(list.length, seed.length);
    for (var i = 0; i < seed.length; i++) {
      expect(list[i].id, seed[i].id);
      expect(list[i].originalText, seed[i].originalText);
      expect(list[i].translation, seed[i].translation);
      expect(list[i].isOutgoing, seed[i].isOutgoing);
      expect(list[i].status, seed[i].status);
    }
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
    final seed = portfolioMessages(kPortfolioChatId);
    expect(list, hasLength(seed.length));
    for (var i = 0; i < seed.length; i++) {
      expect(list[i].id, seed[i].id);
    }
  });
}
