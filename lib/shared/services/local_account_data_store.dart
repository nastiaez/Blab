import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../data/local_storage_keys.dart';
import 'local_profile_cache.dart';
import 'blab_local_notifications.dart';
import 'local_chat_signals_cache.dart';

/// Removes only data owned by the deleted Blab account.
class LocalAccountDataStore {
  const LocalAccountDataStore({
    this.clearNotifications = BlabLocalNotifications.cancelAll,
    this.removePreference,
  });

  final Future<void> Function() clearNotifications;
  final Future<bool> Function(SharedPreferences, String)? removePreference;

  Future<void> clear() => _clear();

  Future<void> clearForOwner(String owner) => _clear(owner: owner);

  Future<void> _clear({String? owner}) async {
    LocalProfileCache.invalidateAll();
    LocalChatSignalsCache.invalidateAll();
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences.getKeys().where(
      (key) =>
          key == kPrivacyTypingIndicatorsKey ||
          key == kPrivacyReadReceiptsKey ||
          key.startsWith('$kPrivacyTypingIndicatorsKey:account:') ||
          key.startsWith('$kPrivacyReadReceiptsKey:account:') ||
          key.startsWith(kAccountInterfaceLanguageKeyPrefix) ||
          key.startsWith(kPendingSendsKeyPrefix) ||
          key.startsWith(kCachedChatsKeyPrefix) ||
          key.startsWith(kCachedProfileKeyPrefix) ||
          key.startsWith(kCachedSignalsKeyPrefix) ||
          key.startsWith(kCachedChatModeKeyPrefix) ||
          key.startsWith(kCachedMessagesKeyPrefix) ||
          key.startsWith(kCachedLanguageTimelineKeyPrefix) ||
          key.startsWith('cached_deleted_identity:') ||
          key.startsWith('cached_group_members:') ||
          key.startsWith('cached_group_photos:') ||
          key.startsWith('cached_group_notifications:') ||
          key.startsWith(kCachedPreparedTranslationsKeyPrefix) ||
          key.startsWith(kCachedAttachmentKeyPrefix) ||
          key.startsWith(kCachedAttachmentPreviewKeyPrefix) ||
          key.startsWith(kCachedAttachmentIndexKeyPrefix) ||
          key.startsWith(kModeTipSeenKeyPrefix),
    );
    final scoped = keys
        .where((key) => owner == null || _belongsToOwner(key, owner))
        .toList();
    List<bool> removed;
    try {
      removed = await Future.wait(
        scoped.map(
          (key) =>
              removePreference?.call(preferences, key) ??
              preferences.remove(key),
        ),
      );
    } catch (_) {
      await preferences.reload();
      rethrow;
    }
    if (removed.any((ok) => !ok)) {
      // SharedPreferences evicts its memory entry before native removal.
      // Reload disk truth so a retry cannot mistake a failed write for erase.
      await preferences.reload();
      throw StateError('account_data_removal_failed');
    }
    // OS-delivered previews are account data too. Do not depend on an
    // available Firebase token/provider to remove device-local records.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // Failure retains the recovery receipt; Auth sign-out still runs in
      // the service finally block, and device erasure retries on restart.
      await clearNotifications();
    }
  }

  static bool _belongsToOwner(String key, String owner) {
    const prefixes = [
      kAccountInterfaceLanguageKeyPrefix,
      kPendingSendsKeyPrefix,
      kCachedChatsKeyPrefix,
      kCachedProfileKeyPrefix,
      kCachedSignalsKeyPrefix,
      kCachedChatModeKeyPrefix,
      kCachedMessagesKeyPrefix,
      kCachedLanguageTimelineKeyPrefix,
      kCachedPreparedTranslationsKeyPrefix,
      kCachedAttachmentKeyPrefix,
      kCachedAttachmentPreviewKeyPrefix,
      kCachedAttachmentIndexKeyPrefix,
      kModeTipSeenKeyPrefix,
      'cached_deleted_identity:',
      'cached_group_members:',
      'cached_group_photos:',
      'cached_group_notifications:',
      '$kPrivacyTypingIndicatorsKey:account:',
      '$kPrivacyReadReceiptsKey:account:',
    ];
    return prefixes.any(
      (prefix) => key == '$prefix$owner' || key.startsWith('$prefix$owner:'),
    );
  }
}
