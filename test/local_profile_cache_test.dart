import 'dart:async';
import 'package:blab/shared/services/local_profile_cache.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'offline returns the account snapshot without awaiting network refresh',
    () async {
      final cache = LocalProfileCache('alice');
      await cache.write(
        const UserProfile(displayName: 'Alice', primaryKnownLanguage: 'de'),
      );
      final pending = Completer<UserProfile>();
      final result = await cachedProfileFirst(
        cache: cache,
        isCurrent: () => true,
        refresh: () => pending.future,
        changed: () {},
      ).timeout(const Duration(seconds: 1));
      expect(result.primaryKnownLanguage, 'de');
      expect(pending.isCompleted, false);
      pending.completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'account switch cannot publish or persist a late old-account refresh',
    () async {
      final cache = LocalProfileCache('alice');
      await cache.write(const UserProfile(displayName: 'Alice'));
      expect(await LocalProfileCache('bob').read(), null);
      var current = true;
      var changed = 0;
      final pending = Completer<UserProfile>();
      await cachedProfileFirst(
        cache: cache,
        isCurrent: () => current,
        refresh: () => pending.future,
        changed: () => changed++,
      );
      current = false;
      pending.complete(const UserProfile(displayName: 'Late'));
      await Future<void>.delayed(Duration.zero);
      expect((await cache.read())!.displayName, 'Alice');
      expect(changed, 0);
    },
  );
  test(
    'preference mutation invalidation defeats a late same-account refresh',
    () async {
      final cache = LocalProfileCache('alice');
      await cache.write(const UserProfile(displayName: 'Before'));
      final pending = Completer<UserProfile>();
      await cachedProfileFirst(
        cache: cache,
        isCurrent: () => true,
        refresh: () => pending.future,
        changed: () {},
      );
      await cache.clear();
      pending.complete(const UserProfile(displayName: 'Stale'));
      await Future<void>.delayed(Duration.zero);
      expect(await cache.read(), null);
    },
  );
  test(
    'new server profile replaces snapshot and signals exactly one refresh',
    () async {
      final cache = LocalProfileCache('alice');
      await cache.write(const UserProfile(displayName: 'Before'));
      final changed = Completer<void>();
      final initial = await cachedProfileFirst(
        cache: cache,
        isCurrent: () => true,
        refresh: () async => const UserProfile(displayName: 'After'),
        changed: changed.complete,
      );
      expect(initial.displayName, 'Before');
      await changed.future.timeout(const Duration(seconds: 1));
      expect((await cache.read())!.displayName, 'After');
    },
  );
}
