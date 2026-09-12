import 'package:blab/shared/state/privacy_settings.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PrivacySettingState> _waitUntilLoaded(
  ProviderContainer container,
  NotifierProvider<dynamic, PrivacySettingState> provider,
) async {
  for (var i = 0; i < 20; i++) {
    final state = container.read(provider);
    if (state.isLoaded) return state;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return container.read(provider);
}

class _UserIdNotifier extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void set(String? value) => state = value;
}

final _userIdProvider = NotifierProvider<_UserIdNotifier, String?>(
  _UserIdNotifier.new,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('privacy settings fail closed until persistence has loaded', () async {
    SharedPreferences.setMockInitialValues({
      'privacy_typing_indicators': false,
      'privacy_read_receipts': false,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(typingIndicatorsEnabledProvider), isFalse);
    expect(container.read(readReceiptsEnabledProvider), isFalse);

    final typing = await _waitUntilLoaded(container, typingIndicatorsProvider);
    final reads = await _waitUntilLoaded(container, readReceiptsProvider);
    expect(typing.isLoaded, isTrue);
    expect(reads.isLoaded, isTrue);
    expect(typing.enabled, isFalse);
    expect(reads.enabled, isFalse);
  });

  test('missing preferences default both controls ON after loading', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final typing = await _waitUntilLoaded(container, typingIndicatorsProvider);
    final reads = await _waitUntilLoaded(container, readReceiptsProvider);

    expect(typing.enabled, isTrue);
    expect(reads.enabled, isTrue);
    expect(container.read(typingIndicatorsEnabledProvider), isTrue);
    expect(container.read(readReceiptsEnabledProvider), isTrue);
  });

  test('updated controls persist for the next provider container', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    await _waitUntilLoaded(first, typingIndicatorsProvider);
    await _waitUntilLoaded(first, readReceiptsProvider);

    await first.read(typingIndicatorsProvider.notifier).set(false);
    await first.read(readReceiptsProvider.notifier).set(false);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(
      (await _waitUntilLoaded(second, typingIndicatorsProvider)).enabled,
      isFalse,
    );
    expect(
      (await _waitUntilLoaded(second, readReceiptsProvider)).enabled,
      isFalse,
    );
  });

  test(
    'privacy choices fail closed and stay isolated across accounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith(
            (ref) => ref.watch(_userIdProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _waitUntilLoaded(container, typingIndicatorsProvider);
      await _waitUntilLoaded(container, readReceiptsProvider);
      await container.read(typingIndicatorsProvider.notifier).set(false);
      await container.read(readReceiptsProvider.notifier).set(false);

      container.read(_userIdProvider.notifier).set('bob');
      expect(container.read(typingIndicatorsEnabledProvider), isFalse);
      expect(container.read(readReceiptsEnabledProvider), isFalse);
      expect(
        (await _waitUntilLoaded(container, typingIndicatorsProvider)).enabled,
        isTrue,
      );
      expect(
        (await _waitUntilLoaded(container, readReceiptsProvider)).enabled,
        isTrue,
      );

      container.read(_userIdProvider.notifier).set('alice');
      expect(
        (await _waitUntilLoaded(container, typingIndicatorsProvider)).enabled,
        isFalse,
      );
      expect(
        (await _waitUntilLoaded(container, readReceiptsProvider)).enabled,
        isFalse,
      );
    },
  );
}
