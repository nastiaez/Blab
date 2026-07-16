import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_storage_keys.dart';

/// Removes only data owned by the deleted Blab account.
class LocalAccountDataStore {
  const LocalAccountDataStore();

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys().where(
      (key) =>
          key == kPrivacyTypingIndicatorsKey ||
          key == kPrivacyReadReceiptsKey ||
          key.startsWith(kPendingSendsKeyPrefix),
    );
    await Future.wait(keys.map(preferences.remove));
  }
}
