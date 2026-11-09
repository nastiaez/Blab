import 'dart:convert';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/services/local_profile_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('snapshot stores stable source, never expiring bearer link', () async {
    final cache = LocalProfileCache('avatar-viewer');
    await cache.write(
      const UserProfile(
        displayName: 'Nastia',
        avatarPath: 'actor/photo.jpg',
        avatarUrl: 'https://signed.invalid/secret-bearer',
      ),
    );
    final value = await cache.read();
    expect(value!.avatarPath, 'actor/photo.jpg');
    expect(value.avatarUrl, isNull);
    final prefs = await SharedPreferences.getInstance();
    final all = prefs.getKeys().map((key) => prefs.get(key)).toList();
    expect(jsonEncode(all), isNot(contains('secret-bearer')));
  });
  test(
    'renewed signed link alone cannot invalidate snapshot indefinitely',
    () async {
      final cache = LocalProfileCache('avatar-viewer');
      var changes = 0;
      await cache.write(
        const UserProfile(
          displayName: 'Nastia',
          avatarPath: 'actor/photo.jpg',
          avatarUrl: 'https://signed.invalid/old',
        ),
      );
      await cachedProfileFirst(
        cache: cache,
        isCurrent: () => true,
        refresh: () async => const UserProfile(
          displayName: 'Nastia',
          avatarPath: 'actor/photo.jpg',
          avatarUrl: 'https://signed.invalid/new',
        ),
        changed: () => changes++,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(changes, 0);
    },
  );
  test('actual photo removal changes stable snapshot exactly once', () async {
    final cache = LocalProfileCache('avatar-viewer');
    var changes = 0;
    await cache.write(
      const UserProfile(displayName: 'Nastia', avatarPath: 'actor/photo.jpg'),
    );
    await cachedProfileFirst(
      cache: cache,
      isCurrent: () => true,
      refresh: () async => const UserProfile(displayName: 'Nastia'),
      changed: () => changes++,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(changes, 1);
    expect((await cache.read())!.avatarPath, isNull);
  });
}
