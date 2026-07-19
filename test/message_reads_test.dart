import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blab/features/chat/state/message_reads_state.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
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
        readReceiptsTransportStateProvider.overrideWithValue(
          const PrivacySettingState.ready(true),
        ),
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
        readReceiptsTransportStateProvider.overrideWithValue(
          const PrivacySettingState.ready(true),
        ),
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
        readReceiptsTransportStateProvider.overrideWithValue(
          const PrivacySettingState.ready(false),
        ),
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
        readReceiptsTransportStateProvider.overrideWith(
          (ref) => PrivacySettingState.ready(ref.watch(_readEnabledProvider)),
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

  test('visible messages wait for an enabled preference to load', () async {
    SharedPreferences.setMockInitialValues({kPrivacyReadReceiptsKey: true});
    final calls = <List<String>>[];
    final container = ProviderContainer(
      overrides: [
        markReadFnProvider('c1').overrideWithValue((ids) async {
          calls.add(List.of(ids));
        }),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      messageReadsProvider('c1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final reads = container.read(messageReadsProvider('c1').notifier);
    reads.reportVisible('m1');
    reads.reportVisible('m2');
    reads.reportVisible('m3');
    reads.reportVisible('m4');
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(container.read(readReceiptsEnabledProvider), isTrue);
    expect(container.read(messageReadsProvider('c1')), isEmpty);
    expect(calls, hasLength(1));
    final flushed = List<String>.from(calls.single)..sort();
    expect(flushed, ['m1', 'm2', 'm3', 'm4']);
  });

  test(
    'visible messages are dropped when the loaded preference is OFF',
    () async {
      SharedPreferences.setMockInitialValues({kPrivacyReadReceiptsKey: false});
      final calls = <List<String>>[];
      final container = ProviderContainer(
        overrides: [
          markReadFnProvider('c1').overrideWithValue((ids) async {
            calls.add(List.of(ids));
          }),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        messageReadsProvider('c1'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      container.read(messageReadsProvider('c1').notifier).reportVisible('m1');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(container.read(readReceiptsEnabledProvider), isFalse);
      expect(container.read(messageReadsProvider('c1')), isEmpty);
      expect(calls, isEmpty);
    },
  );

  test('read receipts OFF does not subscribe to partner reads', () async {
    var subscriptions = 0;
    final values = <Set<String>>[];
    final container = ProviderContainer(
      overrides: [
        readReceiptsTransportStateProvider.overrideWithValue(
          const PrivacySettingState.ready(false),
        ),
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
        readReceiptsTransportStateProvider.overrideWithValue(
          const PrivacySettingState.ready(true),
        ),
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
