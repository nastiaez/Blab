import 'package:blab/shared/models/reading_script.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/reading_script_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('native is the synchronous default and invalid wire fallback', () {
    expect(readingScriptFromWire(null), ReadingScript.native);
    expect(readingScriptFromWire('unexpected'), ReadingScript.native);
    expect(
      readingScriptFromWire('english_letters'),
      ReadingScript.englishLetters,
    );
  });

  test('signed-in preference hydrates and saves account-wide', () async {
    final updates = <String>[];
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('alice'),
        fetchReadingScriptProvider.overrideWithValue(
          () async => 'english_letters',
        ),
        updateReadingScriptProvider.overrideWithValue((value) async {
          updates.add(value);
          return value;
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(readingScriptProvider), ReadingScript.native);
    await settle();
    expect(container.read(readingScriptProvider), ReadingScript.englishLetters);

    await container
        .read(readingScriptProvider.notifier)
        .set(ReadingScript.native);
    expect(updates, ['native']);
    expect(container.read(readingScriptProvider), ReadingScript.native);
  });

  test('failed save keeps the previous preference', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('alice'),
        fetchReadingScriptProvider.overrideWithValue(
          () async => 'english_letters',
        ),
        updateReadingScriptProvider.overrideWithValue((_) async {
          throw StateError('offline');
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(readingScriptProvider);
    await settle();
    expect(container.read(readingScriptProvider), ReadingScript.englishLetters);

    await expectLater(
      container.read(readingScriptProvider.notifier).set(ReadingScript.native),
      throwsStateError,
    );
    expect(container.read(readingScriptProvider), ReadingScript.englishLetters);
  });
}
