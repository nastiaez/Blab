import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/services/local_account_data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account deletion clears only Blab account-owned local data', () async {
    SharedPreferences.setMockInitialValues({
      kPrivacyTypingIndicatorsKey: false,
      kPrivacyReadReceiptsKey: false,
      '${kCachedProfileKeyPrefix}user-a': '{"schema":1}',
      cachedChatModeStorageKey(userId: 'user-a', chatId: 'chat-a'):
          '{"mode":"normal","pendingSync":true}',
      pendingSendsStorageKey(userId: 'user-a', chatId: 'chat-a'):
          '[{"body":"one"}]',
      pendingSendsStorageKey(userId: 'user-b', chatId: 'chat-b'):
          '[{"body":"two"}]',
      cachedPreparedTranslationsStorageKey(userId: 'user-a', chatId: 'chat-a'):
          '[{"message_id":"message-a"}]',
      'cached_deleted_identity:user-a:old': true,
      'cached_group_members:user-a:g': 'private roster',
      'cached_group_photos:user-a:g': 'private photos',
      'cached_group_notifications:user-a:g': true,
      'cached_language_timeline:user-a:c': 'private timeline',
      'unrelated_device_preference': 'keep',
    });

    await LocalAccountDataStore(clearNotifications: () async {}).clear();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(kPrivacyTypingIndicatorsKey), isFalse);
    expect(preferences.containsKey(kPrivacyReadReceiptsKey), isFalse);
    expect(
      preferences.containsKey('${kCachedProfileKeyPrefix}user-a'),
      isFalse,
    );
    expect(
      preferences.getKeys().where(
        (key) => key.startsWith(kCachedChatModeKeyPrefix),
      ),
      isEmpty,
    );
    expect(
      preferences.getKeys().where(
        (key) => key.startsWith(kPendingSendsKeyPrefix),
      ),
      isEmpty,
    );
    expect(
      preferences.getKeys().where(
        (key) => key.startsWith(kCachedPreparedTranslationsKeyPrefix),
      ),
      isEmpty,
    );
    expect(
      preferences.getKeys().where((key) => key.startsWith('cached_')),
      isEmpty,
    );
    expect(preferences.getString('unrelated_device_preference'), 'keep');
  });

  for (final nativeFailure in [false, true]) {
    test(
      'OS notification cleanup requested, nativeFailure=$nativeFailure',
      () async {
        SharedPreferences.setMockInitialValues({
          '${kCachedProfileKeyPrefix}owner': 'private',
        });
        var calls = 0;
        final clearing = LocalAccountDataStore(
          clearNotifications: () async {
            calls++;
            if (nativeFailure) throw StateError('native unavailable');
          },
        ).clear();
        if (nativeFailure) {
          await expectLater(clearing, throwsStateError);
        } else {
          await clearing;
        }
        expect(calls, 1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('${kCachedProfileKeyPrefix}owner'), isFalse);
      },
    );
  }
}
