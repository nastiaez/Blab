const String kPrivacyTypingIndicatorsKey = 'privacy_typing_indicators';
const String kPrivacyReadReceiptsKey = 'privacy_read_receipts';
const String kPendingSendsKeyPrefix = 'pending_sends:';
const String kCachedChatsKeyPrefix = 'cached_chats:';
const String kCachedMessagesKeyPrefix = 'cached_messages:';
const String kCachedLanguageTimelineKeyPrefix = 'cached_language_timeline:';
const String kCachedAttachmentKeyPrefix = 'cached_attachment:';
const String kCachedAttachmentPreviewKeyPrefix = 'cached_attachment_preview:';
const String kCachedAttachmentIndexKeyPrefix = 'cached_attachment_index:';
const String kGuestInterfaceLanguageKey = 'interface_language:guest';
const String kAccountInterfaceLanguageKeyPrefix = 'interface_language:account:';
const String kNotificationPermissionRequestedKey =
    'notifications_permission_requested';
const String kNotificationReminderDismissedKey =
    'notifications_reminder_dismissed';
const String kNotificationPreviewsKey = 'notifications_previews_enabled';
const String kModeTipSeenKeyPrefix = 'mode_tip_seen:';
const String kPendingInviteTokenKey = 'pending_invite_token';

String modeTipSeenStorageKey({required String userId, required String mode}) =>
    '$kModeTipSeenKeyPrefix$userId:$mode';

String interfaceLanguageStorageKey(String? userId) => userId == null
    ? kGuestInterfaceLanguageKey
    : '$kAccountInterfaceLanguageKeyPrefix$userId';

String pendingSendsStorageKey({
  required String userId,
  required String chatId,
}) => '$kPendingSendsKeyPrefix$userId:$chatId';

String cachedChatsStorageKey(String userId) => '$kCachedChatsKeyPrefix$userId';

String cachedMessagesStorageKey({
  required String userId,
  required String chatId,
}) => '$kCachedMessagesKeyPrefix$userId:$chatId';

String cachedLanguageTimelineStorageKey({
  required String userId,
  required String chatId,
}) => '$kCachedLanguageTimelineKeyPrefix$userId:$chatId';

String cachedAttachmentStorageKey({
  required String userId,
  required String attachmentId,
}) => '$kCachedAttachmentKeyPrefix$userId:$attachmentId';

String cachedAttachmentPreviewStorageKey({
  required String userId,
  required String attachmentId,
}) => '$kCachedAttachmentPreviewKeyPrefix$userId:$attachmentId';

String cachedAttachmentIndexStorageKey(String userId) =>
    '$kCachedAttachmentIndexKeyPrefix$userId';
