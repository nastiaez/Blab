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
      '${kPendingSendsKeyPrefix}chat-a': '[{"body":"one"}]',
      '${kPendingSendsKeyPrefix}chat-b': '[{"body":"two"}]',
      'unrelated_device_preference': 'keep',
    });

    await const LocalAccountDataStore().clear();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(kPrivacyTypingIndicatorsKey), isFalse);
    expect(preferences.containsKey(kPrivacyReadReceiptsKey), isFalse);
    expect(
      preferences.getKeys().where(
        (key) => key.startsWith(kPendingSendsKeyPrefix),
      ),
      isEmpty,
    );
    expect(preferences.getString('unrelated_device_preference'), 'keep');
  });
}
