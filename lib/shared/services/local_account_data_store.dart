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
          key.startsWith(kAccountInterfaceLanguageKeyPrefix) ||
          key.startsWith(kPendingSendsKeyPrefix) ||
          key.startsWith(kCachedChatsKeyPrefix) ||
          key.startsWith(kCachedMessagesKeyPrefix) ||
          key.startsWith(kCachedAttachmentKeyPrefix) ||
          key.startsWith(kCachedAttachmentPreviewKeyPrefix) ||
          key.startsWith(kCachedAttachmentIndexKeyPrefix) ||
          key.startsWith(kModeTipSeenKeyPrefix),
    );
    await Future.wait(keys.map(preferences.remove));
  }
}
