import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/interface_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'English is the synchronous default and invalid guest data fallback',
    () async {
      SharedPreferences.setMockInitialValues({
        kGuestInterfaceLanguageKey: 'not-supported',
      });
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      expect(container.read(interfaceLanguageProvider).code, 'en');
      await settle();
      expect(container.read(interfaceLanguageProvider).code, 'en');
    },
  );

  test('guest locale hydrates and persists independently', () async {
    SharedPreferences.setMockInitialValues({kGuestInterfaceLanguageKey: 'de'});
    final container = ProviderContainer(
      overrides: [currentUserIdProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    container.read(interfaceLanguageProvider);
    await settle();
    expect(container.read(interfaceLanguageProvider).code, 'de');

    await container
        .read(interfaceLanguageProvider.notifier)
        .set(interfaceLanguageForCode('es'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(kGuestInterfaceLanguageKey), 'es');
  });

  test('signed-in locale is server authoritative and account scoped', () async {
    SharedPreferences.setMockInitialValues({
      interfaceLanguageStorageKey('user-a'): 'de',
      kGuestInterfaceLanguageKey: 'es',
    });
    final updates = <String>[];
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        fetchInterfaceLanguageProvider.overrideWithValue(() async => 'uk'),
        updateInterfaceLanguageProvider.overrideWithValue((code) async {
          updates.add(code);
          return code;
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(interfaceLanguageProvider);
    await settle();
    expect(container.read(interfaceLanguageProvider).code, 'uk');

    await container
        .read(interfaceLanguageProvider.notifier)
        .set(interfaceLanguageForCode('es'));
    expect(updates, ['es']);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(interfaceLanguageStorageKey('user-a')), 'es');
    expect(preferences.getString(kGuestInterfaceLanguageKey), 'es');
  });

  test('invalid server locale safely resolves to English', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-b'),
        fetchInterfaceLanguageProvider.overrideWithValue(() async => 'fr'),
      ],
    );
    addTearDown(container.dispose);

    container.read(interfaceLanguageProvider);
    await settle();
    expect(container.read(interfaceLanguageProvider).code, 'en');
  });
}
