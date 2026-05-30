import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blab/features/chat/state/message_reads_state.dart';

void main() {
  test('reportVisible coalesces ids and is idempotent', () async {
    final calls = <List<String>>[];
    final container = ProviderContainer(overrides: [
      markReadFnProvider('c1').overrideWithValue((ids) async {
        calls.add(List.of(ids));
      }),
    ]);
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
    final container = ProviderContainer(overrides: [
      markReadFnProvider('a').overrideWithValue((ids) async {
        callsA.add(List.of(ids));
      }),
      markReadFnProvider('b').overrideWithValue((ids) async {
        callsB.add(List.of(ids));
      }),
    ]);
    addTearDown(container.dispose);

    container.read(messageReadsProvider('a').notifier).reportVisible('x');
    container.read(messageReadsProvider('b').notifier).reportVisible('y');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(callsA.first, ['x']);
    expect(callsB.first, ['y']);
  });
}
