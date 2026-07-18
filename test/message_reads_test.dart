import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blab/features/chat/state/message_reads_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';

class _ReadEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final _readEnabledProvider = NotifierProvider<_ReadEnabled, bool>(
  _ReadEnabled.new,
);

void main() {
  test('reportVisible coalesces ids and is idempotent', () async {
    final calls = <List<String>>[];
    final container = ProviderContainer(
      overrides: [
        readReceiptsEnabledProvider.overrideWithValue(true),
        markReadFnProvider('c1').overrideWithValue((ids) async {
          calls.add(List.of(ids));
        }),
      ],
    );
    addTearDown(container.dispose);

    final n = container.read(messageReadsProvider('c1').notifier);
    n.reportVisible('m1');
    n.reportVisible('m2');
    n.reportVisible('m1');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(calls.length, 1);
    final flushed = List<String>.from(calls.first)..sort();
    expect(flushed, ['m1', 'm2']);
  });

  test('separate chats batch independently', () async {
    final callsA = <List<String>>[];
    final callsB = <List<String>>[];
    final container = ProviderContainer(
      overrides: [
        readReceiptsEnabledProvider.overrideWithValue(true),
        markReadFnProvider('a').overrideWithValue((ids) async {
          callsA.add(List.of(ids));
        }),
        markReadFnProvider('b').overrideWithValue((ids) async {
          callsB.add(List.of(ids));
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(messageReadsProvider('a').notifier).reportVisible('x');
    container.read(messageReadsProvider('b').notifier).reportVisible('y');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(callsA.first, ['x']);
    expect(callsB.first, ['y']);
  });

  test('read receipts OFF never queue or call the write transport', () async {
    final calls = <List<String>>[];
    final container = ProviderContainer(
      overrides: [
        readReceiptsEnabledProvider.overrideWithValue(false),
        markReadFnProvider('c1').overrideWithValue((ids) async {
          calls.add(List.of(ids));
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(messageReadsProvider('c1').notifier).reportVisible('m1');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(container.read(messageReadsProvider('c1')), isEmpty);
    expect(calls, isEmpty);
  });

  test('turning receipts OFF drops an already queued batch', () async {
    final calls = <List<String>>[];
    final container = ProviderContainer(
      overrides: [
        readReceiptsEnabledProvider.overrideWith(
          (ref) => ref.watch(_readEnabledProvider),
        ),
        markReadFnProvider('c1').overrideWithValue((ids) async {
          calls.add(List.of(ids));
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(messageReadsProvider('c1').notifier).reportVisible('m1');
    container.read(_readEnabledProvider.notifier).set(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(calls, isEmpty);
    expect(container.read(messageReadsProvider('c1')), isEmpty);
  });

  test('read receipts OFF does not subscribe to partner reads', () async {
    var subscriptions = 0;
    final values = <Set<String>>[];
    final container = ProviderContainer(
      overrides: [
        readReceiptsEnabledProvider.overrideWithValue(false),
        watchReadsFnProvider('c1').overrideWithValue(() {
          subscriptions++;
          return Stream.value([
            {'message_id': 'm1', 'user_id': 'partner'},
          ]);
        }),
      ],
    );
    final subscription = container.listen(readsForChatProvider('c1'), (
      _,
      next,
    ) {
      final value = next.value;
      if (value != null) values.add(value);
    }, fireImmediately: true);
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(values, [<String>{}]);
    expect(subscriptions, 0);
  });

  test('read receipts ON subscribes and maps only partner rows', () async {
    final values = <Set<String>>[];
    final container = ProviderContainer(
      overrides: [
        readReceiptsEnabledProvider.overrideWithValue(true),
        readReceiptUserIdProvider.overrideWithValue('me'),
        watchReadsFnProvider('c1').overrideWithValue(
          () => Stream.value([
            {'message_id': 'mine', 'user_id': 'me'},
            {'message_id': 'theirs', 'user_id': 'partner'},
          ]),
        ),
      ],
    );
    final subscription = container.listen(readsForChatProvider('c1'), (
      _,
      next,
    ) {
      final value = next.value;
      if (value != null) values.add(value);
    }, fireImmediately: true);
    addTearDown(subscription.close);
    addTearDown(container.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(values, [
      <String>{'theirs'},
    ]);
  });
}
