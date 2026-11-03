import 'package:blab/shared/services/account_deletion_recovery.dart';
import 'package:blab/shared/services/local_account_data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'captured-owner cleanup preserves other accounts and device defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        'cached_profile:old': 'private',
        'cached_messages:old:c': 'history',
        'cached_profile:old2': 'other',
        'cached_profile:new': 'new private',
        'pending_sends:new:c': 'new queue',
        'privacy_read_receipts:account:old': false,
        'privacy_read_receipts:account:new': false,
        'privacy_read_receipts': false,
      });
      await LocalAccountDataStore(
        clearNotifications: () async {},
      ).clearForOwner('old');
      final p = await SharedPreferences.getInstance();
      expect(p.containsKey('cached_profile:old'), isFalse);
      expect(p.containsKey('cached_messages:old:c'), isFalse);
      expect(p.containsKey('privacy_read_receipts:account:old'), isFalse);
      expect(p.getString('cached_profile:new'), 'new private');
      expect(p.getString('cached_profile:old2'), 'other');
      expect(p.getString('pending_sends:new:c'), 'new queue');
      expect(p.getBool('privacy_read_receipts:account:new'), isFalse);
      expect(p.getBool('privacy_read_receipts'), isFalse);
    },
  );
  test(
    'false preference removal retains receipt and can recover later',
    () async {
      SharedPreferences.setMockInitialValues({'cached_profile:old': 'private'});
      final r = AccountDeletionRecovery();
      await r.begin('old');
      await expectLater(
        r.reconcile(
          currentOwner: () => 'old',
          confirmed: (_) async => true,
          erase: (owner) => LocalAccountDataStore(
            clearNotifications: () async {},
            removePreference: (_, _) async => false,
          ).clearForOwner(owner),
        ),
        throwsStateError,
      );
      expect(await r.pending(), isNotNull);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('cached_profile:old'), 'private');
      expect(
        await r.reconcile(
          currentOwner: () => null,
          confirmed: (_) async => true,
          erase: (owner) => LocalAccountDataStore(
            clearNotifications: () async {},
          ).clearForOwner(owner),
        ),
        isTrue,
      );
      expect(await r.pending(), isNull);
      expect(p.containsKey('cached_profile:old'), isFalse);
    },
  );
  test('false receipt removal never reports cleanup complete', () async {
    final r = AccountDeletionRecovery(removeMarker: (_, _) async => false);
    await r.begin('old');
    await expectLater(
      r.reconcile(
        currentOwner: () => null,
        confirmed: (_) async => true,
        erase: (_) async {},
      ),
      throwsStateError,
    );
    expect(await r.pending(), isNotNull);
  });
  test(
    'finishing an old deletion never forgets a newer identity receipt',
    () async {
      final r = AccountDeletionRecovery();
      await r.begin('old');
      expect(
        await r.reconcile(
          currentOwner: () => null,
          confirmed: (_) async => true,
          erase: (owner) async {
            expect(owner, 'old');
            await r.begin('new');
          },
        ),
        isTrue,
      );
      expect((await r.pending())!.owner, 'new');
    },
  );
}
