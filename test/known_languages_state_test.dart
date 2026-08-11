import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/known_languages_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'falls back to interface language when known_languages is empty',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith(
            (_) async => const UserProfile(
              displayName: 'Alice',
              interfaceLanguage: 'en',
              knownLanguages: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(knownLanguagesProvider.future);
      expect(result.codes, ['en']);
      expect(result.primary, 'en');
    },
  );

  test('uses the stored list and primary when present', () async {
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith(
          (_) async => const UserProfile(
            displayName: 'Alice',
            interfaceLanguage: 'en',
            knownLanguages: ['en', 'uk'],
            primaryKnownLanguage: 'en',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(knownLanguagesProvider.future);
    expect(result.codes, ['en', 'uk']);
    expect(result.primary, 'en');
  });

  test('falls back to first known language when primary is unset', () async {
    final container = ProviderContainer(
      overrides: [
        currentProfileProvider.overrideWith(
          (_) async => const UserProfile(
            displayName: 'Alice',
            interfaceLanguage: 'en',
            knownLanguages: ['uk', 'de'],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(knownLanguagesProvider.future);
    expect(result.codes, ['uk', 'de']);
    expect(result.primary, 'uk');
  });
}
