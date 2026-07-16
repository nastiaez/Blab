import 'package:blab/shared/state/privacy_settings.dart';
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
}
