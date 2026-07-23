import 'dart:async';

import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TypingEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final _typingEnabledProvider = NotifierProvider<_TypingEnabled, bool>(
  _TypingEnabled.new,
);

class _FakeTypingTransport implements TypingTransport {
  final controller = StreamController<TypingEvent>.broadcast();
  final sent = <bool>[];

  @override
  String get localUserId => 'me';

  @override
  Stream<TypingEvent> get events => controller.stream;

  @override
  Future<void> send(bool isTyping) async => sent.add(isTyping);

  @override
  Future<void> close() => controller.close();
}

void main() {
  test(
    'retained send callback rechecks privacy immediately before send',
    () async {
      final fake = _FakeTypingTransport();
      final container = ProviderContainer(
        overrides: [
          typingIndicatorsEnabledProvider.overrideWith(
            (ref) => ref.watch(_typingEnabledProvider),
          ),
          typingTransportProvider('c1').overrideWithValue(fake),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await fake.close();
      });

      final send = container.read(sendTypingFnProvider('c1'));
      container.read(_typingEnabledProvider.notifier).set(false);
      await send(true);

      expect(fake.sent, isEmpty);
    },
  );

  test('typing OFF neither subscribes nor displays partner events', () async {
    final fake = _FakeTypingTransport();
    final values = <bool>[];
    final container = ProviderContainer(
      overrides: [
        typingIndicatorsEnabledProvider.overrideWithValue(false),
        typingTransportProvider('c1').overrideWithValue(fake),
      ],
    );
    final subscription = container.listen(partnerTypingProvider('c1'), (
      _,
      next,
    ) {
      final value = next.value;
      if (value != null) values.add(value);
    }, fireImmediately: true);
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await fake.close();
    });

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(values, [false]);
    expect(fake.controller.hasListener, isFalse);
  });

  test('partner typing events display and explicit stop clears them', () async {
    final fake = _FakeTypingTransport();
    final container = ProviderContainer(
      overrides: [
        typingIndicatorsEnabledProvider.overrideWithValue(true),
        typingTransportProvider('c1').overrideWithValue(fake),
      ],
    );
    final values = <bool>[];
    final subscription = container.listen(partnerTypingProvider('c1'), (
      _,
      next,
    ) {
      final value = next.value;
      if (value != null) values.add(value);
    }, fireImmediately: true);
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await fake.close();
    });

    fake.controller.add(const TypingEvent(userId: 'partner', isTyping: true));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    fake.controller.add(const TypingEvent(userId: 'partner', isTyping: false));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(values, containsAllInOrder([false, true, false]));
  });

  test(
    'composer delays start, bounds updates, and stops after inactivity',
    () async {
      final sent = <bool>[];
      final composer = TypingComposer(
        send: (value) async => sent.add(value),
        isEnabled: () => true,
        startDelay: const Duration(milliseconds: 10),
        heartbeatInterval: const Duration(milliseconds: 15),
        inactivityTimeout: const Duration(milliseconds: 55),
      );
      addTearDown(composer.dispose);

      composer.textChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(sent, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(sent.first, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 55));

      expect(sent.last, isFalse);
      expect(sent.where((value) => value).length, lessThanOrEqualTo(5));
    },
  );

  test('composer emits an explicit stop when text is cleared', () async {
    final sent = <bool>[];
    final composer = TypingComposer(
      send: (value) async => sent.add(value),
      isEnabled: () => true,
      startDelay: const Duration(milliseconds: 5),
      heartbeatInterval: const Duration(seconds: 1),
      inactivityTimeout: const Duration(seconds: 1),
    );
    addTearDown(composer.dispose);

    composer.textChanged(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    composer.textChanged(false);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(sent, [true, false]);
  });

  test('composer stays active across continuous edits', () async {
    final sent = <bool>[];
    final composer = TypingComposer(
      send: (value) async => sent.add(value),
      isEnabled: () => true,
      startDelay: const Duration(milliseconds: 5),
      heartbeatInterval: const Duration(milliseconds: 10),
      inactivityTimeout: const Duration(milliseconds: 35),
    );
    addTearDown(composer.dispose);

    for (var i = 0; i < 5; i++) {
      composer.textChanged(true);
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }

    expect(sent, isNotEmpty);
    expect(sent, isNot(contains(false)));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(sent.last, isFalse);
  });

  test('composer restarts after inactivity clears a non-empty draft', () async {
    final sent = <bool>[];
    final composer = TypingComposer(
      send: (value) async => sent.add(value),
      isEnabled: () => true,
      startDelay: const Duration(milliseconds: 5),
      heartbeatInterval: const Duration(seconds: 1),
      inactivityTimeout: const Duration(milliseconds: 25),
    );
    addTearDown(composer.dispose);

    composer.textChanged(true);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(sent, [true, false]);

    composer.textChanged(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(sent, [true, false, true]);
  });

  test('composer never emits while disabled', () async {
    final sent = <bool>[];
    final composer = TypingComposer(
      send: (value) async => sent.add(value),
      isEnabled: () => false,
      startDelay: const Duration(milliseconds: 1),
      heartbeatInterval: const Duration(milliseconds: 1),
      inactivityTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(composer.dispose);

    composer.textChanged(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(sent, isEmpty);
  });
}
